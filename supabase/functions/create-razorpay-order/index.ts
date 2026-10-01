// supabase/functions/create-razorpay-order/index.ts
// Supabase Edge Function: create-razorpay-order
// Handles server-side Razorpay order creation using secure environment variables

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface CreateRazorpayOrderRequest {
  amount: number; // In paise (e.g. 100 paise = 1 INR)
  currency?: string; // Default: 'INR'
  receipt?: string;
  notes?: Record<string, string>;
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const keyId = Deno.env.get("RAZORPAY_KEY_ID");
    const keySecret = Deno.env.get("RAZORPAY_KEY_SECRET");

    if (!keyId || !keySecret) {
      console.error("Missing RAZORPAY_KEY_ID or RAZORPAY_KEY_SECRET environment variables");
      return new Response(
        JSON.stringify({
          error: "Razorpay credentials not configured on Supabase Edge Function",
        }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const body: CreateRazorpayOrderRequest = await req.json();
    const amount = typeof body.amount === "number" ? Math.round(body.amount) : parseInt(String(body.amount), 10);
    const currency = (body.currency || "INR").toUpperCase();
    const receipt = body.receipt || `rcpt_${Date.now()}`;
    const notes = body.notes || {};

    if (!amount || isNaN(amount) || amount < 100) {
      return new Response(
        JSON.stringify({
          error: "Invalid amount. Minimum amount is 100 paise (₹1.00)",
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Call Razorpay Orders API using HTTP Basic Authentication
    const basicAuth = btoa(`${keyId}:${keySecret}`);
    const rzpResponse = await fetch("https://api.razorpay.com/v1/orders", {
      method: "POST",
      headers: {
        Authorization: `Basic ${basicAuth}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        amount,
        currency,
        receipt,
        notes,
      }),
    });

    const rzpData = await rzpResponse.json();

    if (!rzpResponse.ok) {
      console.error("Razorpay order creation error:", rzpData);
      return new Response(
        JSON.stringify({
          error: "Failed to create Razorpay order",
          details: rzpData.error?.description || rzpData,
        }),
        {
          status: rzpResponse.status,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Return order payload with order_id and id
    return new Response(
      JSON.stringify({
        order_id: rzpData.id,
        id: rzpData.id,
        amount: rzpData.amount,
        currency: rzpData.currency,
        receipt: rzpData.receipt,
        status: rzpData.status,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    console.error("Error in create-razorpay-order edge function:", error);
    return new Response(
      JSON.stringify({
        error: "Internal server error",
        message: error instanceof Error ? error.message : String(error),
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
