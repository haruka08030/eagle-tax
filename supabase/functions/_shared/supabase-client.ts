import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

export const createAuthenticatedClient = (req: Request) => {
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY');

    if (!supabaseUrl || !supabaseAnonKey) {
        throw new Error('Missing required environment variables: SUPABASE_URL or SUPABASE_ANON_KEY');
    }

    const authHeader = req.headers.get('Authorization');
    return createClient(
        supabaseUrl,
        supabaseAnonKey,
        authHeader ? { global: { headers: { Authorization: authHeader } } } : {}
    );
};

export const createAdminClient = () => {
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

    if (!supabaseUrl || !serviceRoleKey) {
        throw new Error('Missing Supabase configuration in environment variables.');
    }

    return createClient(supabaseUrl, serviceRoleKey);
};
