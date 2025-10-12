/**
 * Cloudflare Worker for Fieldawy Store Notifications
 * Receives webhooks from Supabase and sends FCM notifications
 */

export default {
  async fetch(request, env) {
    // CORS Headers
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    };

    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    // Only accept POST requests
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

      // Get product name and details
      let productName = 'منتج';
      let tabName = 'home';
      let isPriceUpdate = false;

      // Fetch product name based on table
      if (table === 'distributor_surgical_tools' || table === 'surgical_tools') {
        productName = record.tool_name || record.description || 'أداة جراحية';
        tabName = 'surgical';
        
        // Check price update for surgical tools
        if (operation === 'UPDATE' && old_record && old_record.price !== record.price) {
          tabName = 'price_action';
          isPriceUpdate = true;
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
                `${env.SUPABASE_URL}/rest/v1/users?id=eq.${record.distributor_id}&select=full_name,username`,
                {
                  headers: {
                    'apikey': env.SUPABASE_SERVICE_KEY,
                    'Authorization': `Bearer ${env.SUPABASE_SERVICE_KEY}`,
                  }
                }
              );
              const userData = await userResponse.json();
              if (userData && userData[0]) {
                distributorName = userData[0].full_name || userData[0].username || '';
              }
            }
            
            // For display: combine product name with distributor if available
            productName = distributorName ? `${prodName} - ${distributorName}` : prodName;
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
        
        // Skip regular product inserts
        if (operation === 'INSERT' && tabName === 'home') {
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
        body = `\n${productName}`;
        screen = 'surgical';
      } else if (tabName === 'offers') {
        title = '🎁 عرض جديد';
        body = `\n${productName}`;
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
        body = `\n${productName}${daysLeft}`;
        screen = 'expire_soon';
      } else if (tabName === 'expire_soon_price') {
        title = '💰⚠️ تحديث سعر منتج قريب الصلاحية';
        body = `\n${productName}`;
        screen = 'price_action';
      } else if (tabName === 'expire_soon_update') {
        title = '🔄⚠️ تحديث منتج قريب الصلاحية';
        body = `\n${productName}`;
        screen = 'expire_soon';
      } else if (tabName === 'price_action') {
        if (table === 'distributor_surgical_tools') {
          title = '💰 تحديث سعر أداة طبية';
        } else if (table === 'offers') {
          title = '💰 تحديث سعر عرض';
        } else {
          title = '💰 تحديث سعر منتج';
        }
        body = `\n${productName}`;
        screen = 'price_action';
      } else {
        title = isNew ? '✅ منتج جديد' : '🔄 تحديث منتج';
        body = `\n${productName}`;
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
      
      // Add distributor info for price updates from distributor products
      if (isPriceUpdate && record.distributor_id) {
        dataPayload.distributor_id = record.distributor_id;
        
        // Add separated product and distributor names for flexible handling
        if (record._product_name_only) {
          dataPayload.product_name = record._product_name_only;
        }
        if (record._distributor_name) {
          dataPayload.distributor_name = record._distributor_name;
        }
      }
      
      const message = {
        message: {
          topic: 'all_users',
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
