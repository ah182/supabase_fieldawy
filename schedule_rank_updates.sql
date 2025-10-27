-- This script schedules the 'update-leaderboard-ranks' function to run every minute.

SELECT cron.schedule(
  'update-leaderboard-ranks-job',
  '* * * * *', -- Every minute
  $$
  SELECT net.http_post(
    url:='https://rkukzuwerbvmueuxadul.supabase.co/functions/v1/update-leaderboard-ranks',
    headers:='{"Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJrdWt6dXdlcmJ2bXVldXhhZHVsIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1Nzg1NzA4NywiZXhwIjoyMDczNDMzMDg3fQ.NvyFIXcwJdKPZZZ9zJXP-K_3FovI6_8XtEeuip_9IGk"}'
  )
  $$
);