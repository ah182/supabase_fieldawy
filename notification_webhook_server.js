import admin from "firebase-admin";
import { readFileSync } from "fs";
import express from "express";

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
    if (table === "products") {
      product_name = record.name || "منتج";
    } else if (table === "ocr_products") {
      product_name = record.product_name || "منتج OCR";
    } else if (table === "surgical_tools") {
      product_name = record.tool_name || "أداة جراحية";
    } else if (table === "distributor_surgical_tools") {
      product_name = record.description || "أداة جراحية";
    } else if (table === "offers") {
      product_name = record.description || "عرض";
    }
    
    // تحديد tab_name حسب الجدول والعملية
    let tab_name = "home";
    if (table === "surgical_tools" || table === "distributor_surgical_tools") {
      tab_name = "surgical";
    } else if (table === "offers") {
      tab_name = "offers";
    } else if (table === "distributor_products" || table === "distributor_ocr_products") {
      // فحص تغيير السعر
      if (operation === "UPDATE" && payload.old_record && payload.old_record.price !== record.price) {
        tab_name = "price_action";
      }
      // فحص تاريخ الانتهاء
      else if (record.expiration_date) {
        const expDate = new Date(record.expiration_date);
        const now = new Date();
        const days = (expDate - now) / (1000 * 60 * 60 * 24);
        if (days > 0 && days <= 60) {
          tab_name = "expire_soon";
        }
      }
    }
    
    console.log("   Product Name:", product_name);
    console.log("   Tab Name:", tab_name);

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
      
    } else if (tab_name === "expire_soon") {
      // حساب عدد الأيام المتبقية
      let daysLeft = "";
      if (record.expiration_date) {
        const expDate = new Date(record.expiration_date);
        const now = new Date();
        const days = Math.ceil((expDate - now) / (1000 * 60 * 60 * 24));
        daysLeft = ` - ينتهي خلال ${days} يوم`;
      }
      title = "⚠️ تنبيه انتهاء";
      body = `${product_name}${daysLeft}`;
      tabKey = "expire_soon";
      
    } else if (tab_name === "price_action") {
      title = "💰 تحديث السعر";
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
  
  // قرب الانتهاء = أقل من 60 يوم
  return diffDays > 0 && diffDays <= 60;
}

// 🚀 تشغيل السيرفر
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`🚀 Notification webhook server is running on port ${PORT}`);
  console.log(`📡 Endpoint: http://localhost:${PORT}/api/notify/product-change`);
});

export default app;
