// ============================================================================
// اختبار يدوي للـ Cloudflare Worker
// ============================================================================

const WEBHOOK_URL = 'https://notification-webhook.ah3181997-1e7.workers.dev';

// Test 1: طلب تقييم جديد
async function testReviewRequest() {
  console.log('🧪 Testing review_request webhook...');
  
  const payload = {
    type: 'INSERT',
    table: 'review_requests',
    record: {
      id: 'test-' + Date.now(),
      product_id: '123',
      product_type: 'product',
      product_name: 'دواء تجريبي',
      requester_name: 'مستخدم تجريبي',
      user_id: 'user-123',
      created_at: new Date().toISOString()
    }
  };
  
  try {
    const response = await fetch(WEBHOOK_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload)
    });
    
    const status = response.status;
    const text = await response.text();
    
    console.log('✅ Response:', status);
    console.log('📦 Body:', text);
    
    if (status === 200) {
      console.log('✅ Test PASSED - Worker is working!');
    } else {
      console.log('❌ Test FAILED - Status:', status);
    }
  } catch (error) {
    console.error('❌ Error:', error.message);
  }
  
  console.log('');
}

// Test 2: تعليق جديد
async function testProductReview() {
  console.log('🧪 Testing product_review webhook...');
  
  const payload = {
    type: 'INSERT',
    table: 'product_reviews',
    record: {
      id: 'test-' + Date.now(),
      review_request_id: 'req-123',
      product_id: '123',
      product_type: 'product',
      product_name: 'دواء تجريبي',
      reviewer_name: 'مراجع تجريبي',
      rating: 5,
      comment: 'تعليق تجريبي للاختبار',
      user_id: 'user-456',
      created_at: new Date().toISOString()
    }
  };
  
  try {
    const response = await fetch(WEBHOOK_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload)
    });
    
    const status = response.status;
    const text = await response.text();
    
    console.log('✅ Response:', status);
    console.log('📦 Body:', text);
    
    if (status === 200) {
      console.log('✅ Test PASSED - Worker is working!');
    } else {
      console.log('❌ Test FAILED - Status:', status);
    }
  } catch (error) {
    console.error('❌ Error:', error.message);
  }
  
  console.log('');
}

// Run tests
async function runTests() {
  console.log('');
  console.log('==============================================');
  console.log('🧪 Testing Cloudflare Worker');
  console.log('==============================================');
  console.log('');
  
  await testReviewRequest();
  await testProductReview();
  
  console.log('==============================================');
  console.log('✅ Tests completed!');
  console.log('==============================================');
  console.log('');
  console.log('💡 إذا نجحت الاختبارات:');
  console.log('   - Worker يعمل بشكل صحيح ✅');
  console.log('   - المشكلة في الـ payload من Supabase');
  console.log('');
  console.log('💡 إذا فشلت الاختبارات:');
  console.log('   - تحقق من deployment الـ Worker');
  console.log('   - راجع logs في Cloudflare Dashboard');
  console.log('');
}

runTests();
