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

// 📱 Topics المتاحة
const TOPICS = {
  all: "all_users",        // جميع المستخدمين
  orders: "orders",        // الطلبات فقط
  offers: "offers",        // العروض فقط
  admins: "admins",        // المدراء فقط
};

// 📱 أنواع الإشعارات المختلفة
const notificationTemplates = {
  order: {
    topic: TOPICS.all,  // يرسل لجميع المستخدمين
    data: {
      title: "طلب جديد 📦",
      body: "لديك طلب جديد رقم #12345 بقيمة 750 ريال",
      type: "order",
      screen: "orders",
      order_id: "12345",
    },
  },
  offer: {
    topic: TOPICS.all,  // يرسل لجميع المستخدمين
    data: {
      title: "عرض خاص 🎉",
      body: "خصم 50% على جميع المنتجات لمدة 24 ساعة فقط!",
      type: "offer",
      screen: "offers",
    },
  },
  general: {
    topic: TOPICS.all,  // يرسل لجميع المستخدمين
    data: {
      title: "إشعار عام 🔔",
      body: "مرحباً! هذا إشعار عام من تطبيق Fieldawy Store",
      type: "general",
      screen: "home",
    },
  },
};

async function sendNotificationToTopic(type = "general") {
  console.log(`\n📤 جاري إرسال إشعار من نوع: ${type}...`);
  console.log("═══════════════════════════════════════════════════════════");

  const template = notificationTemplates[type];

  if (!template) {
    console.error(`❌ نوع الإشعار "${type}" غير موجود!`);
    console.log("الأنواع المتاحة:", Object.keys(notificationTemplates).join(", "));
    return;
  }

  try {
    // إنشاء الرسالة للإرسال إلى Topic
    const message = {
      topic: template.topic,
      data: template.data,
      android: {
        priority: "high",
      },
    };

    console.log(`📢 الإرسال إلى Topic: ${template.topic}`);
    console.log(`📝 العنوان: ${template.data.title}`);
    console.log(`📄 المحتوى: ${template.data.body}`);

    // إرسال الإشعار
    const response = await admin.messaging().send(message);

    console.log("✅ تم إرسال الإشعار بنجاح!");
    console.log("📊 Message ID:", response);
    console.log("📱 النوع:", type);
    console.log("🎯 Topic:", template.topic);
  } catch (error) {
    console.error("❌ فشل إرسال الإشعار!");
    console.error("📊 الخطأ:", error.message);
    
    if (error.code === "messaging/invalid-argument") {
      console.log("\n💡 نصيحة: تأكد من صحة Topic name");
    }
  }

  console.log("═══════════════════════════════════════════════════════════\n");
}

// 🚀 تشغيل الإشعار
const notificationType = process.argv[2] || "general";
sendNotificationToTopic(notificationType);
