import { serve } from "http/server";
import { createClient } from "@supabase/supabase-js";
import { corsHeaders } from '../_shared/cors.ts';

serve(async (req: Request) => {
    // Handle CORS preflight requests
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders });
    }

    try {
        // 1. Authenticate the user
        const authHeader = req.headers.get('Authorization');
        if (!authHeader) {
            return new Response(JSON.stringify({ error: 'Missing Authorization header' }), {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 401,
            });
        }

        const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
        const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
        const supabaseClient = createClient(supabaseUrl, supabaseAnonKey, {
            global: { headers: { Authorization: authHeader } },
        });

        const { data: { user }, error: authError } = await supabaseClient.auth.getUser();

        if (authError || !user) {
            return new Response(JSON.stringify({ error: 'Unauthorized' }), {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 401,
            });
        }

        // 2. Parse request body
        const { shopName, redirectUri: clientRedirectUri } = await req.json();

        if (!shopName) {
            return new Response(JSON.stringify({ error: 'Shop name is required' }), {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 400,
            });
        }

        // 3. Get configuration from environment variables
        const clientId = Deno.env.get('SHOPIFY_API_KEY');
        const envRedirectUri = Deno.env.get('SHOPIFY_REDIRECT_URI');

        // Always use server-configured redirect URI for security
        const redirectUri = envRedirectUri;

        // Default scopes if not set in environment
        const scopes = Deno.env.get('SHOPIFY_SCOPES') || 'read_orders';

        if (!clientId || !redirectUri) {
            console.error("Missing server configuration: SHOPIFY_API_KEY or SHOPIFY_REDIRECT_URI");
            return new Response(JSON.stringify({ error: 'Server configuration error' }), {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 500,
            });
        }

        // 4. Construct Authorization URL
        // Validate shop name strictly to prevent injection/phishing
        const shopDomainRegex = /^[a-zA-Z0-9][a-zA-Z0-9\-]*$/; // Only the subdomain part
        if (!shopDomainRegex.test(shopName)) {
            return new Response(JSON.stringify({ error: 'Invalid shop name format. Use only the subdomain (e.g., "my-store").' }), {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 400,
            });
        }

        // Ensure shopName doesn't contain myshopify.com (client code should prune it, but we double check or handle it)
        // The client code sends just the name usually, but let's be safe.
        // If the user sends "my-store.myshopify.com", we should handle it or error. 
        // The previous client code handled trimming, let's assume input is just the name or handle consistent logic.
        // For now, construct assuming just the name. 

        const shopUrl = `${shopName}.myshopify.com`;
        const state = crypto.randomUUID();
        const url = new URL(`https://${shopUrl}/admin/oauth/authorize`);
        url.searchParams.append('client_id', clientId);
        url.searchParams.append('scope', scopes);
        url.searchParams.append('redirect_uri', redirectUri);
        url.searchParams.append('state', state);

        // 5. Return the URL and redirect URI to the client
        return new Response(
            JSON.stringify({
                authUrl: url.toString(),
                redirectUri: redirectUri
            }),
            {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 200,
            }
        );

    } catch (error) {
        console.error('Error generating auth URL:', error);
        return new Response(JSON.stringify({ error: error instanceof Error ? error.message : 'Unknown error' }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 500,
        });
    }
});
