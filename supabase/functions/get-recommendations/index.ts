import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const supabase = createClient(supabaseUrl, supabaseKey);

serve(async (req: Request) => {
  try {
    const { user_id, content_type = 'zap', limit = 20, feed_type = 'personalized' } = await req.json();

    if (!user_id) {
      return new Response(JSON.stringify({ error: 'Missing user_id' }), { status: 400 });
    }

    const table = content_type === 'zap' ? 'zaps' : 'stories';
    const last24h = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();

    // 1. Fetch user preference vectors and interaction count
    const { data: userData, error: userError } = await supabase
      .from('user_preference_vectors')
      .select('positive_vector, negative_vector, interaction_count')
      .eq('user_id', user_id)
      .maybeSingle();

    if (userError) throw userError;

    // Helper: Calculation for engagement score
    const getEngagementScore = (p: any) => {
      const shares = p.shares_count || 0;
      const comments = p.comments_count || 0;
      const likes = p.likes_count || 0;
      const views = p.views_count || 0;
      return (shares * 5) + (comments * 2) + (likes * 1) + (views * 0.1);
    };

    // --- MODE: VIRAL FEED ---
    if (feed_type === 'viral') {
      const { data: viralData, error: viralError } = await supabase
        .from(table)
        .select('id, created_at, likes_count, comments_count, shares_count, views_count')
        .eq('is_deleted', false)
        .gt('created_at', last24h)
        .order('created_at', { ascending: false }) // Initial filter
        .limit(200);

      if (viralError) throw viralError;

      const rankedViral = viralData
        .map(p => {
          const score = getEngagementScore(p);
          // Gravity: older posts need higher engagement to stay up
          const ageHours = (Date.now() - new Date(p.created_at).getTime()) / (1000 * 60 * 60);
          const gravityScore = score / Math.pow(ageHours + 2, 1.8);
          return { id: p.id, score: gravityScore };
        })
        .sort((a, b) => b.score - a.score)
        .slice(0, limit)
        .map(r => r.id);

      return new Response(JSON.stringify({ recommendations: rankedViral }), {
        headers: { 'Content-Type': 'application/json' },
      });
    }

    // --- MODE: PERSONALIZED FEED (with Sprinkling) ---
    const isColdStart = !userData || (userData.interaction_count || 0) < 5;

    // A. Get Personalized Candidates
    let personalIds: string[] = [];
    if (!isColdStart && userData.positive_vector) {
      const { data: matchData, error: matchError } = await supabase.rpc('match_content', {
        query_embedding: userData.positive_vector,
        match_threshold: 0.1,
        match_count: limit * 2, // Get more for ranking
        p_content_type: content_type,
      });
      if (matchError) throw matchError;
      personalIds = matchData.map((m: any) => m.target_id);
    }

    // B. Get Trending/Viral Candidates (Discovery)
    const { data: trendingData, error: trendingError } = await supabase
      .from(table)
      .select('id, created_at, likes_count, comments_count, shares_count, views_count')
      .eq('is_deleted', false)
      .gt('created_at', last24h)
      .limit(50);
    
    if (trendingError) throw trendingError;
    const trendingIds = trendingData
      .map(p => ({ id: p.id, score: getEngagementScore(p) / Math.pow((Date.now() - new Date(p.created_at).getTime())/(1000*3600) + 2, 1.5) }))
      .sort((a, b) => b.score - a.score)
      .map(r => r.id);

    // C. Get Random New Candidates (Discovery)
    const { data: randomData, error: randomError } = await supabase
      .from(table)
      .select('id')
      .eq('is_deleted', false)
      .order('created_at', { ascending: false })
      .limit(30);
    
    if (randomError) throw randomError;
    const discoveryIds = randomData.map(d => d.id).sort(() => Math.random() - 0.5);

    // D. Interleave Results (80% Personal, 10% Trending, 10% Random)
    const finalResults = new Set<string>();
    
    for (let i = 0; i < limit; i++) {
      if (isColdStart) {
        // Just interleave trending and discovery for new users
        if (i % 2 === 0 && trendingIds.length > 0) finalResults.add(trendingIds.shift()!);
        else if (discoveryIds.length > 0) finalResults.add(discoveryIds.shift()!);
      } else {
        const rand = i % 10;
        if (rand < 8 && personalIds.length > 0) finalResults.add(personalIds.shift()!);
        else if (rand === 8 && trendingIds.length > 0) finalResults.add(trendingIds.shift()!);
        else if (discoveryIds.length > 0) finalResults.add(discoveryIds.shift()!);
      }
      if (finalResults.size >= limit) break;
    }

    // Fill remaining if sets were too small
    const remaining = [...personalIds, ...trendingIds, ...discoveryIds];
    while (finalResults.size < limit && remaining.length > 0) {
      finalResults.add(remaining.shift()!);
    }

    return new Response(JSON.stringify({ recommendations: Array.from(finalResults) }), {
      headers: { 'Content-Type': 'application/json' },
    });

  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
})
