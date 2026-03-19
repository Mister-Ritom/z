import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const supabase = createClient(supabaseUrl, supabaseKey);

const WEIGHTS: Record<string, number> = {
  'view': 1,
  'like': 3,
  'share': 5,
  'skip': 1,
  'block': 5
};

serve(async (req: Request) => {
  try {
    const { user_ids } = await req.json();

    if (!user_ids || !Array.isArray(user_ids)) {
      return new Response(JSON.stringify({ error: 'Missing user_ids array' }), { status: 400 });
    }

    const results = [];

    for (const user_id of user_ids) {
      // 1. Fetch user data (vectors + last update time)
      const { data: userData, error: userError } = await supabase
        .from('user_preference_vectors')
        .select('*')
        .eq('user_id', user_id)
        .maybeSingle();

      if (userError) continue;

      const lastUpdate = userData?.updated_at || new Date(0).toISOString();
      const currentCount = userData?.interaction_count || 0;
      let positiveVector: number[] | null = userData?.positive_vector as any;
      let negativeVector: number[] | null = userData?.negative_vector as any;

      // 2. Fetch ALL interactions since last update
      const { data: interactions, error: intError } = await supabase
        .from('user_interactions')
        .select('*, content_embeddings(embedding)')
        .eq('user_id', user_id)
        .gt('updated_at', lastUpdate);

      if (intError || !interactions || interactions.length === 0) {
        results.push({ user_id, status: 'skipped (no new interactions)' });
        continue;
      }

      // 3. Aggregate interactions
      let totalWeightAdded = 0;
      
      for (const int of interactions) {
        const embedding = (int.content_embeddings as any)?.embedding as number[];
        if (!embedding) continue;

        // Determine interaction types (can be multiple booleans)
        const activeTypes: string[] = [];
        if (int.reshared) activeTypes.push('share');
        else if (int.liked) activeTypes.push('like');
        else if (int.viewed) activeTypes.push('view');
        
        if (int.skipped) activeTypes.push('skip');

        for (const type of activeTypes) {
          const weight = WEIGHTS[type] || 1;
          const isPositive = ['share', 'like', 'view'].includes(type);
          
          if (isPositive) {
            if (!positiveVector) {
              positiveVector = [...embedding];
            } else {
              positiveVector = positiveVector.map((val, i) => (val * (currentCount + totalWeightAdded) + embedding[i] * weight) / (currentCount + totalWeightAdded + weight));
            }
          } else {
            if (!negativeVector) {
              negativeVector = [...embedding];
            } else {
              negativeVector = negativeVector.map((val, i) => (val * (currentCount + totalWeightAdded) + embedding[i] * weight) / (currentCount + totalWeightAdded + weight));
            }
          }
          totalWeightAdded += weight;
        }
      }

      // 4. Update the user vector
      if (totalWeightAdded > 0) {
        await supabase
          .from('user_preference_vectors')
          .upsert({
            user_id,
            positive_vector: positiveVector,
            negative_vector: negativeVector,
            interaction_count: currentCount + totalWeightAdded,
            updated_at: new Date().toISOString(),
          });
        results.push({ user_id, status: 'updated', weight_added: totalWeightAdded });
      }
    }

    return new Response(JSON.stringify({ success: true, results }), {
      headers: { 'Content-Type': 'application/json' },
    });

  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
})
