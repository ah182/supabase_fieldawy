import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.0.0";

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

    // Fetch all distributor products
    const { data: rows, error: rowsError } = await supabase
      .from('distributor_products')
      .select('*')
      .order('added_at', { ascending: false });

    if (rowsError) throw rowsError;

    if (!rows || rows.length === 0) {
      return new Response(JSON.stringify([]), {
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
        },
      });
    }

    // Get unique product IDs
    const productIds = [...new Set(rows.map((row) => row.product_id as string))];

    // Fetch product details for the unique IDs
    const { data: productDocs, error: productDocsError } = await supabase
      .from('products')
      .select('*')
      .in('id', productIds);

    if (productDocsError) throw productDocsError;

    const productsMap = new Map(productDocs.map((doc) => [doc.id, doc]));

    // Combine the data
    const products = rows
      .map((row) => {
        const productDetails = productsMap.get(row.product_id);
        if (productDetails) {
          return {
            ...productDetails,
            price: row.price,
            selectedPackage: row.package,
            distributorId: row.distributor_name,
          };
        }
        return null;
      })
      .filter((p) => p !== null);

    return new Response(JSON.stringify(products), {
      headers: {
        "Content-Type": "application/json",
        "Cache-Control": "public, max-age=600, s-maxage=600", // Cache for 10 minutes
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
