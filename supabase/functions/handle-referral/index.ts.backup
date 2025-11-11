import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// CORS headers
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle preflight requests for CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { referral_code, invited_id } = await req.json()

    if (!referral_code || !invited_id) {
      throw new Error("Missing referral_code or invited_id");
    }

    // Create a Supabase client with the service role key
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // 1. Find the inviter by their referral code
    const { data: inviter, error: inviterError } = await supabaseAdmin
      .from('users')
      .select('id')
      .eq('referral_code', referral_code)
      .single()

    if (inviterError || !inviter) {
      return new Response(JSON.stringify({ error: 'Invalid referral code' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      })
    }

    const inviter_id = inviter.id;

    // Prevent users from referring themselves
    if (inviter_id === invited_id) {
      return new Response(JSON.stringify({ error: 'You cannot refer yourself' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      })
    }

    // 2. Create a new record in the referrals table
    const { error: referralError } = await supabaseAdmin
      .from('referrals')
      .insert({
        inviter_id,
        invited_id,
        status: 'completed' // Or 'pending' if you have a verification step
      })

    if (referralError) {
      // Handle potential unique constraint violation if user was already invited
      if (referralError.code === '23505') { // unique_violation
         return new Response(JSON.stringify({ error: 'This user has already been invited.' }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 409,
        })
      }
      throw referralError
    }

    // 3. Award a point to the inviter
    const { error: pointsError } = await supabaseAdmin.rpc('increment_user_points', { user_id_param: inviter_id, points_to_add: 1 });


    if (pointsError) {
      // It's important to handle this error, but the referral is already created.
      // You might want to log this for manual correction.
      console.error(`Failed to award points to user ${inviter_id}:`, pointsError);
      // Still, we return a success response to the client as the referral was successful.
    }

    return new Response(JSON.stringify({ success: true, message: 'Referral successful!' }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    })
  }
})
