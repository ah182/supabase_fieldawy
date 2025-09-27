import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.0.0";

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
      },
    });
  }

  try {
    const { distributorId } = await req.json();
    if (!distributorId) {
      throw new Error("distributorId is required.");
    }

    // ✅ استخدم الـ secrets
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      {
        global: { headers: { Authorization: req.headers.get("Authorization")! } },
      }
    );

    const { data: rows, error: rowsError } = await supabase
      .from("distributor_products")
      .select("product_id, price, package, distributor_name")
      .eq("distributor_id", distributorId);

    if (rowsError) throw rowsError;

    if (!rows || rows.length === 0) {
      return new Response(JSON.stringify([]), {
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
        },
      });
    }

    const productIds = rows.map((row) => row.product_id);

    const { data: productDocs, error: productDocsError } = await supabase
      .from("products")
      .select("*")
      .in("id", productIds);

    if (productDocsError) throw productDocsError;

    const productsMap = new Map(productDocs.map((doc) => [doc.id, doc]));

    const products = rows
      .map((row) => {
        const productDetails = productsMap.get(row.product_id);
        if (!productDetails) return null;
        return {
          ...productDetails,
          price: row.price,
          selected_package: row.package,
          distributor_id: row.distributor_name,
        };
      })
      .filter((p) => p !== null);

    return new Response(JSON.stringify(products), {
      headers: {
        "Content-Type": "application/json",
        "Cache-Control": "public, max-age=1800, s-maxage=1800",
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
