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

    const allProducts = [];

    // ========================================
    // 1. Fetch from distributor_products
    // ========================================
    const { data: rows, error: rowsError } = await supabase
      .from("distributor_products")
      .select("product_id, price, old_price, price_updated_at, package, distributor_name")
      .eq("distributor_id", distributorId);

    if (rowsError) throw rowsError;

    if (rows && rows.length > 0) {
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
            oldPrice: row.old_price,
            priceUpdatedAt: row.price_updated_at,
            selectedPackage: row.package,
            distributorId: row.distributor_name,
          };
        })
        .filter((p) => p !== null);

      allProducts.push(...products);
    }

    // ========================================
    // 2. Fetch from distributor_ocr_products
    // ========================================
    const { data: ocrRows, error: ocrRowsError } = await supabase
      .from("distributor_ocr_products")
      .select("ocr_product_id, price, old_price, price_updated_at, distributor_name")
      .eq("distributor_id", distributorId);

    if (ocrRowsError) throw ocrRowsError;

    if (ocrRows && ocrRows.length > 0) {
      const ocrProductIds = ocrRows.map((row) => row.ocr_product_id);

      const { data: ocrProductDocs, error: ocrProductDocsError } = await supabase
        .from("ocr_products")
        .select("*")
        .in("id", ocrProductIds);

      if (ocrProductDocsError) throw ocrProductDocsError;

      const ocrProductsMap = new Map(ocrProductDocs.map((doc) => [doc.id, doc]));

      const ocrProducts = ocrRows
        .map((row) => {
          const ocrProductData = ocrProductsMap.get(row.ocr_product_id);
          if (!ocrProductData) return null;
          return {
            id: ocrProductData.id,
            name: ocrProductData.product_name,
            company: ocrProductData.product_company,
            activePrinciple: ocrProductData.active_principle,
            imageUrl: ocrProductData.image_url,
            package: ocrProductData.package,
            availablePackages: ocrProductData.package ? [ocrProductData.package] : [],
            price: row.price,
            oldPrice: row.old_price,
            priceUpdatedAt: row.price_updated_at,
            selectedPackage: ocrProductData.package,
            distributorId: row.distributor_name,
          };
        })
        .filter((p) => p !== null);

      allProducts.push(...ocrProducts);
    }

    return new Response(JSON.stringify(allProducts), {
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
