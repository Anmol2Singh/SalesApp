// Supabase Edge Function: amc_daily_cron
// Designed to run daily at midnight to update AMC contract and service visit statuses,
// and create appropriate system notifications.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error("Missing environment variables SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const todayStr = new Date().toISOString().split('T')[0];
    const log: string[] = [];

    // --- CONTRACT STATUS TRANSITIONS ---

    // 1. Transition active -> expiring_soon where end_date <= today + 30 days and status is active
    const thirtyDaysFromNow = new Date();
    thirtyDaysFromNow.setDate(thirtyDaysFromNow.getDate() + 30);
    const thirtyDaysFromNowStr = thirtyDaysFromNow.toISOString().split('T')[0];

    const { data: expiringContracts, error: activeErr } = await supabase
      .from('amc_contracts')
      .select('id, amc_number, customer_id, created_by, customers(company_name)')
      .eq('status', 'active')
      .lte('end_date', thirtyDaysFromNowStr)
      .gte('end_date', todayStr);

    if (activeErr) throw activeErr;

    if (expiringContracts && expiringContracts.length > 0) {
      log.push(`Found ${expiringContracts.length} active contracts expiring soon.`);
      for (const contract of expiringContracts) {
        const { error: updErr } = await supabase
          .from('amc_contracts')
          .update({ status: 'expiring_soon' })
          .eq('id', contract.id);

        if (updErr) throw updErr;

        // Get all admin profiles to notify
        const { data: admins } = await supabase
          .from('profiles')
          .select('id')
          .eq('role', 'admin')
          .eq('is_active', true);

        // Notify salesperson (created_by)
        await supabase.from('notifications').insert({
          user_id: contract.created_by,
          title: 'AMC Contract Expiring Soon',
          body: `AMC Contract ${contract.amc_number} for customer ${contract.customers?.company_name || ''} is expiring within 30 days.`,
          type: 'amc_expiring_soon',
          related_amc_id: contract.id,
        });

        // Notify admins
        if (admins) {
          for (const admin of admins) {
            if (admin.id !== contract.created_by) {
              await supabase.from('notifications').insert({
                user_id: admin.id,
                title: 'AMC Contract Expiring Soon',
                body: `AMC Contract ${contract.amc_number} for customer ${contract.customers?.company_name || ''} is expiring within 30 days.`,
                type: 'amc_expiring_soon',
                related_amc_id: contract.id,
              });
            }
          }
        }
      }
    }

    // 2. Transition expiring_soon/active -> expired where end_date < today
    const { data: expiredContracts, error: expErr } = await supabase
      .from('amc_contracts')
      .select('id, amc_number, customer_id, created_by, customers(company_name)')
      .in('status', ['active', 'expiring_soon'])
      .lt('end_date', todayStr);

    if (expErr) throw expErr;

    if (expiredContracts && expiredContracts.length > 0) {
      log.push(`Found ${expiredContracts.length} contracts that have expired.`);
      for (const contract of expiredContracts) {
        const { error: updErr } = await supabase
          .from('amc_contracts')
          .update({ status: 'expired' })
          .eq('id', contract.id);

        if (updErr) throw updErr;

        // Write audit log
        await supabase.from('step_audit_log').insert({
          amc_contract_id: contract.id,
          step_name: 'amc',
          action: 'amc_expired',
          performed_by: contract.created_by,
          notes: 'Contract expired automatically based on end date.',
        });

        // Get all admin profiles to notify
        const { data: admins } = await supabase
          .from('profiles')
          .select('id')
          .eq('role', 'admin')
          .eq('is_active', true);

        if (admins) {
          for (const admin of admins) {
            await supabase.from('notifications').insert({
              user_id: admin.id,
              title: 'AMC Contract Expired',
              body: `AMC Contract ${contract.amc_number} for customer ${contract.customers?.company_name || ''} has expired.`,
              type: 'amc_expired',
              related_amc_id: contract.id,
            });
          }
        }
      }
    }

    // --- SERVICE VISIT STATUS TRANSITIONS ---

    // 3. Transition scheduled -> missed where scheduled_date < today
    const { data: missedVisits, error: visitErr } = await supabase
      .from('amc_service_visits')
      .select('id, visit_number, scheduled_date, amc_contract_id, amc_contracts(amc_number, created_by, customers(company_name))')
      .eq('status', 'scheduled')
      .lt('scheduled_date', todayStr);

    if (visitErr) throw visitErr;

    if (missedVisits && missedVisits.length > 0) {
      log.push(`Found ${missedVisits.length} missed service visits.`);
      for (const visit of missedVisits) {
        const { error: updErr } = await supabase
          .from('amc_service_visits')
          .update({ status: 'missed' })
          .eq('id', visit.id);

        if (updErr) throw updErr;

        const amc = visit.amc_contracts;
        if (amc) {
          await supabase.from('notifications').insert({
            user_id: amc.created_by,
            title: 'AMC Service Visit Missed',
            body: `Scheduled service visit #${visit.visit_number} on ${visit.scheduled_date} for contract ${amc.amc_number} (${amc.customers?.company_name || ''}) was missed.`,
            type: 'amc_visit_missed',
            related_amc_id: visit.amc_contract_id,
          });
        }
      }
    }

    // --- SERVICE VISIT DUE SOON WARNINGS ---

    // 4. Send amc_visit_due_soon notification for visits scheduled in exactly 7 days
    const sevenDaysFromNow = new Date();
    sevenDaysFromNow.setDate(sevenDaysFromNow.getDate() + 7);
    const sevenDaysFromNowStr = sevenDaysFromNow.toISOString().split('T')[0];

    const { data: dueVisits, error: dueErr } = await supabase
      .from('amc_service_visits')
      .select('id, visit_number, scheduled_date, amc_contract_id, amc_contracts(amc_number, created_by, customers(company_name))')
      .eq('status', 'scheduled')
      .eq('scheduled_date', sevenDaysFromNowStr);

    if (dueErr) throw dueErr;

    if (dueVisits && dueVisits.length > 0) {
      log.push(`Found ${dueVisits.length} service visits due in 7 days.`);
      for (const visit of dueVisits) {
        const amc = visit.amc_contracts;
        if (amc) {
          await supabase.from('notifications').insert({
            user_id: amc.created_by,
            title: 'AMC Service Visit Due Soon',
            body: `Service visit #${visit.visit_number} for contract ${amc.amc_number} (${amc.customers?.company_name || ''}) is due in 7 days (on ${visit.scheduled_date}).`,
            type: 'amc_visit_due_soon',
            related_amc_id: visit.amc_contract_id,
          });
        }
      }
    }

    return new Response(JSON.stringify({ success: true, log }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
