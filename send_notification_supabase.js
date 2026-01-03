import admin from "firebase-admin";
import { readFileSync } from "fs";
import { createClient } from "@supabase/supabase-js";

// 🔑 قراءة Service Account من الملف
const serviceAccount = JSON.parse(
  readFileSync("./fieldawy-store-app-66c0ffe5a54f.json", "utf8")
);

// تهيئة Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

// 🔑 تهيئة Supabase Client بمفتاح الـ Service Role
const SUPABASE_URL = "https://rkukzuwerbvmueuxadul.supabase.co";
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SUPABASE_SERVICE_ROLE_KEY) {
  console.error("❌ ERROR: SUPABASE_SERVICE_ROLE_KEY is not defined in environment variables.");
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

// 📱 أنواع الإشعارات المختلفة
const notificationTemplates = {
  order: {
    data: {
      title: "طلب جديد 📦",
      body: "لديك طلب جديد رقم #12345 بقيمة 750 ريال",
      type: "order",
      screen: "orders",
      order_id: "12345",
    },
  },
  offer: {
    data: {
      title: "عرض خاص 🎉",
      body: "خصم 50% على جميع المنتجات لمدة 24 ساعة فقط!",
      type: "offer",
      screen: "offers",
    },
  },
  general: {
    data: {
      title: "إشعار عام 🔔",
      body: "مرحباً! هذا إشعار عام من تطبيق Fieldawy Store",
      type: "general",
      screen: "home",
    },
  },
};

// 🔧 الحصول على جميع Tokens من Supabase
async function getAllTokens() {
  try {
    const { data, error } = await supabase.rpc("get_all_active_tokens");

    if (error) {
      console.error("❌ خطأ في قراءة Tokens من Supabase:", error.message);
      return [];
    }

    console.log(`✅ تم الحصول على ${data.length} token من Supabase`);
    return data.map((row) => row.token);
  } catch (error) {
    console.error("❌ خطأ في الاتصال بـ Supabase:", error.message);
    return [];
  }
}

// 🔧 الحصول على tokens مستخدم محدد
async function getUserTokens(userId) {
  try {
    const { data, error } = await supabase.rpc("get_user_tokens", {
      p_user_id: userId,
    });

    if (error) {
      console.error("❌ خطأ في قراءة Tokens المستخدم:", error.message);
      return [];
    }

    return data.map((row) => row.token);
  } catch (error) {
    console.error("❌ خطأ في الاتصال بـ Supabase:", error.message);
    return [];
  }
}

// 📤 إرسال إشعار لجميع المستخدمين
async function sendToAll(type = "general") {
  console.log(`\n📤 جاري إرسال إشعار من نوع: ${type} لجميع المستخدمين...`);
  console.log("═══════════════════════════════════════════════════════════");

  const template = notificationTemplates[type];

  if (!template) {
    console.error(`❌ نوع الإشعار "${type}" غير موجود!`);
    return;
  }

  // التحقق من إعدادات Supabase
  if (SUPABASE_URL === "YOUR_SUPABASE_URL") {
    console.error("❌ يجب إضافة SUPABASE_URL أولاً!");
    console.log("📝 افتح send_notification_supabase.js وأضف:");
    console.log("   - SUPABASE_URL من Project Settings > API");
    console.log("   - SUPABASE_SERVICE_ROLE_KEY من Project Settings > API");
    return;
  }

  try {
    // الحصول على جميع Tokens
    const tokens = await getAllTokens();

    if (tokens.length === 0) {
      console.log("⚠️ لا توجد tokens محفوظة في قاعدة البيانات");
      console.log("💡 تأكد من تسجيل الدخول في التطبيق أولاً");
      return;
    }

    console.log(`📱 سيتم الإرسال إلى ${tokens.length} جهاز`);
    console.log(`📝 العنوان: ${template.data.title}`);
    console.log(`📄 المحتوى: ${template.data.body}`);

    // إرسال لجميع الأجهزة
    const results = await sendToMultipleTokens(tokens, template.data);

    console.log("═══════════════════════════════════════════════════════════");
    console.log(`✅ نجح: ${results.success} | ❌ فشل: ${results.failure}`);
    console.log("═══════════════════════════════════════════════════════════\n");
  } catch (error) {
    console.error("❌ خطأ عام:", error.message);
  }
}

// 📤 إرسال إشعار لمستخدم محدد
async function sendToUser(userId, type = "general") {
  console.log(`\n📤 جاري إرسال إشعار من نوع: ${type} للمستخدم: ${userId}...`);
  console.log("═══════════════════════════════════════════════════════════");

  const template = notificationTemplates[type];

  if (!template) {
    console.error(`❌ نوع الإشعار "${type}" غير موجود!`);
    return;
  }

  try {
    const tokens = await getUserTokens(userId);

    if (tokens.length === 0) {
      console.log("⚠️ لا توجد tokens لهذا المستخدم");
      return;
    }

    console.log(`📱 سيتم الإرسال إلى ${tokens.length} جهاز للمستخدم`);

    const results = await sendToMultipleTokens(tokens, template.data);

    console.log("═══════════════════════════════════════════════════════════");
    console.log(`✅ نجح: ${results.success} | ❌ فشل: ${results.failure}`);
    console.log("═══════════════════════════════════════════════════════════\n");
  } catch (error) {
    console.error("❌ خطأ عام:", error.message);
  }
}

// 📤 إرسال لعدة tokens
async function sendToMultipleTokens(tokens, data) {
  let successCount = 0;
  let failureCount = 0;

  // إرسال بشكل متوازي (batch)
  const batchSize = 500; // Firebase يسمح بـ 500 في المرة الواحدة
  
  for (let i = 0; i < tokens.length; i += batchSize) {
    const batch = tokens.slice(i, i + batchSize);
    
    try {
      const response = await admin.messaging().sendEachForMulticast({
        tokens: batch,
        data: data,
        android: {
          priority: "high",
        },
      });

      successCount += response.successCount;
      failureCount += response.failureCount;

      // طباعة Tokens الفاشلة
      if (response.failureCount > 0) {
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            console.log(`  ⚠️ فشل Token ${i + idx}: ${resp.error?.code}`);
          }
        });
      }
    } catch (error) {
      console.error(`❌ خطأ في إرسال Batch: ${error.message}`);
      failureCount += batch.length;
    }
  }

  return { success: successCount, failure: failureCount };
}

// 🚀 تنفيذ الأوامر
const command = process.argv[2]; // all, user
const type = process.argv[3] || "general"; // order, offer, general
const userId = process.argv[4]; // في حالة user

if (command === "all") {
  sendToAll(type);
} else if (command === "user" && userId) {
  sendToUser(userId, type);
} else {
  console.log("📝 طريقة الاستخدام:");
  console.log("");
  console.log("إرسال لجميع المستخدمين:");
  console.log("  node send_notification_supabase.js all [order|offer|general]");
  console.log("");
  console.log("إرسال لمستخدم محدد:");
  console.log("  node send_notification_supabase.js user [order|offer|general] [user_id]");
  console.log("");
  console.log("أمثلة:");
  console.log("  npm run supabase:all:order");
  console.log("  npm run supabase:user:order abc123-...");
}
