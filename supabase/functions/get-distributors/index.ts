
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.0.0";

// Edge Function to fetch distributors with product count
serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers":
          "authorization, x-client-info, apikey, content-type",
      },
    });
  }

  try {
    // 🟢 استخدم المتغيرات اللي خزناها في secrets
    const url = Deno.env.get("URL");
    const anonKey = Deno.env.get("ANON_KEY");

    if (!url || !anonKey) {
      throw new Error("Missing URL or ANON_KEY environment variable.");
    }

    const supabase = createClient(url, anonKey, {
      global: {
        headers: { Authorization: req.headers.get("Authorization") ?? "" },
      },
    });

    // 🟢 استعلام المستخدمين (الموزعين والشركات)
    const { data: users, error: usersError } = await supabase
      .from("users")
      .select("*, distributorType:role")
      .or("role.eq.distributor,role.eq.company")
      .or("account_status.eq.approved,account_status.eq.pending_review")
      .eq("is_profile_complete", true);

    if (usersError) throw usersError;

    if (!users || users.length === 0) {
      return new Response(JSON.stringify([]), {
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
        },
      });
    }

    const distributorIds = users.map((u) => u.id);

    // 🟢 استعلام المنتجات الخاصة بالموزعين
    const { data: productRows, error: productsError } = await supabase
      .from("distributor_products")
      .select("distributor_id")
      .in("distributor_id", distributorIds);

    if (productsError) throw productsError;

    // 🟢 حساب عدد المنتجات لكل موزع
    const counts = new Map<string, number>();
    for (const row of productRows) {
      counts.set(
        row.distributor_id,
        (counts.get(row.distributor_id) || 0) + 1,
      );
    }

    // 🟢 تجهيز النتيجة النهائية
    const result = users.map((u) => ({
      ...u,
      productCount: counts.get(u.id) || 0,
    }));

    return new Response(JSON.stringify(result), {
      headers: {
        "Content-Type": "application/json",
        "Cache-Control": "public, max-age=1800, s-maxage=1800", // كاش 30 دقيقة
        "Access-Control-Allow-Origin": "*",
      },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      },
    });
  }
});
