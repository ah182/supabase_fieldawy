// Supabase Edge Function لحذف العروض المنتهية تلقائياً
// يتم تشغيلها بشكل دوري عبر Supabase Cron Jobs

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  try {
    // إنشاء Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    // حذف العروض القديمة (أكثر من 7 أيام من تاريخ الإنشاء)
    const sevenDaysAgo = new Date()
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7)
    
    const { data, error } = await supabase
      .from('offers')
      .delete()
      .lt('created_at', sevenDaysAgo.toISOString())

    if (error) {
      console.error('Error deleting expired offers:', error)
      return new Response(
        JSON.stringify({ error: error.message }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      )
    }

    console.log('Successfully deleted expired offers')
    return new Response(
      JSON.stringify({ 
        success: true, 
        message: 'Expired offers deleted successfully',
        deletedBefore: sevenDaysAgo.toISOString()
      }),
      { status: 200, headers: { 'Content-Type': 'application/json' } }
    )
  } catch (err) {
    console.error('Unexpected error:', err)
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
})

// لتفعيل هذه الوظيفة:
// 1. قم برفعها إلى Supabase:
//    supabase functions deploy delete-expired-offers
//
// 2. قم بجدولتها للتشغيل يومياً عبر Supabase Dashboard:
//    - اذهب إلى Database > Cron Jobs
//    - أنشئ cron job جديد:
//      - Schedule: 0 0 * * * (كل يوم في منتصف الليل)
//      - Command: select net.http_post(
//          url:='https://YOUR_PROJECT_REF.supabase.co/functions/v1/delete-expired-offers',
//          headers:='{"Content-Type": "application/json", "Authorization": "Bearer YOUR_ANON_KEY"}'::jsonb
//        );
