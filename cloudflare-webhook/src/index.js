/**
 * Cloudflare Worker for Fieldawy Store Notifications
 * Receives webhooks from Supabase and sends FCM notifications
 */

export default {
  async fetch(request, env) {
    // CORS Headers
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, OPTIONS, GET',
      'Access-Control-Allow-Headers': 'Content-Type',
    };

    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    const url = new URL(request.url);

    // 🎯 Custom Notification Endpoint (من Dashboard)
    if (url.pathname === '/send-custom-notification' && request.method === 'POST') {
      return handleCustomNotification(request, env, corsHeaders);
    }

    // Health check endpoint
    if (url.pathname === '/health' && request.method === 'GET') {
      return new Response(JSON.stringify({ status: 'ok', service: 'fieldawy-notifications' }), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // Only accept POST requests for webhook
    if (request.method !== 'POST') {
      return new Response('Method not allowed', {
        status: 405,
        headers: corsHeaders
      });
    }

    try {
      const payload = await request.json();

      console.log('📩 Received webhook from Supabase');
      console.log('   Type:', payload.type);
      console.log('   Table:', payload.table);
      console.log('   Operation:', payload.type === 'INSERT' ? 'INSERT' : 'UPDATE');

      // Extract data
      const { type: operation, table, record, old_record } = payload;

      if (!record) {
        return new Response('No record in payload', {
          status: 400,
          headers: corsHeaders
        });
      }

      // 🚫 منع الإشعارات إذا كان التحديث فقط على عمود views أو views_count
      if (operation === 'UPDATE' && old_record && record) {
        const isOnlyViewsUpdate = checkIfOnlyViewsUpdate(old_record, record);
        if (isOnlyViewsUpdate) {
          console.log('⏭️ Skipping notification - only views/views_count column updated');
          return new Response('Skipped - views only update', {
            status: 200,
            headers: corsHeaders
          });
        }
      }

      // Get product name and details
      let productName = 'منتج';
      let tabName = 'home';
      let isPriceUpdate = false;

      // 📚 Handle Books notifications
      if (table === 'vet_books') {
        const bookName = record.name || 'كتاب بيطري';
        const authorName = record.author || 'مؤلف';
        const isNew = operation === 'INSERT';

        const title = isNew ? '📚 كتاب بيطري جديد' : '📚 تحديث كتاب بيطري';
        const body = isNew
          ? `${bookName}\nبواسطة ${authorName}`
          : `تم تحديث ${bookName}`;

        const extraData = {
          type: 'books',
          operation,
          book_id: record.id,
          book_name: bookName,
          author_name: authorName,
          price: record.price ? String(record.price) : '0',
        };

        return await sendFCMNotification(env, title, body, 'books', extraData);
      }

      // 🎓 Handle Courses notifications  
      if (table === 'vet_courses') {
        const courseTitle = record.title || 'كورس بيطري';
        const isNew = operation === 'INSERT';

        const title = isNew ? '🎓 كورس بيطري جديد' : '🎓 تحديث كورس بيطري';
        const body = isNew
          ? `${courseTitle}`
          : `تم تحديث ${courseTitle}`;

        const extraData = {
          type: 'courses',
          operation,
          course_id: record.id,
          course_title: courseTitle,
          price: record.price ? String(record.price) : '0',
        };

        return await sendFCMNotification(env, title, body, 'courses', extraData);
      }

      // 💼 Handle Job Offers notifications
      if (table === 'job_offers') {
        const jobTitle = record.title || 'وظيفة بيطرية';
        const isNew = operation === 'INSERT';

        const title = isNew ? '💼 وظيفة بيطرية جديدة' : '💼 تحديث وظيفة بيطرية';
        const body = isNew
          ? `${jobTitle}`
          : `تم تحديث ${jobTitle}`;

        const extraData = {
          type: 'job_offers',
          operation,
          job_id: record.id,
          job_title: jobTitle,
          phone: record.phone || null,
        };

        return await sendFCMNotification(env, title, body, 'job_offers', extraData);
      }

      // 🏥 Handle Vet Supplies notifications
      if (table === 'vet_supplies') {
        const supplyName = record.name || 'مستلزم بيطري';
        const isNew = operation === 'INSERT';

        const title = isNew ? '🏥 مستلزم بيطري جديد' : '🏥 تحديث مستلزم بيطري';
        const body = isNew
          ? `${supplyName}`
          : `تم تحديث ${supplyName}`;

        const extraData = {
          type: 'vet_supplies',
          operation,
          supply_id: record.id,
          supply_name: supplyName,
          price: record.price ? String(record.price) : null,
          phone: record.phone || null,
        };

        return await sendFCMNotification(env, title, body, 'vet_supplies', extraData);
      }

      // Handle review requests
      if (table === 'review_requests') {
        // فقط للإضافات الجديدة (INSERT)
        if (operation !== 'INSERT') {
          console.log('⏭️ Skipping non-INSERT operation on review_requests');
          return new Response('Skipped - not an INSERT', {
            status: 200,
            headers: corsHeaders
          });
        }

        let productName = record.product_name || 'منتج';
        let requesterName = 'مستخدم';

        // جلب اسم صاحب الطلب من users
        if (env.SUPABASE_URL && env.SUPABASE_SERVICE_KEY && record.requested_by) {
          try {
            const userResponse = await fetch(
              `${env.SUPABASE_URL}/rest/v1/users?id=eq.${record.requested_by}&select=display_name,email`,
              {
                headers: {
                  'apikey': env.SUPABASE_SERVICE_KEY,
                  'Authorization': `Bearer ${env.SUPABASE_SERVICE_KEY}`,
                }
              }
            );
            const userData = await userResponse.json();
            if (userData && userData[0]) {
              requesterName = userData[0].display_name || userData[0].email || 'مستخدم';
            }
          } catch (err) {
            console.error('Error fetching requester data:', err);
          }
        }

        tabName = 'reviews';

        const title = '⭐ طلب تقييم جديد';
        const body = `طلب ${requesterName} تقييم ${productName}`;

        return await sendFCMNotification(env, title, body, 'reviews', {
          type: 'new_review_request',
          review_request_id: record.id,
          product_id: record.product_id,
          product_type: record.product_type,
        });
      }

      // Handle product reviews (comments)
      if (table === 'product_reviews') {
        // فقط للإضافات الجديدة (INSERT)
        if (operation !== 'INSERT') {
          console.log('⏭️ Skipping non-INSERT operation on product_reviews');
          return new Response('Skipped - not an INSERT', {
            status: 200,
            headers: corsHeaders
          });
        }

        // ✅ ✅ ✅ تجاهل التقييمات بدون تعليق!
        const comment = record.comment || '';
        if (!comment || comment.trim() === '') {
          console.log('⏭️ Skipping - no comment (rating only)');
          return new Response('Skipped - no comment', {
            status: 200,
            headers: corsHeaders
          });
        }

        let productName = 'منتج';
        let reviewerName = 'مستخدم';
        const rating = record.rating || 0;

        // جلب البيانات من Supabase
        if (env.SUPABASE_URL && env.SUPABASE_SERVICE_KEY) {
          try {
            // جلب اسم المنتج من review_requests
            if (record.review_request_id) {
              const reqResponse = await fetch(
                `${env.SUPABASE_URL}/rest/v1/review_requests?id=eq.${record.review_request_id}&select=product_name`,
                {
                  headers: {
                    'apikey': env.SUPABASE_SERVICE_KEY,
                    'Authorization': `Bearer ${env.SUPABASE_SERVICE_KEY}`,
                  }
                }
              );
              const reqData = await reqResponse.json();
              if (reqData && reqData[0] && reqData[0].product_name) {
                productName = reqData[0].product_name;
              }
            }

            // جلب اسم المراجع من users
            if (record.user_id) {
              const userResponse = await fetch(
                `${env.SUPABASE_URL}/rest/v1/users?id=eq.${record.user_id}&select=display_name,email`,
                {
                  headers: {
                    'apikey': env.SUPABASE_SERVICE_KEY,
                    'Authorization': `Bearer ${env.SUPABASE_SERVICE_KEY}`,
                  }
                }
              );
              const userData = await userResponse.json();
              if (userData && userData[0]) {
                reviewerName = userData[0].display_name || userData[0].email || 'مستخدم';
              }
            }
          } catch (err) {
            console.error('Error fetching user/product data:', err);
          }
        }

        tabName = 'reviews';

        // رسالة واضحة عن التقييم
        const title = `⭐ تم تقييم ${productName}`;
        const body = `${reviewerName} (${rating}⭐): ${comment}`;

        return await sendFCMNotification(env, title, body, 'reviews', {
          type: 'new_product_review',
          review_id: record.id,
          review_request_id: record.review_request_id,
          product_id: record.product_id,
          product_type: record.product_type,
          rating: String(rating), // ✅ تحويل لـ string
        });
      }

      // Fetch product name based on table
      if (table === 'distributor_surgical_tools' || table === 'surgical_tools') {
        productName = record.tool_name || record.description || 'أداة جراحية';
        tabName = 'surgical';

        // Check price update for surgical tools
        if (operation === 'UPDATE' && old_record && old_record.price !== record.price) {
          tabName = 'price_action';
          isPriceUpdate = true;
        }

        // Fetch distributor name if available
        if (record.distributor_id && env.SUPABASE_URL && env.SUPABASE_SERVICE_KEY) {
          try {
            const userResponse = await fetch(
              `${env.SUPABASE_URL}/rest/v1/users?id=eq.${record.distributor_id}&select=display_name,email`,
              {
                headers: {
                  'apikey': env.SUPABASE_SERVICE_KEY,
                  'Authorization': `Bearer ${env.SUPABASE_SERVICE_KEY}`,
                }
              }
            );
            const userData = await userResponse.json();
            if (userData && userData[0]) {
              const distributorName = userData[0].display_name || userData[0].email || '';
              if (distributorName) {
                // Combine distributor name with product name
                productName = `${distributorName}\n${productName}`;
              }
            }
          } catch (err) {
            console.error('Error fetching distributor for surgical tool:', err);
          }
        }
      } else if (table === 'offers') {
        // Skip offers without description
        if (operation === 'INSERT' && !record.description) {
          console.log('⏭️ Skipping offer without description');
          return new Response('Skipped - waiting for description', {
            status: 200,
            headers: corsHeaders
          });
        }

        // Get product name from Supabase
        if (record.product_id && env.SUPABASE_URL && env.SUPABASE_SERVICE_KEY) {
          try {
            const tableName = record.is_ocr ? 'ocr_products' : 'products';
            const columnName = record.is_ocr ? 'product_name' : 'name';

            const response = await fetch(
              `${env.SUPABASE_URL}/rest/v1/${tableName}?id=eq.${record.product_id}&select=${columnName}`,
              {
                headers: {
                  'apikey': env.SUPABASE_SERVICE_KEY,
                  'Authorization': `Bearer ${env.SUPABASE_SERVICE_KEY}`,
                }
              }
            );

            const data = await response.json();
            if (data && data[0]) {
              const prodName = data[0][columnName];
              const description = record.description || 'عرض';
              productName = `${prodName} - ${description}`;
            } else {
              productName = record.description || 'عرض';
            }
          } catch (err) {
            console.error('Error fetching product name:', err);
            productName = record.description || 'عرض';
          }
        } else {
          productName = record.description || 'عرض';
        }

        // Check price update for offers
        if (operation === 'UPDATE' && old_record && old_record.price !== record.price) {
          tabName = 'price_action';
          isPriceUpdate = true;
        } else {
          tabName = 'offers';
        }
      } else if (table === 'distributor_products' || table === 'distributor_ocr_products') {
        // Get product name and distributor name separately for flexible notification
        let prodName = 'منتج';
        let distributorName = '';

        if (env.SUPABASE_URL && env.SUPABASE_SERVICE_KEY) {
          try {
            // Fetch product name
            if (table === 'distributor_products' && record.product_id) {
              const prodResponse = await fetch(
                `${env.SUPABASE_URL}/rest/v1/products?id=eq.${record.product_id}&select=name`,
                {
                  headers: {
                    'apikey': env.SUPABASE_SERVICE_KEY,
                    'Authorization': `Bearer ${env.SUPABASE_SERVICE_KEY}`,
                  }
                }
              );
              const prodData = await prodResponse.json();
              if (prodData && prodData[0]) {
                prodName = prodData[0].name;
              }
            } else if (table === 'distributor_ocr_products' && record.ocr_product_id) {
              const prodResponse = await fetch(
                `${env.SUPABASE_URL}/rest/v1/ocr_products?id=eq.${record.ocr_product_id}&select=product_name`,
                {
                  headers: {
                    'apikey': env.SUPABASE_SERVICE_KEY,
                    'Authorization': `Bearer ${env.SUPABASE_SERVICE_KEY}`,
                  }
                }
              );
              const prodData = await prodResponse.json();
              if (prodData && prodData[0]) {
                prodName = prodData[0].product_name;
              }
            }

            // Fetch distributor name
            if (record.distributor_id) {
              const userResponse = await fetch(
                `${env.SUPABASE_URL}/rest/v1/users?id=eq.${record.distributor_id}&select=display_name,email`,
                {
                  headers: {
                    'apikey': env.SUPABASE_SERVICE_KEY,
                    'Authorization': `Bearer ${env.SUPABASE_SERVICE_KEY}`,
                  }
                }
              );
              const userData = await userResponse.json();
              console.log('   Fetched distributor data:', userData);
              if (userData && userData[0]) {
                distributorName = userData[0].display_name || userData[0].email || '';
                console.log('   Distributor name:', distributorName);
              }
            }

            // Combine product name and distributor name for all users
            // Client will display this directly
            if (distributorName) {
              productName = `${distributorName}\n${prodName}`;
            } else {
              productName = prodName;
            }
          } catch (err) {
            console.error('Error fetching product/distributor:', err);
            productName = 'منتج';
          }
        }

        // Store separately for flexible client-side handling
        record._product_name_only = prodName;
        record._distributor_name = distributorName;

        // Check expiration date
        let isExpiringSoon = false;
        let expirationDate = record.expiration_date;

        // Fetch expiration_date if not in payload
        if (!expirationDate && record.id && env.SUPABASE_URL && env.SUPABASE_SERVICE_KEY) {
          try {
            const response = await fetch(
              `${env.SUPABASE_URL}/rest/v1/${table}?id=eq.${record.id}&select=expiration_date`,
              {
                headers: {
                  'apikey': env.SUPABASE_SERVICE_KEY,
                  'Authorization': `Bearer ${env.SUPABASE_SERVICE_KEY}`,
                }
              }
            );
            const data = await response.json();
            if (data && data[0]) {
              expirationDate = data[0].expiration_date;
            }
          } catch (err) {
            console.error('Error fetching expiration_date:', err);
          }
        }

        // Check if expiring soon (within 365 days)
        if (expirationDate) {
          const expDate = new Date(expirationDate);
          const now = new Date();
          const days = (expDate - now) / (1000 * 60 * 60 * 24);
          if (days > 0 && days <= 365) {
            isExpiringSoon = true;
          }
        }

        // Determine tab_name
        if (operation === 'UPDATE') {
          if (old_record && old_record.price !== record.price) {
            isPriceUpdate = true;
            tabName = isExpiringSoon ? 'expire_soon_price' : 'price_action';
          } else if (isExpiringSoon) {
            tabName = 'expire_soon_update';
          }
        } else if (isExpiringSoon) {
          tabName = 'expire_soon';
        }

        // Skip regular product inserts (but NOT from distributors)
        // Distributor products should trigger notifications for subscribers
        if (operation === 'INSERT' && tabName === 'home' &&
          table !== 'distributor_products' && table !== 'distributor_ocr_products') {
          console.log('⏭️ Skipping regular product insert');
          return new Response('Skipped - regular product insert', {
            status: 200,
            headers: corsHeaders
          });
        }
      }

      console.log('   Product Name:', productName);
      console.log('   Tab Name:', tabName);

      // Build notification message
      const isNew = operation === 'INSERT';
      let title = '';
      let body = '';
      let screen = '';

      if (tabName === 'surgical') {
        title = isNew ? '🩺 أداة طبية جديدة' : '🩺 تحديث أداة طبية';
        body = productName;
        screen = 'surgical';
      } else if (tabName === 'offers') {
        title = '🎁 عرض جديد';
        body = productName;
        screen = 'offers';
      } else if (tabName === 'expire_soon') {
        let daysLeft = '';
        if (record.expiration_date) {
          const expDate = new Date(record.expiration_date);
          const now = new Date();
          const days = Math.ceil((expDate - now) / (1000 * 60 * 60 * 24));
          daysLeft = ` - ينتهي خلال ${days} يوم`;
        }
        title = '⚠️ منتج قريب الصلاحية';
        body = `${productName}${daysLeft}`;
        screen = 'expire_soon';
      } else if (tabName === 'expire_soon_price') {
        title = '💰⚠️ تحديث سعر منتج قريب الصلاحية';
        body = productName;
        screen = 'expire_soon';
      } else if (tabName === 'expire_soon_update') {
        title = '🔄⚠️ تحديث منتج قريب الصلاحية';
        body = productName;
        screen = 'expire_soon';
      } else if (tabName === 'price_action') {
        // فحص: لو INSERT يبقى منتج جديد، مش تحديث سعر
        if (isNew) {
          if (table === 'distributor_surgical_tools') {
            title = '🩺 أداة طبية جديدة';
            screen = 'surgical';
          } else if (table === 'distributor_products' || table === 'distributor_ocr_products') {
            title = '✅ منتج جديد من موزع';
            screen = 'home';
          } else {
            title = '✅ منتج جديد';
            screen = 'home';
          }
        } else {
          // UPDATE - تحديث سعر
          if (table === 'distributor_surgical_tools' || table === 'surgical_tools') {
            title = '💰 تحديث سعر أداة طبية';
            screen = 'surgical';
          } else if (table === 'offers') {
            title = '💰 تحديث سعر عرض';
            screen = 'offers';
          } else {
            title = '💰 تحديث سعر منتج';
            screen = 'price_action';
          }
        }
        body = productName;
      } else {
        title = isNew ? '✅ منتج جديد' : '🔄 تحديث منتج';
        body = productName;
        screen = 'home';
      }

      // Send FCM notification
      if (!env.FIREBASE_SERVICE_ACCOUNT) {
        throw new Error('FIREBASE_SERVICE_ACCOUNT not configured');
      }

      const serviceAccount = JSON.parse(env.FIREBASE_SERVICE_ACCOUNT);
      const accessToken = await getAccessToken(serviceAccount);

      const fcmUrl = `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`;

      // Build data payload with flexible fields for client-side customization
      const dataPayload = {
        title: title,
        body: body,
        type: 'product_update',
        screen: screen,
      };

      // Add distributor info for all distributor products (new or price update)
      if (record.distributor_id && (table === 'distributor_products' || table === 'distributor_ocr_products' || table === 'distributor_surgical_tools')) {
        dataPayload.distributor_id = record.distributor_id;

        // Use the combined productName (which includes distributor name)
        // This ensures all users see the distributor name
        dataPayload.product_name = productName;

        // Do NOT send distributor_name separately to prevent client from duplicating it
        // if (record._distributor_name) {
        //   dataPayload.distributor_name = record._distributor_name;
        // }
      }

      const message = {
        message: {
          topic: 'all_users',
          // ✅ data only - background handler will show customized notification
          data: dataPayload,
          android: {
            priority: 'high',
          },
        }
      };

      const fcmResponse = await fetch(fcmUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${accessToken}`,
        },
        body: JSON.stringify(message),
      });

      if (!fcmResponse.ok) {
        const error = await fcmResponse.text();
        throw new Error(`FCM Error: ${error}`);
      }

      console.log('✅ Notification sent successfully!');
      console.log('   Title:', title);

      return new Response('Notification sent', {
        status: 200,
        headers: corsHeaders
      });

    } catch (error) {
      console.error('❌ Error:', error);
      return new Response(`Error: ${error.message}`, {
        status: 500,
        headers: corsHeaders
      });
    }
  },
};

// Helper function to send FCM notification
async function sendFCMNotification(env, title, body, screen, extraData = {}) {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  };

  try {
    if (!env.FIREBASE_SERVICE_ACCOUNT) {
      throw new Error('FIREBASE_SERVICE_ACCOUNT not configured');
    }

    const serviceAccount = JSON.parse(env.FIREBASE_SERVICE_ACCOUNT);
    const accessToken = await getAccessToken(serviceAccount);

    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`;

    const dataPayload = {
      title: title,
      body: body,
      screen: screen,
      ...extraData,
    };

    const message = {
      message: {
        topic: 'all_users',
        // ✅ notification: يظهر عندما التطبيق مقفول/background
        notification: {
          title: title,
          body: body,
        },
        // ✅ data: للتعامل معه في التطبيق
        data: dataPayload,
        android: {
          priority: 'high',
        },
      }
    };

    const fcmResponse = await fetch(fcmUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${accessToken}`,
      },
      body: JSON.stringify(message),
    });

    if (!fcmResponse.ok) {
      const error = await fcmResponse.text();
      throw new Error(`FCM Error: ${error}`);
    }

    console.log('✅ Notification sent successfully!');
    console.log('   Title:', title);

    return new Response('Notification sent', {
      status: 200,
      headers: corsHeaders
    });

  } catch (error) {
    console.error('❌ Error:', error);
    return new Response(`Error: ${error.message}`, {
      status: 500,
      headers: corsHeaders
    });
  }
}

// Helper function to get Firebase access token
async function getAccessToken(serviceAccount) {
  const jwtHeader = btoa(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));

  const now = Math.floor(Date.now() / 1000);
  const jwtClaimSet = {
    iss: serviceAccount.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    exp: now + 3600,
    iat: now,
  };

  const jwtClaimSetEncoded = btoa(JSON.stringify(jwtClaimSet));
  const signatureInput = `${jwtHeader}.${jwtClaimSetEncoded}`;

  // Import private key
  const privateKey = await crypto.subtle.importKey(
    'pkcs8',
    pemToArrayBuffer(serviceAccount.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign']
  );

  // Sign
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    privateKey,
    new TextEncoder().encode(signatureInput)
  );

  const jwtSignature = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');

  const jwt = `${signatureInput}.${jwtSignature}`;

  // Exchange JWT for access token
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });

  const data = await response.json();
  return data.access_token;
}

// Helper to convert PEM to ArrayBuffer
function pemToArrayBuffer(pem) {
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s/g, '');

  const binary = atob(b64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}

// Helper function to check if only views or views_count column was updated
function checkIfOnlyViewsUpdate(oldRecord, newRecord) {
  // تحويل الكائنات لمصفوفات من المفاتيح
  const oldKeys = Object.keys(oldRecord);
  const newKeys = Object.keys(newRecord);

  // التحقق من أن عدد الحقول متساوٍ
  if (oldKeys.length !== newKeys.length) {
    return false;
  }

  let hasChanges = false;
  let onlyViewsChanged = true;

  // فحص كل حقل
  for (const key of oldKeys) {
    if (oldRecord[key] !== newRecord[key]) {
      hasChanges = true;

      // إذا تغير حقل غير views أو views_count أو updated_at، فهذا ليس تحديث views فقط
      if (key !== 'views' && key !== 'views_count' && key !== 'updated_at') {
        onlyViewsChanged = false;
        break;
      }
    }
  }

  // إرجاع true إذا كان هناك تغييرات وكانت فقط على views أو views_count أو updated_at
  return hasChanges && onlyViewsChanged;
}

// =====================================================
// 🎯 Custom Notifications Handler (من Dashboard)
// =====================================================

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

    // Send notifications (batch: 500 at a time)
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
        // ✅ data only - لتجنب تكرار الإشعار
        // notification سيتم عرضها من التطبيق نفسه
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
