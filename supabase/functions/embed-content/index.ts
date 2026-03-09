import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { env, pipeline, RawImage } from "https://cdn.jsdelivr.net/npm/@xenova/transformers@2.17.2"

// Speed up loading by using the local cache or a fast CDN
env.allowLocalModels = false;

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const supabase = createClient(supabaseUrl, supabaseKey);

serve(async (req: Request) => {
  try {
    const { target_id, target_type, text, media_url } = await req.json();

    if (!target_id || !target_type) {
      return new Response(JSON.stringify({ error: 'Missing target_id or target_type' }), { status: 400 });
    }

    // 1. Initialize the Tiny CLIP pipeline
    // This model is small (~80MB) and supports both text and image embeddings in the same 512d space
    const embedder = await pipeline('feature-extraction', 'Xenova/clip-vit-tiny-patch14');

    let textEmbedding = null;
    let imageEmbedding = null;

    // 2. Generate Text Embedding
    if (text) {
      const output = await embedder(text, { pooling: 'mean', normalize: true });
      textEmbedding = Array.from(output.data);
    }

    // 3. Generate Image Embedding
    if (media_url) {
      try {
        const image = await RawImage.read(media_url);
        const output = await embedder(image, { pooling: 'mean', normalize: true });
        imageEmbedding = Array.from(output.data);
      } catch (err) {
        console.error('Failed to process image:', err);
      }
    }

    // 4. Combine Embeddings
    // If we have both, we take the mean. If only one, we use that.
    let finalEmbedding = null;
    if (textEmbedding && imageEmbedding) {
      finalEmbedding = textEmbedding.map((val, i) => (val + imageEmbedding![i]) / 2);
    } else {
      finalEmbedding = textEmbedding || imageEmbedding;
    }

    if (!finalEmbedding) {
      return new Response(JSON.stringify({ error: 'No content to embed' }), { status: 400 });
    }

    // 5. Store in content_embeddings
    const { error } = await supabase
      .from('content_embeddings')
      .upsert({
        target_id,
        target_type,
        embedding: finalEmbedding,
        created_at: new Date().toISOString(),
      });

    if (error) throw error;

    return new Response(JSON.stringify({ success: true, target_id }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
})
