import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// اختبار سريع لدالة زيادة المشاهدات
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // تهيئة Supabase (استخدم بياناتك الفعلية)
  // await Supabase.initialize(url: 'YOUR_URL', anonKey: 'YOUR_KEY');
  
  await testIncrementJobViews();
}

Future<void> testIncrementJobViews() async {
  final supabase = Supabase.instance.client;
  
  try {
    print('🧪 Testing increment_job_views function...');
    
    // الحصول على أول وظيفة من قاعدة البيانات
    final jobs = await supabase.rpc('get_all_job_offers');
    
    if (jobs.isEmpty) {
      print('❌ No jobs found in database');
      return;
    }
    
    final firstJob = jobs[0];
    final jobId = firstJob['id'];
    final currentViews = firstJob['views_count'];
    
    print('📝 Job ID: $jobId');
    print('📊 Current views: $currentViews');
    
    // اختبار زيادة المشاهدات
    await supabase.rpc('increment_job_views', params: {
      'p_job_id': jobId,
    });
    
    print('✅ increment_job_views called successfully');
    
    // التحقق من النتيجة
    await Future.delayed(Duration(seconds: 1)); // انتظار قصير
    
    final updatedJobs = await supabase.rpc('get_all_job_offers');
    final updatedJob = updatedJobs.firstWhere((job) => job['id'] == jobId);
    final newViews = updatedJob['views_count'];
    
    print('📊 New views: $newViews');
    
    if (newViews > currentViews) {
      print('🎉 SUCCESS: Views increased from $currentViews to $newViews');
    } else {
      print('❌ FAILED: Views did not increase');
    }
    
  } catch (e) {
    print('❌ Error testing increment_job_views: $e');
  }
}