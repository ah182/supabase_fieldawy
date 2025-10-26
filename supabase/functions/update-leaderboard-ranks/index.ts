import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

console.log('Update leaderboard ranks function initialized');

serve(async (req) => {
  try {
    // Create a Supabase client with the service role key
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { auth: { persistSession: false } }
    );

    console.log('Fetching users to update ranks...');

    // 1. Fetch all user IDs, ordered by points descending
    const { data: users, error: fetchError } = await supabaseAdmin
      .from('users')
      .select('id')
      .order('points', { ascending: false });

    if (fetchError) {
      throw fetchError;
    }

    if (!users || users.length === 0) {
      console.log('No users found to update.');
      return new Response(JSON.stringify({ success: true, message: 'No users to update.' }), {
        headers: { 'Content-Type': 'application/json' },
        status: 200,
      });
    }

    console.log(`Found ${users.length} users. Preparing rank updates...`);

    // 2. Prepare the data for a bulk update
    const updates = users.map((user, index) => ({
      id: user.id,
      rank: index + 1,
    }));

    // 3. Perform the bulk update using upsert
    const { error: updateError } = await supabaseAdmin
      .from('users')
      .upsert(updates);

    if (updateError) {
      throw updateError;
    }

    const message = `Successfully updated ranks for ${updates.length} users.`;
    console.log(message);

    return new Response(JSON.stringify({ success: true, message }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    });

  } catch (error) {
    console.error('Error updating user ranks:', error.message);
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { 'Content-Type': 'application/json' },
      status: 500,
    });
  }
});
