import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { verifyFirebasePassword, HashConfig } from "./scrypt.ts";

const FIREBASE_HASH_CONFIG: HashConfig = {
  algorithm: 'SCRYPT',
  base64_signer_key: 'z9qI3d0Oi2HY+hgGHjSwSdmIdIx8tv75jSF02Tg8S6REF/aEN+e/UEK5Pz5ru7jXGOOxUpqJMxx0I4pUhyjTbg==',
  base64_salt_separator: 'Bw==',
  rounds: 8,
  mem_cost: 14,
};

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { email, password } = await req.json();

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

    const supabase = createClient(supabaseUrl, supabaseAnonKey);
    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey);

    // 1. Attempt Supabase login normally
    const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
      email,
      password,
    });

    if (!authError) {
      return new Response(JSON.stringify(authData), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      });
    }

    // 2. If login fails, check if user exists in Firebase migration table
    if (authError.message === 'Invalid login credentials') {
      const { data: fbUser, error: fbError } = await supabaseAdmin
        .from('auth_firebase_migration')
        .select('*')
        .eq('email', email)
        .eq('migrated', false)
        .single();

      if (fbError || !fbUser) {
        return new Response(JSON.stringify({ error: 'Invalid login credentials' }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 401,
        });
      }

      if (fbUser.disabled) {
        return new Response(JSON.stringify({ error: 'User account is disabled' }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 403,
        });
      }

      // 3. Verify password using Firebase Scrypt
      const isValid = verifyFirebasePassword(
        password,
        fbUser.password_hash,
        fbUser.password_salt,
        FIREBASE_HASH_CONFIG
      );

      if (!isValid) {
        return new Response(JSON.stringify({ error: 'Invalid login credentials' }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 401,
        });
      }

      // 4. Migrate user to Supabase
      console.log(`Migrating user ${email} from Firebase to Supabase...`);
      
      const { data: newUser, error: createError } = await supabaseAdmin.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: {
          firebase_uid: fbUser.firebase_uid,
        },
      });

      if (createError) {
        console.error('Error creating Supabase user:', createError.message);
        return new Response(JSON.stringify({ error: 'Failed to migrate user' }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 500,
        });
      }

      // Store mapping
      await supabaseAdmin.from('auth_migration_map').insert({
        firebase_uid: fbUser.firebase_uid,
        supabase_uid: newUser.user.id,
        email: email,
        migration_method: 'lazy_scrypt_edge',
      });

      // Mark as migrated
      await supabaseAdmin
        .from('auth_firebase_migration')
        .update({ migrated: true })
        .eq('firebase_uid', fbUser.firebase_uid);

      // 5. Log user in through Supabase now that they are migrated
      const { data: sessionData, error: sessionError } = await supabase.auth.signInWithPassword({
        email,
        password,
      });

      if (sessionError) {
        return new Response(JSON.stringify({ error: 'Migration failed during session creation' }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 500,
        });
      }

      return new Response(JSON.stringify(sessionData), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      });
    }

    return new Response(JSON.stringify({ error: authError.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 401,
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    });
  }
});
