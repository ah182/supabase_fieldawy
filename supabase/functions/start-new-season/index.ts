import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

console.log('Start New Leaderboard Season function initialized');

serve(async (req) => {
  try {
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { auth: { persistSession: false } }
    );

    // 1. Find the current active season
    console.log('Searching for active season...');
    const { data: activeSeasons, error: findError } = await supabaseAdmin
      .from('leaderboard_seasons')
      .select('id')
      .eq('is_active', true);

    if (findError) throw findError;

    // 2. If a season is active, end it and archive results.
    if (activeSeasons.length > 0) {
      const activeSeason = activeSeasons[0];
      console.log(`Ending season ${activeSeason.id}...`);

      // 2a. Archive rankings for users with points > 0
      const { data: usersToArchive, error: usersError } = await supabaseAdmin
        .from('users')
        .select('id, points, rank')
        .gt('points', 0);

      if (usersError) throw usersError;

      if (usersToArchive && usersToArchive.length > 0) {
        const rankingsToInsert = usersToArchive.map(user => ({
          season_id: activeSeason.id,
          user_id: user.id,
          final_rank: user.rank,
          final_points: user.points,
        }));

        const { error: archiveError } = await supabaseAdmin
          .from('season_rankings')
          .insert(rankingsToInsert);

        if (archiveError) throw archiveError;
        console.log(`Archived ${rankingsToInsert.length} user rankings.`);
      }

      // 2b. Deactivate the old season
      const { error: deactivateError } = await supabaseAdmin
        .from('leaderboard_seasons')
        .update({ is_active: false })
        .eq('id', activeSeason.id);
      if (deactivateError) throw deactivateError;
      console.log(`Season ${activeSeason.id} has been deactivated.`);
    }

    // 3. Reset all user points and ranks
    console.log('Resetting user points and ranks...');
    const { error: resetError } = await supabaseAdmin
      .from('users')
      .update({ points: 0, rank: null })
      .gt('points', 0); // Only update users who actually have points

    if (resetError) throw resetError;

    // 4. Create the new season
    console.log('Starting new season...');
    const now = new Date();
    const startDate = now.toISOString();
    // Set end date to the last second of the last day of the current month
    const endDate = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59, 999).toISOString();

    const { data: newSeason, error: createError } = await supabaseAdmin
      .from('leaderboard_seasons')
      .insert({
        start_date: startDate,
        end_date: endDate,
        is_active: true,
      })
      .select();

    if (createError) throw createError;

    const message = `Successfully started new season ${newSeason?.[0]?.id}.`;
    console.log(message);

    return new Response(JSON.stringify({ success: true, message }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    });

  } catch (error) {
    console.error('Error starting new season:', error.message);
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { 'Content-Type': 'application/json' },
      status: 500,
    });
  }
});
