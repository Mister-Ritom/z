import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const supabase = createClient(supabaseUrl, supabaseKey);

serve(async (req: Request) => {
  try {
    const { user_id, content_type = 'zap', limit = 20 } = await req.json();

    if (!user_id) {
      return new Response(JSON.stringify({ error: 'Missing user_id' }), { status: 400 });
    }

    // 1. Fetch user preference vectors
    const { data: userData, error: userError } = await supabase
      .from('user_preference_vectors')
      .select('positive_vector, negative_vector')
      .eq('user_id', user_id)
      .maybeSingle();

    if (userError) throw userError;

    let candidates = [];

    if (userData?.positive_vector) {
      // 2. Vector Similarity Search
      const { data: matchData, error: matchError } = await supabase.rpc('match_content', {
        query_embedding: userData.positive_vector,
        match_threshold: 0.1, 
        match_count: limit * 5,
        p_content_type: content_type,
      });

      if (matchError) throw matchError;
      candidates = matchData;
    } else {
      // Cold start: just fetch recent popular content
      const { data: recentData, error: recentError } = await supabase
        .from(content_type === 'zap' ? 'zaps' : 'stories')
        .select('id')
        .eq('is_deleted', false)
        .order('created_at', { ascending: false })
        .limit(limit);
      
      if (recentError) throw recentError;
      return new Response(JSON.stringify({ recommendations: recentData.map(d => d.id) }), {
        headers: { 'Content-Type': 'application/json' },
      });
    }

    // 3. Rank Candidates with Hybrid Scoring
    // Fetch engagement details AND embeddings for candidates
    const table = content_type === 'zap' ? 'zaps' : 'stories';
    const { data: postData, error: postError } = await supabase
      .from(table)
      .select('id, created_at, likes_count, comments_count, shares_count, views_count')
      .in('id', candidates.map((c: any) => c.target_id));

    if (postError) throw postError;

    // Fetch embeddings for negative signal calculation
    const { data: embeddingData, error: embeddingError } = await supabase
      .from('content_embeddings')
      .select('target_id, embedding')
      .in('target_id', candidates.map((c: any) => c.target_id));

    if (embeddingError) throw embeddingError;

    const ranked = candidates.map((c: any) => {
      const post = postData.find((p: any) => p.id === c.target_id);
      const postEmbedding = (embeddingData.find((e: any) => e.target_id === c.target_id)?.embedding) as number[] | undefined;
      
      if (!post) return { id: c.target_id, score: 0 };

      // a. Cosine Similarity (0.0 to 1.0)
      const positiveSimilarity = c.similarity;

      // b. Negative Signal Penalty
      let negativePenalty = 0;
      if (userData?.negative_vector && postEmbedding) {
        // Simple dot product for similarity (assuming vectors are normalized by CLIP)
        const negativeSimilarity = postEmbedding.reduce((sum, val, i) => sum + val * (userData.negative_vector as number[])[i], 0);
        negativePenalty = Math.max(0, negativeSimilarity) * 0.4; // 40% weight to negative signals
      }

      // c. Engagement Score
      const engagement = (post.likes_count || 0) + (post.comments_count || 0) * 2 + (post.shares_count || 0) * 5; // Share weight is 5
      const engagementScore = Math.min(1.0, engagement / 100);

      // d. Recency Score
      const hoursSincePosted = (Date.now() - new Date(post.created_at).getTime()) / (1000 * 60 * 60);
      const recencyScore = Math.exp(-hoursSincePosted / 48);

      // e. Final Combined Score
      const finalScore = (0.5 * positiveSimilarity) + (0.2 * engagementScore) + (0.2 * recencyScore) - negativePenalty;

      return { id: post.id, score: finalScore };
    });

    // Sort by score and take top N
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
