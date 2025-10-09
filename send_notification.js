import admin from "firebase-admin";
import { readFileSync } from "fs";

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

// 🎯 قراءة FCM Token من ملف محلي
let fcmTokenData;
try {
  fcmTokenData = JSON.parse(readFileSync("./fcm_token.json", "utf8"));
} catch (error) {
  console.error("❌ خطأ في قراءة fcm_token.json");
  fcmTokenData = { token: null };
}

const fcmToken = fcmTokenData.token;


// 📱 أنواع الإشعارات المختلفة
const notificationTemplates = {
  order: {
    notification: {
      title: "طلب جديد 📦",
      body: "لديك طلب جديد رقم #12345 بقيمة 750 ريال",
    },
    data: {
      type: "order",
      screen: "orders",
      order_id: "12345",
    },
  },
  offer: {
    notification: {
      title: "عرض خاص 🎉",
      body: "خصم 50% على جميع المنتجات لمدة 24 ساعة فقط!",
    },
    data: {
      type: "offer",
      screen: "offers",
    },
  },
  general: {
    notification: {
      title: "إشعار عام 🔔",
      body: "مرحباً! هذا إشعار عام من تطبيق Fieldawy Store",
    },
    data: {
      type: "general",
      screen: "home",
    },
  },
};

async function sendNotification(type = "general") {
  console.log(`\n📤 جاري إرسال إشعار من نوع: ${type}...`);
  console.log("═══════════════════════════════════════════════════════════");

  const template = notificationTemplates[type];

  if (!template) {
    console.error(`❌ نوع الإشعار "${type}" غير موجود!`);
    console.log("الأنواع المتاحة:", Object.keys(notificationTemplates).join(", "));
    return;
  }

  if (!fcmToken || fcmToken === "PASTE_YOUR_TOKEN_HERE_ONCE") {
    console.error("❌ يجب إضافة FCM Token أولاً!");
    console.log("\n📝 خطوات الإعداد:");
    console.log("1. شغّل التطبيق");
    console.log("2. انسخ FCM Token من console");
    console.log("3. افتح ملف fcm_token.json");
    console.log("4. ضع Token مكان \"PASTE_YOUR_TOKEN_HERE_ONCE\"");
    console.log("\n💡 تحتاج تعمل هذا مرة واحدة فقط!");
    return;
  }

  try {
    // إنشاء الرسالة باستخدام Firebase Admin SDK
    // نرسل data-only (بدون notification) لنتحكم في عرض الإشعار بالكامل
    const message = {
      token: fcmToken,
      data: {
        title: template.notification.title,
        body: template.notification.body,
        type: template.data.type,
        screen: template.data.screen,
        ...(template.data.order_id && { order_id: template.data.order_id }),
      },
      android: {
        priority: "high",
      },
    };

    // إرسال الإشعار
    const response = await admin.messaging().send(message);

    console.log("✅ تم إرسال الإشعار بنجاح!");
    console.log("📊 Message ID:", response);
    console.log("📱 النوع:", type);
    console.log("📝 العنوان:", template.notification.title);
    console.log("📄 المحتوى:", template.notification.body);
  } catch (error) {
    console.error("❌ فشل إرسال الإشعار!");
    console.error("📊 الخطأ:", error.message);
    
    if (error.code === "messaging/invalid-registration-token") {
      console.log("\n💡 نصيحة: الـ FCM Token غير صحيح أو منتهي الصلاحية");
      console.log("   - تأكد من نسخ Token كامل من console التطبيق");
      console.log("   - جرب إعادة تشغيل التطبيق للحصول على Token جديد");
    } else if (error.code === "messaging/registration-token-not-registered") {
      console.log("\n💡 نصيحة: الـ Token غير مسجل");
      console.log("   - تأكد أن التطبيق شغال على جهاز حقيقي أو محاكي فيه Google Play Services");
    }
  }

  console.log("═══════════════════════════════════════════════════════════\n");
}

// 🚀 تشغيل الإشعار
// يمكنك تغيير النوع: "order" أو "offer" أو "general"
const notificationType = process.argv[2] || "general";
sendNotification(notificationType);
