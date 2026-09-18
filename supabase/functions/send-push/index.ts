// supabase/functions/send-push/index.ts
//
// Triggered by a Supabase Database Webhook on INSERT into `notifications`.
// Looks up the recipient's saved FCM device token and sends a push via the
// Firebase Cloud Messaging HTTP v1 API, so the notification shows up even
// if the app is fully closed.
//
// Deploy with:
//   supabase functions deploy send-push
//
// Required secrets (set with `supabase secrets set KEY=value`):
//   SUPABASE_URL                - your project URL (auto-available, but set explicitly if needed)
//   SUPABASE_SERVICE_ROLE_KEY   - service role key, needed to read the users table server-side
//   FCM_PROJECT_ID              - your Firebase project ID
//   FCM_SERVICE_ACCOUNT_JSON    - the full contents of your Firebase service account JSON key,
//                                  as a single-line string (Firebase console > Project settings >
//                                  Service accounts > Generate new private key)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

interface WebhookPayload {
  type: "INSERT";
  table: string;
  record: {
    id: number;
    recipient: string;
    qr_code: string;
    message: string;
    is_read: boolean;
    created_at: string;
  };
}

// Minimal OAuth2 token fetch for the FCM HTTP v1 API using a service account.
async function getAccessToken(serviceAccountJson: string): Promise<string> {
  const serviceAccount = JSON.parse(serviceAccountJson);
  const now = Math.floor(Date.now() / 1000);

  const header = { alg: "RS256", typ: "JWT" };
  const claimSet = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    exp: now + 3600,
    iat: now,
  };

  const encode = (obj: unknown) =>
    btoa(JSON.stringify(obj)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");

  const unsigned = `${encode(header)}.${encode(claimSet)}`;

  const keyData = serviceAccount.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");
  const binaryKey = Uint8Array.from(atob(keyData), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryKey.buffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(unsigned),
  );

  const encodedSig = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");

  const jwt = `${unsigned}.${encodedSig}`;

  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  const tokenJson = await tokenRes.json();
  if (!tokenRes.ok) {
    throw new Error(`Failed to get access token: ${JSON.stringify(tokenJson)}`);
  }
  return tokenJson.access_token as string;
}

Deno.serve(async (req) => {
  try {
    const payload: WebhookPayload = await req.json();

    if (payload.type !== "INSERT" || payload.table !== "notifications") {
      return new Response("Ignored", { status: 200 });
    }

    const { recipient, message, qr_code } = payload.record;

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, serviceRoleKey);

    const { data: user, error } = await supabase
      .from("users")
      .select("fcm_token")
      .eq("username", recipient)
      .maybeSingle();

    if (error) throw error;
    if (!user?.fcm_token) {
      // User has no registered device (never logged in on this build, or
      // token not yet saved) — nothing to push to.
      return new Response("No device token for recipient", { status: 200 });
    }

    const fcmProjectId = Deno.env.get("FCM_PROJECT_ID")!;
    const serviceAccountJson = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON")!;
    const accessToken = await getAccessToken(serviceAccountJson);

    const fcmRes = await fetch(
      `https://fcm.googleapis.com/v1/projects/${fcmProjectId}/messages:send`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token: user.fcm_token,
            notification: {
              title: "Document Tracker",
              body: message,
            },
            data: {
              qr_code: qr_code,
            },
          },
        }),
      },
    );

    const fcmJson = await fcmRes.json();
    if (!fcmRes.ok) {
      console.error("FCM send failed:", fcmJson);
      return new Response(JSON.stringify(fcmJson), { status: 500 });
    }

    return new Response("Push sent", { status: 200 });
  } catch (err) {
    console.error(err);
    return new Response(`Error: ${err}`, { status: 500 });
  }
});