// supabase/functions/get-products/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.0.0";
serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type"
      }
    });
  }
  try {
    const url = Deno.env.get("URL");
    const anonKey = Deno.env.get("ANON_KEY");
    if (!url || !anonKey) {
      throw new Error("Missing URL or ANON_KEY environment variable.");
    }
    const supabase = createClient(url, anonKey, {
      global: {
        headers: { Authorization: req.headers.get("Authorization") ?? "" }
      }
    });
    const { data: products, error: productsError } = await supabase.from("products").select("*");
    if (productsError) throw productsError;
    if (!products) {
      return new Response(JSON.stringify([]), {
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*"
        }
      });
    }
    return new Response(JSON.stringify(products), {
      headers: {
        "Content-Type": "application/json",
        "Cache-Control": "public, max-age=600, s-maxage=600",
        // Cache for 10 minutes
        "Access-Control-Allow-Origin": "*"
      }
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*"
      }
    });
  }
});
