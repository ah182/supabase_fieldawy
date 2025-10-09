import admin from "firebase-admin";
import { readFileSync } from "fs";

// تهيئة Firebase
const serviceAccount = JSON.parse(
  readFileSync("./fieldawy-store-app-66c0ffe5a54f.json", "utf8")
);

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

console.log("🔥 Firebase initialized");
console.log("📡 Project ID:", serviceAccount.project_id);

// إرسال إشعار تجريبي للـ topic
async function testTopicNotification() {
  try {
    console.log("\n📤 جاري إرسال إشعار تجريبي...");
    
    const message = {
      topic: "all_users",
      data: {
        title: "اختبار الإشعارات 🎉",
        body: "هذا إشعار تجريبي للتأكد من عمل النظام",
        type: "general",
        screen: "home",
      },
      android: {
        priority: "high",
      },
    };

    const response = await admin.messaging().send(message);
    
    console.log("✅ تم إرسال الإشعار بنجاح!");
    console.log("📬 Message ID:", response);
    console.log("\n💡 إذا لم يصل الإشعار، تحقق من:");
    console.log("   1. التطبيق مشترك في topic: all_users");
    console.log("   2. التطبيق مفتوح أو في الخلفية");
    console.log("   3. الأذونات ممنوحة للإشعارات");
    
  } catch (error) {
    console.error("❌ خطأ في إرسال الإشعار:");
    console.error(error);
  }
}

testTopicNotification();
