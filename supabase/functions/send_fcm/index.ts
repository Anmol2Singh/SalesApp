// supabase/functions/send_fcm/index.ts
// Supabase Edge Function to send FCM push notifications via FCM HTTP v1 API
// Authenticates with Google OAuth2 using FIREBASE_SERVICE_ACCOUNT_JSON secret
// Cached in-memory access token with automatic refresh

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface ServiceAccount {
  project_id: string;
  private_key: string;
  client_email: string;
}

let cachedAccessToken: { token: string; expiresAt: number } | null = null;

function base64UrlEncode(str: string): string {
  const bytes = new TextEncoder().encode(str);
  let binary = "";
  for (let i = 0; i < bytes.byteLength; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

function bufferToBase64Url(buffer: ArrayBuffer): string {
  const bytes = new Uint8Array(buffer);
  let binary = "";
  for (let i = 0; i < bytes.byteLength; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

function pemToBinary(pem: string): ArrayBuffer {
  const clean = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s+/g, "");
  const binaryStr = atob(clean);
  const bytes = new Uint8Array(binaryStr.length);
  for (let i = 0; i < binaryStr.length; i++) {
    bytes[i] = binaryStr.charCodeAt(i);
  }
  return bytes.buffer;
}

async function getGoogleAccessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);

  // Return cached token if valid for at least 5 more minutes
  if (cachedAccessToken && cachedAccessToken.expiresAt > now + 300) {
    return cachedAccessToken.token;
  }

  const header = {
    alg: "RS256",
    typ: "JWT",
  };

  const claimSet = {
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    exp: now + 3600,
    iat: now,
  };

  const encodedHeader = base64UrlEncode(JSON.stringify(header));
  const encodedClaimSet = base64UrlEncode(JSON.stringify(claimSet));
  const unsignedToken = `${encodedHeader}.${encodedClaimSet}`;

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    pemToBinary(sa.private_key),
    {
      name: "RSASSA-PKCS1-v1_5",
      hash: "SHA-256",
    },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(unsignedToken)
  );

  const signedJwt = `${unsignedToken}.${bufferToBase64Url(signature)}`;

  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${signedJwt}`,
  });

  if (!tokenResponse.ok) {
    const errorText = await tokenResponse.text();
    throw new Error(`Failed to obtain Google access token: ${errorText}`);
  }

  const tokenData = await tokenResponse.json();
  const accessToken = tokenData.access_token;
  const expiresIn = tokenData.expires_in || 3600;

  cachedAccessToken = {
    token: accessToken,
    expiresAt: now + expiresIn,
  };

  return accessToken;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const serviceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
    const webhookSecret = Deno.env.get("FCM_WEBHOOK_SECRET");

    if (!supabaseUrl || !supabaseServiceKey) {
      return new Response(
        JSON.stringify({ error: "Missing Supabase configuration environment variables" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Security check: ensure request has valid authorization
    const authHeader = req.headers.get("Authorization");
    const secretHeader = req.headers.get("x-webhook-secret");

    const isAuthorized =
      (webhookSecret && secretHeader === webhookSecret) ||
      (authHeader && authHeader.includes(supabaseServiceKey)) ||
      (authHeader && authHeader.startsWith("Bearer "));

    if (!isAuthorized) {
      return new Response(
        JSON.stringify({ error: "Unauthorized access" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!serviceAccountJson) {
      console.warn("FIREBASE_SERVICE_ACCOUNT_JSON is not configured in Supabase secrets.");
      return new Response(
        JSON.stringify({
          error: "FIREBASE_SERVICE_ACCOUNT_JSON secret is not configured in Supabase",
        }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    let serviceAccount: ServiceAccount;
    try {
      serviceAccount = JSON.parse(serviceAccountJson);
    } catch {
      return new Response(
        JSON.stringify({ error: "Invalid FIREBASE_SERVICE_ACCOUNT_JSON JSON format" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);
    const body = await req.json();

    let targetUserIds: string[] = [];
    let title = "";
    let messageBody = "";
    let dataPayload: Record<string, string> = {};

    // 1. Support Postgres Database Webhook payload (INSERT on notifications)
    if (body.record && body.type === "INSERT") {
      const rec = body.record;
      if (rec.user_id) targetUserIds.push(rec.user_id);
      title = rec.title || "IZYHEAT Update";
      messageBody = rec.body || "";
      dataPayload = {
        notification_id: String(rec.id || ""),
        pipeline_id: String(rec.related_pipeline_id || ""),
        amc_id: String(rec.related_amc_id || ""),
        type: String(rec.type || ""),
      };
    } else {
      // 2. Direct API call
      title = body.title || "";
      messageBody = body.body || "";

      if (body.data && typeof body.data === "object") {
        for (const [k, v] of Object.entries(body.data)) {
          dataPayload[k] = String(v ?? "");
        }
      }

      if (body.user_ids && Array.isArray(body.user_ids)) {
        targetUserIds = body.user_ids;
      } else if (body.user_id) {
        targetUserIds = [body.user_id];
      }

      // If a role is specified, look up user IDs for that role
      if (body.role) {
        const role = body.role.toLowerCase();
        const { data: roleProfiles } = await supabase
          .from("profiles")
          .select("id, role, roles")
          .eq("is_active", true);

        if (roleProfiles) {
          const matchingUsers = roleProfiles.filter((p: any) => {
            if (p.role === role) return true;
            if (Array.isArray(p.roles) && p.roles.includes(role)) return true;
            return false;
          });
          const ids = matchingUsers.map((p: any) => p.id);
          targetUserIds = Array.from(new Set([...targetUserIds, ...ids]));
        }
      }
    }

    if (targetUserIds.length === 0) {
      return new Response(
        JSON.stringify({ success: true, message: "No target users found for notification", sent: 0 }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Query active device tokens for the target users
    const { data: tokensData, error: tokensError } = await supabase
      .from("fcm_tokens")
      .select("id, user_id, token")
      .in("user_id", targetUserIds);

    if (tokensError) {
      console.error("Error fetching fcm_tokens:", tokensError);
      return new Response(
        JSON.stringify({ error: "Failed to fetch device tokens", details: tokensError }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!tokensData || tokensData.length === 0) {
      return new Response(
        JSON.stringify({ success: true, message: "No registered device tokens found for users", sent: 0 }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const accessToken = await getGoogleAccessToken(serviceAccount);
    const fcmEndpoint = `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`;

    let successCount = 0;
    let failureCount = 0;
    const tokensToDelete: string[] = [];

    // Send push notification to each registered device
    await Promise.all(
      tokensData.map(async (row: { id: string; user_id: string; token: string }) => {
        const payload = {
          message: {
            token: row.token,
            notification: {
              title: title,
              body: messageBody,
            },
            data: dataPayload,
            android: {
              priority: "high",
              notification: {
                channel_id: "izyheat_sales_updates",
                icon: "ic_launcher",
                default_sound: true,
                default_vibrate_timings: true,
              },
            },
          },
        };

        try {
          const res = await fetch(fcmEndpoint, {
            method: "POST",
            headers: {
              Authorization: `Bearer ${accessToken}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify(payload),
          });

          if (res.ok) {
            successCount++;
          } else {
            failureCount++;
            const errBody = await res.json().catch(() => ({}));
            const errStatus = res.status;
            const errCode = errBody?.error?.details?.[0]?.errorCode || errBody?.error?.status || "";
            const errMsg = errBody?.error?.message || "";

            console.warn(`FCM send failure for token (${row.token}):`, errStatus, errCode, errMsg);

            // Prune dead/unregistered tokens
            if (
              errStatus === 404 ||
              errCode === "UNREGISTERED" ||
              errCode === "NOT_FOUND" ||
              errMsg.includes("registration-token-not-registered") ||
              errMsg.includes("UNREGISTERED") ||
              errMsg.includes("not a valid FCM registration token")
            ) {
              tokensToDelete.push(row.token);
            }
          }
        } catch (fetchErr) {
          failureCount++;
          console.error("FCM network error for token:", fetchErr);
        }
      })
    );

    // Delete obsolete tokens if any were discovered
    if (tokensToDelete.length > 0) {
      await supabase.from("fcm_tokens").delete().in("token", tokensToDelete);
      console.log(`Pruned ${tokensToDelete.length} obsolete FCM tokens from database.`);
    }

    return new Response(
      JSON.stringify({
        success: true,
        sent: successCount,
        failed: failureCount,
        pruned_tokens: tokensToDelete.length,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error: any) {
    console.error("send_fcm error:", error);
    return new Response(
      JSON.stringify({ error: error.message || "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
