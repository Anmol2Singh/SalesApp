// Supabase Edge Function: confirm_quotation
// Called by the Flutter client to server-side validate & confirm a quotation
// This prevents client-side total manipulation

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface LineItem {
  description: string;
  qty: number;
  unit_price: number;
  total: number;
}

interface ConfirmRequest {
  quotation_id: string;
  line_items: LineItem[];
  cgst_rate: number;
  sgst_rate: number;
  terms_text?: string;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // Get the calling user's JWT
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Verify user
    const { data: { user }, error: userError } = await supabase.auth.getUser(
      authHeader.replace("Bearer ", "")
    );
    if (userError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Check user role
    const { data: profile } = await supabase
      .from("profiles")
      .select("role, is_active")
      .eq("id", user.id)
      .single();

    if (!profile?.is_active) {
      return new Response(JSON.stringify({ error: "Account deactivated" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (!["admin", "sales", "sales_head"].includes(profile.role)) {
      return new Response(JSON.stringify({ error: "Insufficient permissions" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body: ConfirmRequest = await req.json();
    const { quotation_id, line_items, cgst_rate, sgst_rate, terms_text } = body;

    // Validate inputs
    if (!quotation_id || !line_items?.length) {
      return new Response(JSON.stringify({ error: "Missing required fields" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Recompute totals server-side (never trust client totals)
    let subtotal = 0;
    for (const item of line_items) {
      if (item.qty <= 0 || item.unit_price < 0) {
        return new Response(
          JSON.stringify({ error: `Invalid line item: ${item.description}` }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
      const computedTotal = Math.round(item.qty * item.unit_price * 100) / 100;
      item.total = computedTotal;
      subtotal += computedTotal;
    }

    subtotal = Math.round(subtotal * 100) / 100;
    const cgstAmount = Math.round(subtotal * (cgst_rate / 100) * 100) / 100;
    const sgstAmount = Math.round(subtotal * (sgst_rate / 100) * 100) / 100;
    const grandTotal = Math.round((subtotal + cgstAmount + sgstAmount) * 100) / 100;

    // Fetch the quotation to verify ownership
    const { data: quotation, error: quotationError } = await supabase
      .from("quotations")
      .select("id, pipeline_id, status")
      .eq("id", quotation_id)
      .single();

    if (quotationError || !quotation) {
      return new Response(JSON.stringify({ error: "Quotation not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (quotation.status === "confirmed") {
      return new Response(JSON.stringify({ error: "Quotation already confirmed" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Verify pipeline ownership (for sales role)
    if (profile.role === "sales") {
      const { data: pipeline } = await supabase
        .from("sales_pipelines")
        .select("created_by")
        .eq("id", quotation.pipeline_id)
        .single();

      if (pipeline?.created_by !== user.id) {
        return new Response(JSON.stringify({ error: "Access denied" }), {
          status: 403,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
    }

    const isSales = profile.role === "sales";
    const statusToSet = isSales ? "pending_approval" : "confirmed";

    // Update quotation with server-computed totals
    const updatePayload: any = {
      line_items,
      subtotal,
      cgst_rate,
      sgst_rate,
      cgst_amount: cgstAmount,
      sgst_amount: sgstAmount,
      grand_total: grandTotal,
      terms_text: terms_text || null,
      status: statusToSet,
      updated_at: new Date().toISOString(),
    };

    if (!isSales) {
      updatePayload.confirmed_by = user.id;
      updatePayload.confirmed_at = new Date().toISOString();
    }

    const { error: updateError } = await supabase
      .from("quotations")
      .update(updatePayload)
      .eq("id", quotation_id);

    if (updateError) {
      throw updateError;
    }

    if (!isSales) {
      // Advance pipeline to sales_order step
      const { error: pipelineError } = await supabase
        .from("sales_pipelines")
        .update({
          current_step: "sales_order",
          updated_at: new Date().toISOString(),
        })
        .eq("id", quotation.pipeline_id);

      if (pipelineError) {
        throw pipelineError;
      }

      // Write audit log
      await supabase.from("step_audit_log").insert({
        pipeline_id: quotation.pipeline_id,
        step_name: "quotation",
        action: "confirmed",
        performed_by: user.id,
        notes: `Quotation approved and confirmed. Total: ₹${grandTotal}`,
      });

      // Notify the sales executive who created the pipeline
      const { data: pipeline } = await supabase
        .from("sales_pipelines")
        .select("created_by")
        .eq("id", quotation.pipeline_id)
        .single();

      if (pipeline) {
        await supabase.from("notifications").insert({
          user_id: pipeline.created_by,
          title: "Quotation Approved",
          body: "Your quotation has been approved. Sales Order step is now unlocked.",
          type: "step_unlocked",
          related_pipeline_id: quotation.pipeline_id,
        });
      }
    } else {
      // Write audit log for submission
      await supabase.from("step_audit_log").insert({
        pipeline_id: quotation.pipeline_id,
        step_name: "quotation",
        action: "status_changed",
        performed_by: user.id,
        notes: `Quotation submitted for approval. Total: ₹${grandTotal}`,
      });

      // Create in-app notification for admin and sales heads
      const { data: adminsAndHeads } = await supabase
        .from("profiles")
        .select("id")
        .inFilter("role", ["admin", "sales_head"])
        .eq("is_active", true);

      if (adminsAndHeads?.length) {
        const notifications = adminsAndHeads.map((recipient) => ({
          user_id: recipient.id,
          title: "Quotation Pending Approval",
          body: `A new quotation of ₹${grandTotal} has been submitted and requires approval.`,
          type: "admin_alert",
          related_pipeline_id: quotation.pipeline_id,
        }));

        await supabase.from("notifications").insert(notifications);
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        status: statusToSet,
        subtotal,
        cgst_amount: cgstAmount,
        sgst_amount: sgstAmount,
        grand_total: grandTotal,
        line_items,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    console.error("confirm_quotation error:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
