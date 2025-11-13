// Node.js Server لإرسال الإشعارات المخصصة
import admin from "firebase-admin";
import { readFileSync } from "fs";
import express from "express";
import cors from "cors";

// تهيئة Firebase Admin
const serviceAccount = JSON.parse(
  readFileSync("./fieldawy-store-app-66c0ffe5a54f.json", "utf8")
);

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

const app = express();
app.use(cors()); // للسماح بـ requests من Web Dashboard
app.use(express.json());

// Endpoint لإرسال إشعارات مخصصة
app.post("/send-custom-notification", async (req, res) => {
  try {
    const { title, message, tokens } = req.body;

    if (!title || !message || !tokens || tokens.length === 0) {
      return res.status(400).json({
        error: "Missing required fields",
        required: ["title", "message", "tokens"],
      });
    }

    console.log(`📤 Sending notification to ${tokens.length} devices`);
    console.log(`📝 Title: ${title}`);
    console.log(`📄 Message: ${message}`);

    // إرسال الإشعارات
    const results = await sendNotifications(tokens, title, message);

    console.log(`✅ Success: ${results.success}, ❌ Failed: ${results.failure}`);

    res.json({
      success: results.success,
      failure: results.failure,
      total: tokens.length,
    });
  } catch (error) {
    console.error("❌ Error:", error);
    res.status(500).json({
      error: error.message,
    });
  }
});

// دالة إرسال الإشعارات
async function sendNotifications(tokens, title, message) {
  let success = 0;
  let failure = 0;

  // إرسال batch (500 في المرة)
  const batchSize = 500;

  for (let i = 0; i < tokens.length; i += batchSize) {
    const batch = tokens.slice(i, i + batchSize);

    try {
      const response = await admin.messaging().sendEachForMulticast({
        tokens: batch,
        data: {
          title: title,
          body: message,
          type: "custom",
          screen: "home",
        },
        android: {
          priority: "high",
        },
      });

      success += response.successCount;
      failure += response.failureCount;

      // طباعة الأخطاء
      if (response.failureCount > 0) {
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            console.log(`  ⚠️ Token ${i + idx} failed: ${resp.error?.code}`);
          }
        });
      }
    } catch (error) {
      console.error(`❌ Batch ${i} failed:`, error.message);
      failure += batch.length;
    }
  }

  return { success, failure };
}

// Health check endpoint
app.get("/health", (req, res) => {
  res.json({ status: "ok", service: "custom-notification-server" });
});

// تشغيل Server
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  console.log("🚀 Custom Notification Server");
  console.log(`📡 Running on: http://localhost:${PORT}`);
  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  console.log("\nEndpoints:");
  console.log(`  POST /send-custom-notification`);
  console.log(`  GET  /health`);
  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");
});

export default app;
