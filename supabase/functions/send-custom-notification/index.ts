// Supabase Edge Function للإرسال الإشعارات المخصصة من Dashboard
// يستخدم Firebase Cloud Messaging API (Legacy) - الأسهل والأسرع!
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

// Firebase Server Key (من Firebase Console → Cloud Messaging)
const FIREBASE_SERVER_KEY = Deno.env.get("FIREBASE_SERVER_KEY") || "";

serve(async (req) => {
  // CORS headers
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST",
        "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
      },
    });
  }

  try {
    const { title, message, tokens } = await req.json();

    if (!title || !message || !tokens || tokens.length === 0) {
      return new Response(
        JSON.stringify({ error: "Missing required fields" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    console.log(`Sending notification to ${tokens.length} devices`);

    if (!FIREBASE_SERVER_KEY) {
      throw new Error("FIREBASE_SERVER_KEY not configured");
    }

    // إرسال عبر Firebase FCM API (Legacy)
    const results = await sendToFCM(tokens, title, message);

    return new Response(
      JSON.stringify({
        success: true,
        sent: results.success,
        failed: results.failure,
      }),
      {
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
        },
      }
    );
  } catch (error) {
    console.error("Error:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        status: 500,
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
        },
      }
    );
  }
});

// إرسال إشعارات عبر Firebase Legacy API (Batch Support!)
async function sendToFCM(tokens: string[], title: string, message: string) {
  let success = 0;
  let failure = 0;

  // Legacy API يدعم batch requests (500 token في المرة الواحدة)
  const batchSize = 500;
  
  for (let i = 0; i < tokens.length; i += batchSize) {
    const batch = tokens.slice(i, i + batchSize);
    
    try {
      const response = await fetch("https://fcm.googleapis.com/fcm/send", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `key=${FIREBASE_SERVER_KEY}`,
        },
        body: JSON.stringify({
          registration_ids: batch,
          data: {
            title: title,
            body: message,
            type: "custom",
            screen: "home",
          },
          priority: "high",
        }),
      });

      if (response.ok) {
        const result = await response.json();
        success += result.success || 0;
        failure += result.failure || 0;
        
        console.log(`Batch ${i}-${i+batch.length}: ✅ ${result.success} ❌ ${result.failure}`);
      } else {
        const error = await response.json();
        console.error(`Batch ${i} failed:`, error);
        failure += batch.length;
      }
    } catch (error) {
      console.error(`Batch ${i} failed:`, error);
      failure += batch.length;
    }
  }

  console.log(`Total: ✅ ${success} sent, ❌ ${failure} failed`);
  return { success, failure };
}
