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

    const allProducts = [];

    // ========================================
    // 1. Fetch from distributor_products
    // ========================================
    const { data: rows, error: rowsError } = await supabase
      .from('distributor_products')
      .select('*')
      .order('added_at', { ascending: false });

    if (rowsError) throw rowsError;

    if (rows && rows.length > 0) {
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
              oldPrice: row.old_price,
              priceUpdatedAt: row.price_updated_at,
              selectedPackage: row.package,
              distributorId: row.distributor_name,
            };
          }
          return null;
        })
        .filter((p) => p !== null);
      
      allProducts.push(...products);
    }

    // ========================================
    // 2. Fetch from distributor_ocr_products
    // ========================================
    const { data: ocrRows, error: ocrRowsError } = await supabase
      .from('distributor_ocr_products')
      .select('*')
      .order('created_at', { ascending: false });

    if (ocrRowsError) throw ocrRowsError;

    if (ocrRows && ocrRows.length > 0) {
      // Get unique OCR product IDs
      const ocrProductIds = [...new Set(ocrRows.map((row) => row.ocr_product_id as string))];

      // Fetch OCR product details
      const { data: ocrProductDocs, error: ocrProductDocsError } = await supabase
        .from('ocr_products')
        .select('*')
        .in('id', ocrProductIds);

      if (ocrProductDocsError) throw ocrProductDocsError;

      const ocrProductsMap = new Map(ocrProductDocs.map((doc) => [doc.id, doc]));

      // Combine the OCR data
      const ocrProducts = ocrRows
        .map((row) => {
          const ocrProductData = ocrProductsMap.get(row.ocr_product_id);
          if (ocrProductData) {
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
          }
          return null;
        })
        .filter((p) => p !== null);
      
      allProducts.push(...ocrProducts);
    }

    return new Response(JSON.stringify(allProducts), {
      headers: {
        "Content-Type": "application/json",
        "Cache-Control": "public, max-age=1800, s-maxage=1800", // Cache for 30 minutes
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
