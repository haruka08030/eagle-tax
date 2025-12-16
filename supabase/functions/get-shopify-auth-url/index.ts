import { serve } from "http/server";
import { corsHeaders } from '../_shared/cors.ts';
import { createAuthenticatedClient } from '../_shared/supabase-client.ts';
import { errorResponse, successResponse } from '../_shared/response-utils.ts';

serve(async (req: Request) => {
    // Handle CORS preflight requests
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders });
    }

    try {
        // 1. Authenticate the user
        const authHeader = req.headers.get('Authorization');
        if (!authHeader) {
            return errorResponse('Missing Authorization header', 401);
        }

        const supabaseClient = createAuthenticatedClient(req);

        const { data: { user }, error: authError } = await supabaseClient.auth.getUser();

        if (authError || !user) {
            return errorResponse('Unauthorized', 401);
        }

        // 2. Parse request body
        const { shopName, redirectUri: clientRedirectUri } = await req.json();

        if (!shopName) {
            return errorResponse('Shop name is required', 400);
        }

        // 3. Get configuration from environment variables
        const clientId = Deno.env.get('SHOPIFY_API_KEY');
        const envRedirectUri = Deno.env.get('SHOPIFY_REDIRECT_URI');

        // Allow client to override redirect URI for local development (e.g. localhost:3000)
        const redirectUri = clientRedirectUri || envRedirectUri;

        // Default scopes if not set in environment
        const scopes = Deno.env.get('SHOPIFY_SCOPES') || 'read_orders';

        if (!clientId || !redirectUri) {
            console.error("Missing server configuration: SHOPIFY_API_KEY or SHOPIFY_REDIRECT_URI");
            return errorResponse('Server configuration error');
        }

        // 4. Construct Authorization URL
        // Validate shop name strictly to prevent injection/phishing
        // Only the subdomain part
        const shopDomainRegex = /^[a-zA-Z0-9][a-zA-Z0-9\-]*$/;
        if (!shopDomainRegex.test(shopName)) {
            return errorResponse('Invalid shop name format. Use only the subdomain (e.g., "my-store").', 400);
        }

        // Ensure shopName doesn't contain myshopify.com 
        const shopUrl = `${shopName}.myshopify.com`;
        const state = crypto.randomUUID();
        const url = new URL(`https://${shopUrl}/admin/oauth/authorize`);
        url.searchParams.append('client_id', clientId);
        url.searchParams.append('scope', scopes);
        url.searchParams.append('redirect_uri', redirectUri);
        url.searchParams.append('state', state);

        // 5. Return the URL, redirect URI, and state to the client
        return successResponse({
            authUrl: url.toString(),
            redirectUri: redirectUri,
            state: state
        });

    } catch (error) {
        console.error('Error generating auth URL:', error);
        return errorResponse(error instanceof Error ? error.message : 'Unknown error', 500);
    }
});

