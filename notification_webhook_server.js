import admin from "firebase-admin";
import { readFileSync } from "fs";
import express from "express";
import { createClient } from "@supabase/supabase-js";

// 🔑 تهيئة Supabase Client
const supabaseUrl = process.env.SUPABASE_URL || "https://your-project.supabase.co";
const supabaseKey = process.env.SUPABASE_SERVICE_KEY || "";
const supabase = createClient(supabaseUrl, supabaseKey);

// 🔑 تهيئة Firebase Admin
const serviceAccount = process.env.FIREBASE_SERVICE_ACCOUNT 
  ? JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT)
  : JSON.parse(readFileSync("./fieldawy-store-app-66c0ffe5a54f.json", "utf8"));

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

const app = express();
app.use(express.json());

// 🎯 Webhook endpoint لاستقبال إشعارات من Supabase
app.post("/api/notify/product-change", async (req, res) => {
  try {
    // Supabase Database Webhooks ترسل payload مختلف
    const payload = req.body;
    
    // استخراج البيانات من payload
    const operation = payload.type || payload.operation; // INSERT, UPDATE, DELETE
    const table = payload.table;
    const record = payload.record || payload.new || {};
    
    console.log("📩 تلقي webhook من Supabase");
    console.log("   Operation:", operation);
    console.log("   Table:", table);
    console.log("   Record:", JSON.stringify(record).substring(0, 100));
    
    // تحديد اسم المنتج حسب الجدول
    let product_name = "منتج";
    let distributor_name = "";
    
    if (table === "products") {
      product_name = record.name || "منتج";
    } else if (table === "ocr_products") {
      product_name = record.product_name || "منتج OCR";
    } else if (table === "surgical_tools") {
      product_name = record.tool_name || "أداة جراحية";
    } else if (table === "distributor_surgical_tools") {
      // جلب اسم الأداة الحقيقي من جدول surgical_tools + الوصف
      if (record.surgical_tool_id && supabaseUrl && supabaseKey) {
        try {
          const { data, error } = await supabase
            .from('surgical_tools')
            .select('tool_name')
            .eq('id', record.surgical_tool_id)
            .single();
          
          if (data && !error && data.tool_name) {
            // اسم الأداة + الوصف
            const description = record.description || "";
            product_name = description ? `${data.tool_name} - ${description}` : data.tool_name;
          } else {
            product_name = record.description || "أداة جراحية";
          }
        } catch (err) {
          console.error("خطأ في جلب اسم الأداة:", err);
          product_name = record.description || "أداة جراحية";
        }
      } else {
        product_name = record.description || "أداة جراحية";
      }
    } else if (table === "distributor_products") {
      // جلب اسم المنتج من جدول products + اسم الموزع
      if (record.product_id && supabaseUrl && supabaseKey) {
        try {
          // جلب اسم المنتج
          const { data: productData, error: productError } = await supabase
            .from('products')
            .select('name')
            .eq('id', record.product_id)
            .single();
          
          // جلب اسم الموزع
          let distributorName = "";
          if (record.distributor_id) {
            const { data: userData, error: userError } = await supabase
              .from('users')
              .select('full_name, username')
              .eq('id', record.distributor_id)
              .single();
            
            if (userData && !userError) {
              distributorName = userData.full_name || userData.username || "";
            }
          }
          
          if (productData && !productError) {
            // اسم المنتج + اسم الموزع
            product_name = distributorName 
              ? `${productData.name} - ${distributorName}`
              : productData.name;
          } else {
            product_name = "منتج";
          }
        } catch (err) {
          console.error("خطأ في جلب اسم المنتج:", err);
          product_name = "منتج";
        }
      } else {
        product_name = "منتج";
      }
    } else if (table === "distributor_ocr_products") {
      // جلب اسم المنتج من جدول ocr_products + اسم الموزع
      if (record.ocr_product_id && supabaseUrl && supabaseKey) {
        try {
          // جلب اسم المنتج
          const { data: productData, error: productError } = await supabase
            .from('ocr_products')
            .select('product_name')
            .eq('id', record.ocr_product_id)
            .single();
          
          // جلب اسم الموزع
          let distributorName = "";
          if (record.distributor_id) {
            const { data: userData, error: userError } = await supabase
              .from('users')
              .select('full_name, username')
              .eq('id', record.distributor_id)
              .single();
            
            if (userData && !userError) {
              distributorName = userData.full_name || userData.username || "";
            }
          }
          
          if (productData && !productError) {
            // اسم المنتج + اسم الموزع
            product_name = distributorName 
              ? `${productData.product_name} - ${distributorName}`
              : productData.product_name;
          } else {
            product_name = "منتج OCR";
          }
        } catch (err) {
          console.error("خطأ في جلب اسم منتج OCR:", err);
          product_name = "منتج OCR";
        }
      } else {
        product_name = "منتج OCR";
      }
    } else if (table === "offers") {
      // إذا INSERT بدون وصف، لا نرسل إشعار (ننتظر UPDATE مع الوصف)
      if (operation === "INSERT" && !record.description) {
        console.log("⏭️ تخطي الإشعار: عرض بدون وصف (سيتم الإرسال عند إضافة الوصف)");
        return res.json({ success: true, message: "Skipped - waiting for description" });
      }
      
      // جلب اسم المنتج + وصف العرض
      if (record.product_id && supabaseUrl && supabaseKey) {
        try {
          const tableName = record.is_ocr ? 'ocr_products' : 'products';
          const columnName = record.is_ocr ? 'product_name' : 'name';
          
          const { data, error } = await supabase
            .from(tableName)
            .select(columnName)
            .eq('id', record.product_id)
            .single();
          
          if (data && !error) {
            const productName = data[columnName];
            const description = record.description || "عرض";
            // اسم المنتج - وصف العرض
            product_name = `${productName} - ${description}`;
          } else {
            product_name = record.description || "عرض";
          }
        } catch (err) {
          console.error("خطأ في جلب اسم المنتج للعرض:", err);
          product_name = record.description || "عرض";
        }
      } else {
        product_name = record.description || "عرض";
      }
    }
    
    // تحديد tab_name حسب الجدول والعملية
    let tab_name = "home";
    let isPriceUpdate = false;
    
    if (table === "distributor_products" || table === "distributor_ocr_products") {
      // فحص تاريخ الانتهاء أولاً
      let isExpiringSoon = false;
      let expirationDate = record.expiration_date;
      
      console.log("   Expiration Date in payload:", expirationDate);
      
      // إذا لم يكن expiration_date في payload، نجلبه من Supabase
      if (!expirationDate && record.id && supabaseUrl && supabaseKey) {
        console.log("   🔍 جلب expiration_date من Supabase...");
        try {
          const { data, error } = await supabase
            .from(table)
            .select('expiration_date')
            .eq('id', record.id)
            .single();
          
          if (data && !error) {
            expirationDate = data.expiration_date;
            console.log("   ✅ تم جلب expiration_date:", expirationDate);
          } else {
            console.log("   ❌ خطأ في جلب expiration_date:", error);
          }
        } catch (err) {
          console.error("   ❌ خطأ في جلب expiration_date:", err);
        }
      }
      
      // التحقق من قرب الانتهاء (خلال سنة)
      if (expirationDate) {
        const expDate = new Date(expirationDate);
        const now = new Date();
        const days = (expDate - now) / (1000 * 60 * 60 * 24);
        console.log("   Days until expiration:", days);
        if (days > 0 && days <= 365) {
          isExpiringSoon = true;
          console.log("   ✅ المنتج قارب على الانتهاء (خلال سنة)!");
        } else {
          console.log("   ℹ️ المنتج ليس قارب على الانتهاء (أكثر من سنة)");
        }
      } else {
        console.log("   ℹ️ لا يوجد expiration_date");
      }
      
      // فحص نوع التحديث
      if (operation === "UPDATE") {
        // فحص تغيير السعر
        if (payload.old_record && payload.old_record.price !== record.price) {
          isPriceUpdate = true;
          // إذا كان المنتج قارب على الانتهاء أيضاً
          if (isExpiringSoon) {
            tab_name = "expire_soon_price"; // تحديث سعر منتج قارب انتهاء
          } else {
            tab_name = "price_action";
          }
        }
        // تحديث آخر (غير السعر) لمنتج قارب انتهاء
        else if (isExpiringSoon) {
          tab_name = "expire_soon_update"; // تحديث منتج قارب انتهاء
        }
      }
      // إذا كان INSERT وقارب على الانتهاء
      else if (isExpiringSoon) {
        tab_name = "expire_soon";
      }
    } else if (table === "distributor_surgical_tools") {
      // فحص تغيير سعر الأداة
      if (operation === "UPDATE" && payload.old_record && payload.old_record.price !== record.price) {
        tab_name = "price_action";
        isPriceUpdate = true;
      } else {
        tab_name = "surgical";
      }
    } else if (table === "surgical_tools") {
      tab_name = "surgical";
    } else if (table === "offers") {
      // فحص تغيير سعر العرض
      if (operation === "UPDATE" && payload.old_record && payload.old_record.price !== record.price) {
        tab_name = "price_action";
        isPriceUpdate = true;
      } else {
        tab_name = "offers";
      }
    }
    
    console.log("   Product Name:", product_name);
    console.log("   Tab Name:", tab_name);
    
    // تخطي إشعار إضافة منتج عادي (home) - نرسل فقط expire_soon و price_action
    if ((table === "distributor_products" || table === "distributor_ocr_products") && 
        operation === "INSERT" && 
        tab_name === "home") {
      console.log("⏭️ تخطي الإشعار: إضافة منتج عادي (سيتم الإرسال فقط عند expire_soon أو price_action)");
      return res.json({ success: true, message: "Skipped - regular product insert" });
    }

    // تحديد نوع التغيير
    const isNew = operation === "INSERT";
    
    let title = "";
    let body = "";
    let tabKey = "";

    // تحديد العنوان والرسالة بناءً على tab_name (النمط البسيط)
    if (tab_name === "surgical") {
      title = isNew ? "🔧 أداة جديدة" : "🔧 تحديث أداة";
      body = product_name;
      tabKey = "surgical";
      
    } else if (tab_name === "offers") {
      title = "🎁 عرض جديد";
      body = product_name;
      tabKey = "offers";
      
    } else if (tab_name === "expire_soon_price") {
      // تحديث سعر منتج قارب على الانتهاء
      title = "💰⚠️ تحديث سعر منتج على وشك انتهاء صلاحيته";
      body = product_name;
      tabKey = "price_action";
      
    } else if (tab_name === "expire_soon_update") {
      // تحديث منتج قارب على الانتهاء (غير السعر)
      title = "🔄⚠️ تم تحديث منتج تنتهي صلاحيته قريباً";
      body = product_name;
      tabKey = "expire_soon";
      
    } else if (tab_name === "expire_soon") {
      // إضافة منتج قارب على الانتهاء
      let daysLeft = "";
      if (record.expiration_date) {
        const expDate = new Date(record.expiration_date);
        const now = new Date();
        const days = Math.ceil((expDate - now) / (1000 * 60 * 60 * 24));
        daysLeft = ` - ينتهي خلال ${days} يوم`;
      }
      title = "⚠️ تم إضافة منتج قريب الصلاحية";
      body = `${product_name}${daysLeft}`;
      tabKey = "expire_soon";
      
    } else if (tab_name === "price_action") {
      // نصوص مخصصة حسب نوع الجدول
      if (table === "distributor_surgical_tools") {
        title = "💰 تم تحديث سعر أداة";
      } else if (table === "offers") {
        title = "💰 تم تحديث سعر عرض";
      } else {
        title = "💰 تم تحديث سعر منتج";
      }
      body = product_name;
      tabKey = "price_action";
      
    } else {
      // home أو غيره
      title = isNew ? "✅ منتج جديد" : "🔄 تحديث منتج";
      body = product_name;
      tabKey = "home";
    }

    // إرسال لجميع المستخدمين عبر topic
    await sendToTopic("all_users", title, body, tabKey);

    res.json({ success: true, message: "Notification sent" });
  } catch (error) {
    console.error("❌ خطأ في معالجة webhook:", error);
    res.status(500).json({ error: error.message });
  }
});

// 🔥 إرسال إشعار لـ Topic
async function sendToTopic(topic, title, body, screen) {
  try {
    const message = {
      topic: topic,
      data: {
        title: title,
        body: body,
        type: "product_update",
        screen: screen,
      },
      android: {
        priority: "high",
      },
    };

    const response = await admin.messaging().send(message);
    console.log("✅ تم إرسال الإشعار بنجاح!");
    console.log("   Topic:", topic);
    console.log("   Title:", title);
    console.log("   Message ID:", response);
    
    return response;
  } catch (error) {
    console.error("❌ خطأ في إرسال الإشعار:", error);
    throw error;
  }
}

// دالة مساعدة للتحقق من قرب انتهاء المنتج
function isExpiringSoon(expiryDate) {
  if (!expiryDate) return false;
  
  const expiry = new Date(expiryDate);
  const today = new Date();
  const diffTime = expiry - today;
  const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
  
  // قرب الانتهاء = أقل من سنة (365 يوم)
  return diffDays > 0 && diffDays <= 365;
}

// 🚀 تشغيل السيرفر
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`🚀 Notification webhook server is running on port ${PORT}`);
  console.log(`📡 Endpoint: http://localhost:${PORT}/api/notify/product-change`);
});

export default app;
