// Handler للإشعارات المخصصة من Dashboard
// يُضاف في نهاية ملف index.js

// 🎯 دالة معالجة الإشعارات المخصصة
async function handleCustomNotification(request, env, corsHeaders) {
  try {
    const { title, message, tokens } = await request.json();

    // Validation
    if (!title || !message || !tokens || tokens.length === 0) {
      return new Response(JSON.stringify({
        error: 'Missing required fields',
        required: ['title', 'message', 'tokens']
      }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    console.log(`📤 Sending custom notification to ${tokens.length} devices`);
    console.log(`📝 Title: ${title}`);
    console.log(`📄 Message: ${message}`);

    // Get Firebase access token
    if (!env.FIREBASE_SERVICE_ACCOUNT) {
      throw new Error('FIREBASE_SERVICE_ACCOUNT not configured');
    }

    const serviceAccount = JSON.parse(env.FIREBASE_SERVICE_ACCOUNT);
    const accessToken = await getAccessToken(serviceAccount);

    // Send notifications (batch: 500 at a time with FCM HTTP v1)
    const results = await sendBatchNotifications(
      tokens,
      title,
      message,
      accessToken,
      serviceAccount.project_id
    );

    console.log(`✅ Success: ${results.success}, ❌ Failed: ${results.failure}`);

    return new Response(JSON.stringify({
      success: results.success,
      failure: results.failure,
      total: tokens.length
    }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });

  } catch (error) {
    console.error('❌ Error sending custom notification:', error);
    return new Response(JSON.stringify({
      error: error.message
    }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
  }
}

// إرسال Batch Notifications
async function sendBatchNotifications(tokens, title, message, accessToken, projectId) {
  let successCount = 0;
  let failureCount = 0;

  // FCM HTTP v1 يدعم multicast لـ 500 token
  const batchSize = 500;
  
  for (let i = 0; i < tokens.length; i += batchSize) {
    const batch = tokens.slice(i, i + batchSize);
    
    try {
      // استخدام multicast للـ batch
      const promises = batch.map(token => 
        sendSingleNotification(token, title, message, accessToken, projectId)
      );
      
      const results = await Promise.allSettled(promises);
      
      results.forEach(result => {
        if (result.status === 'fulfilled' && result.value === true) {
          successCount++;
        } else {
          failureCount++;
        }
      });
      
      console.log(`  Batch ${Math.floor(i / batchSize) + 1}: ✅ ${successCount} ❌ ${failureCount}`);
      
    } catch (error) {
      console.error(`Batch ${i} failed:`, error);
      failureCount += batch.length;
    }
  }

  return { success: successCount, failure: failureCount };
}

// إرسال إشعار لـ token واحد
async function sendSingleNotification(token, title, message, accessToken, projectId) {
  try {
    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;
    
    const fcmMessage = {
      message: {
        token: token,
        notification: {
          title: title,
          body: message,
        },
        data: {
          title: title,
          body: message,
          type: 'custom',
          screen: 'home',
        },
        android: {
          priority: 'high',
        },
      }
    };

    const response = await fetch(fcmUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${accessToken}`,
      },
      body: JSON.stringify(fcmMessage),
    });

    if (!response.ok) {
      const error = await response.text();
      console.error(`Token failed: ${error}`);
      return false;
    }

    return true;
  } catch (error) {
    console.error(`Token send error:`, error);
    return false;
  }
}

// إضافة في نهاية index.js بعد دالة checkIfOnlyViewsUpdate:

// Helper function to check if only views or views_count column was updated
function checkIfOnlyViewsUpdate(oldRecord, newRecord) {
  const oldKeys = Object.keys(oldRecord);
  const newKeys = Object.keys(newRecord);
  
  if (oldKeys.length !== newKeys.length) {
    return false;
  }
  
  let hasChanges = false;
  let onlyViewsChanged = true;
  
  for (const key of oldKeys) {
    if (oldRecord[key] !== newRecord[key]) {
      hasChanges = true;
      
      if (key !== 'views' && key !== 'views_count' && key !== 'updated_at') {
        onlyViewsChanged = false;
        break;
      }
    }
  }
  
  return hasChanges && onlyViewsChanged;
}

// ✅ إضافة الدوال الجديدة للإشعارات المخصصة
// (انسخ handleCustomNotification, sendBatchNotifications, sendSingleNotification من الأعلى)
