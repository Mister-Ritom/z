import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const supabase = createClient(supabaseUrl, supabaseKey);

serve(async (req: Request) => {
  try {
    const { user_id, target_id, target_type, interaction_type } = await req.json();

    if (!user_id || !target_id || !interaction_type) {
      return new Response(JSON.stringify({ error: 'Missing parameters' }), { status: 400 });
    }

    // 1. Fetch content embedding
    const { data: contentData, error: contentError } = await supabase
      .from('content_embeddings')
      .select('embedding')
      .eq('target_id', target_id)
      .eq('target_type', target_type)
      .maybeSingle();

    if (contentError || !contentData) {
      return new Response(JSON.stringify({ error: 'Content embedding not found' }), { status: 404 });
    }

    const currentEmbedding: number[] = contentData.embedding as any;

    // 2. Fetch user preference vector
    const { data: userData, error: userError } = await supabase
      .from('user_preference_vectors')
      .select('*')
      .eq('user_id', user_id)
      .maybeSingle();

    const count = userData?.interaction_count || 0;
    let positiveVector: number[] | null = userData?.positive_vector as any;
    let negativeVector: number[] | null = userData?.negative_vector as any;

    // 3. Update vectors using weighted running average
    // V_new = (V_old * N + V_curr * W) / (N + W)
    const weights: Record<string, number> = {
      'view': 1,
      'like': 3,
      'share': 5,
      'skip': 1,
      'block': 5
    };
    
    const weight = weights[interaction_type] || 1;

    if (interaction_type === 'like' || interaction_type === 'view' || interaction_type === 'share') {
      if (!positiveVector) {
        positiveVector = currentEmbedding;
      } else {
        positiveVector = positiveVector.map((val, i) => (val * count + currentEmbedding[i] * weight) / (count + weight));
      }
    } else if (interaction_type === 'skip' || interaction_type === 'block') {
      if (!negativeVector) {
        negativeVector = currentEmbedding;
      } else {
        negativeVector = negativeVector.map((val, i) => (val * count + currentEmbedding[i] * weight) / (count + weight));
      }
    }

    // 4. Upsert preference vector
    const { error: upsertError } = await supabase
      .from('user_preference_vectors')
      .upsert({
        user_id,
        positive_vector: positiveVector,
        negative_vector: negativeVector,
        interaction_count: count + weight,
        updated_at: new Date().toISOString(),
      });

    if (upsertError) throw upsertError;

    return new Response(JSON.stringify({ success: true }), {
      headers: { 'Content-Type': 'application/json' },
    });

  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
})
