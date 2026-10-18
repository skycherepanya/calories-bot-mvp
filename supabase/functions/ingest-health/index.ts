import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const INGEST_SECRET = Deno.env.get('INGEST_SECRET');
const ALLOWED_USER_ID = Deno.env.get('ALLOWED_USER_ID') ? parseInt(Deno.env.get('ALLOWED_USER_ID')!) : null;

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || Deno.env.get('SUPABASE_ANON_KEY')!
);

const SHIFT_HOURS = 4;

function dietaryDate(isoString: string): string {
  const dt = new Date(isoString);
  dt.setHours(dt.getHours() - SHIFT_HOURS);
  return dt.toISOString().split('T')[0];
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  let body: any;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: 'Invalid JSON body' }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  // 1. Authentication check
  if (!INGEST_SECRET || body.secret !== INGEST_SECRET) {
    return new Response(JSON.stringify({ error: 'Unauthorized: invalid secret' }), {
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  // 2. User authorization check
  const userId = Number(body.user_id);
  if (!userId) {
    return new Response(JSON.stringify({ error: 'Missing or invalid user_id' }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  if (ALLOWED_USER_ID && userId !== ALLOWED_USER_ID) {
    return new Response(JSON.stringify({ error: 'Forbidden: user_id not allowed' }), {
      status: 403,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  const inserted = { daily_activity: false, sleep: false, workout: false };
  const errors: Record<string, string> = {};

  // 3. Insert or update daily activity (NEAT & lifestyle steps/kcal)
  if (body.daily_activity) {
    const a = body.daily_activity;
    const metricDate = a.date || dietaryDate(new Date().toISOString());
    const { error } = await supabase.from('daily_metrics').upsert({
      user_id: userId,
      metric_date: metricDate,
      steps: a.steps != null ? Math.round(Number(a.steps)) : null,
      active_kcal: a.active_kcal != null ? Number(a.active_kcal) : null,
      distance_km: a.distance_km != null ? Number(a.distance_km) : null,
      source: 'apple_health',
    }, { onConflict: 'user_id,metric_date' });

    if (error) {
      console.error('[ingest-health] daily_activity upsert error:', error);
      errors.daily_activity = error.message;
    } else {
      inserted.daily_activity = true;
    }
  }

  // 4. Insert or update sleep log
  if (body.sleep) {
    const s = body.sleep;
    if (s.sleep_date) {
      const { error } = await supabase.from('sleep_logs').upsert({
        user_id: userId,
        source: 'apple_health',
        sleep_date: s.sleep_date,
        total_hours: s.total_hours != null ? Number(s.total_hours) : null,
        deep_hours: s.deep_hours != null ? Number(s.deep_hours) : null,
        rem_hours: s.rem_hours != null ? Number(s.rem_hours) : null,
        core_hours: s.core_hours != null ? Number(s.core_hours) : null,
        awake_hours: s.awake_hours != null ? Number(s.awake_hours) : null,
        hrv_avg_ms: s.hrv_avg_ms != null ? Number(s.hrv_avg_ms) : null,
        rhr_bpm: s.rhr_bpm != null ? Number(s.rhr_bpm) : null,
        vo2max: s.vo2max != null ? Number(s.vo2max) : null,
      }, { onConflict: 'user_id,sleep_date' });

      if (error) {
        console.error('[ingest-health] sleep upsert error:', error);
        errors.sleep = error.message;
      } else {
        inserted.sleep = true;
      }
    } else {
      errors.sleep = 'Missing sleep_date';
    }
  }

  // 5. Insert workout record
  if (body.workout) {
    const w = body.workout;
    const startedAt = w.started_at || new Date().toISOString();
    const durationMin = Number(w.duration_min) || 0;
    const distanceKm = w.distance_km != null ? Number(w.distance_km) : null;
    const avgPace = w.avg_pace_min_km != null
      ? Number(w.avg_pace_min_km)
      : (distanceKm && durationMin ? +(durationMin / distanceKm).toFixed(2) : null);

    const workoutPayload = {
      user_id: userId,
      workout_type: w.type || w.workout_type || 'other',
      source: 'apple_health',
      started_at: startedAt,
      duration_min: durationMin,
      distance_km: distanceKm,
      avg_heart_rate: w.avg_heart_rate != null ? Number(w.avg_heart_rate) : null,
      max_heart_rate: w.max_heart_rate != null ? Number(w.max_heart_rate) : null,
      active_kcal: (w.active_calories ?? w.active_kcal) != null ? Number(w.active_calories ?? w.active_kcal) : null,
      avg_pace_min_km: avgPace,
      elevation_m: w.elevation_m != null ? Number(w.elevation_m) : null,
      dietary_date: dietaryDate(startedAt),
      notes: w.notes || null,
      raw_data: w,
    };

    // Deduplicate: check if workout at this exact start time already exists
    const { data: existingWorkout } = await supabase
      .from('workouts')
      .select('id')
      .eq('user_id', userId)
      .eq('started_at', startedAt)
      .maybeSingle();

    let error: any;
    if (existingWorkout) {
      const res = await supabase.from('workouts').update(workoutPayload).eq('id', existingWorkout.id);
      error = res.error;
    } else {
      const res = await supabase.from('workouts').insert(workoutPayload);
      error = res.error;
    }

    if (error) {
      console.error('[ingest-health] workout upsert error:', error);
      errors.workout = error.message;
    } else {
      inserted.workout = true;
    }
  }

  return new Response(JSON.stringify({ ok: true, inserted, errors }), {
    status: 200,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
});
