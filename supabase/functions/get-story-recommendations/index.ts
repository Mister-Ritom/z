import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const supabase = createClient(supabaseUrl, supabaseKey);

serve(async (req: Request) => {
  try {
    const { user_id, limit = 10 } = await req.json();

    if (!user_id) {
      return new Response(JSON.stringify({ error: 'Missing user_id' }), { status: 400 });
    }

    // 1. Fetch user preference vector
    const { data: userData, error: userError } = await supabase
      .from('user_preference_vectors')
      .select('positive_vector')
      .eq('user_id', user_id)
      .maybeSingle();

    let candidates = [];

    if (userData?.positive_vector) {
      // 2. Vector Similarity Search for Stories
      const { data: matchData, error: matchError } = await supabase.rpc('match_content', {
        query_embedding: userData.positive_vector,
        match_threshold: 0.05,
        match_count: limit * 3,
        p_content_type: 'story',
      });

      if (matchError) throw matchError;
      candidates = matchData;
    }

    // if no candidates (cold start or no vector), fetch newest stories
    if (candidates.length === 0) {
        const { data: recentStories, error: recentError } = await supabase
            .from('stories')
            .select('id')
            .eq('is_deleted', false)
            .order('created_at', { ascending: false })
            .limit(limit);
        
        if (recentError) throw recentError;
        return new Response(JSON.stringify({ recommendations: recentStories.map(s => s.id) }), {
            headers: { 'Content-Type': 'application/json' },
        });
    }

    // 3. Simple Ranking for Stories (primarily recency-based as stories are ephemeral)
    const { data: storyData, error: storyError } = await supabase
      .from('stories')
      .select('id, created_at, likes_count, views_count')
      .in('id', candidates.map((c: any) => c.target_id));

    if (storyError) throw storyError;

    const ranked = candidates.map((c: any) => {
      const story = storyData.find((s: any) => s.id === c.target_id);
      if (!story) return { id: c.target_id, score: 0 };

      const similarity = c.similarity;
      const hoursSincePosted = (Date.now() - new Date(story.created_at).getTime()) / (1000 * 60 * 60);
      const recencyScore = Math.exp(-hoursSincePosted / 12); // Shorter half-life for stories (12h)

      // Stories favor recency and similarity over high engagement
      const finalScore = (0.5 * similarity) + (0.5 * recencyScore);

      return { id: story.id, score: finalScore };
    });

    const results = ranked
      .sort((a: any, b: any) => b.score - a.score)
      .slice(0, limit)
      .map((r: any) => r.id);

    return new Response(JSON.stringify({ recommendations: results }), {
      headers: { 'Content-Type': 'application/json' },
    });

  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
})
