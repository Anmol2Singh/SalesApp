// supabase/functions/send_fcm/index.ts
// Placeholder Supabase Edge Function to send FCM push notifications
// In production, this would use the Firebase Admin SDK and a service account key

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface SendFcmRequest {
  user_id: string;
  title: string;
  body: string;
  data?: Record<string, string>;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const requestData: SendFcmRequest = await req.json();
    const { user_id, title, body, data } = requestData;

    if (!user_id || !title || !body) {
      return new Response(
        JSON.stringify({ error: "Missing user_id, title, or body" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    console.log(`[FCM Placeholder] Sending notification to user ${user_id}:`);
    console.log(`Title: ${title}`);
    console.log(`Body: ${body}`);
    if (data) {
      console.log(`Data payload:`, data);
    }

    // In a live integration, you would fetch FCM token(s) from profiles/devices table
    // and call Firebase REST API: https://fcm.googleapis.com/v1/projects/YOUR_PROJECT_ID/messages:send

    return new Response(
      JSON.stringify({ success: true, message: "FCM notification sent (placeholder)" }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    console.error("send_fcm error:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
