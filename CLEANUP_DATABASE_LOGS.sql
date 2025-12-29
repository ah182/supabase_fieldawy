-- ==========================================
-- ملف تنظيف سجلات النظام لتوفير مساحة قاعدة البيانات
-- يستخدم لتنظيف جداول الـ Cron و الـ HTTP Responses
-- ==========================================

-- 1. تنظيف سجلات المهام المجدولة التي مضى عليها أكثر من 7 أيام
-- هذا الجدول يستهلك حوالي 32% من مساحتك حالياً
DELETE FROM cron.job_run_details 
WHERE start_time < now() - interval '7 days';

-- 2. تنظيف سجلات استجابات الـ HTTP التي مضى عليها أكثر من 7 أيام
-- هذا الجدول يستهلك حوالي 28% من مساحتك حالياً
DELETE FROM net._http_response 
WHERE created < now() - interval '7 days';

-- 3. تحسين الجداول بعد الحذف لاستعادة المساحة (اختياري)
VACUUM (ANALYZE) cron.job_run_details;
VACUUM (ANALYZE) net._http_response;

/* 
-- ملاحظة إضافية:
-- إذا أردت مسح كل السجلات تماماً فوراً (بدء صفحة جديدة)، استخدم الأوامر التالية:

TRUNCATE cron.job_run_details;
TRUNCATE net._http_response;
*/
