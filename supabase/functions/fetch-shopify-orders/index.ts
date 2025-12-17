import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsHeaders } from '../_shared/cors.ts';

interface ShopifyOrder {
    id: number;
    created_at: string;
    total_price: string;
    shipping_address?: {
        country_code?: string;
        province_code?: string;
    };
}

interface ShopifyResponse {
    orders: ShopifyOrder[];
}

serve(async (req: Request) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders });
    }

    try {
        let pageUrl: string | undefined;
        try {
            const body = await req.json();
            pageUrl = body.pageUrl;
        } catch {
            // No body or invalid JSON - proceed without pageUrl
        }
        const supabaseUrl = Deno.env.get('SUPABASE_URL');
        const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

        if (!supabaseUrl || !supabaseServiceKey) {
            throw new Error('Missing Supabase configuration in environment variables.');
        }

        const supabaseAdmin = createClient(
            supabaseUrl,
            supabaseServiceKey,
        );

        const authHeader = req.headers.get('Authorization');
        if (!authHeader) {
            throw new Error('Missing Authorization header');
        }
        const { data: { user } } = await supabaseAdmin.auth.getUser(authHeader.replace('Bearer ', ''));

        if (!user) {
            throw new Error('Could not get user from JWT');
        }

        const { data: profile, error: profileError } = await supabaseAdmin
            .from('profiles')
            .select('shopify_shop_name')
            .eq('id', user.id)
            .single();

        if (profileError || !profile) {
            throw new Error('Could not retrieve Shopify shop name from profile');
        }

        const { data: accessToken, error: rpcError } = await supabaseAdmin.rpc('get_secret', {
            name_in: `shopify_access_token_${user.id}`,
        });

        if (rpcError || !accessToken) {
            throw new Error('Could not retrieve Shopify access token');
        }

        const shopifyDomain = `${profile.shopify_shop_name}.myshopify.com`;
        const url = pageUrl ||
            `https://${shopifyDomain}/admin/api/2024-01/orders.json?status=any&limit=250`;

        // Validate pageUrl to prevent SSRF
        if (pageUrl) {
            const parsedUrl = new URL(pageUrl);
            if (parsedUrl.hostname !== shopifyDomain) {
                throw new Error('Invalid page URL: must be from your Shopify store');
            }
        }

        console.log(`📦 Fetching orders from: ${url}`);

        const response = await fetch(url, {
            headers: {
                'X-Shopify-Access-Token': accessToken,
                'Content-Type': 'application/json',
            },
        });

        if (!response.ok) {
            throw new Error(`Shopify API Error: ${response.status} ${response.statusText}`);
        }

        const data: ShopifyResponse = await response.json();
        const linkHeader = response.headers.get('link');
        let nextPageUrl: string | null = null;

        if (linkHeader) {
            const links = linkHeader.split(',');
            for (const link of links) {
                if (link.includes('rel="next"')) {
                    const match = link.match(/<(.+?)>/);
                    if (match) {
                        nextPageUrl = match[1];
                    }
                }
            }
        }

        console.log(`✅ Retrieved ${data.orders.length} orders`);
        if (nextPageUrl) {
            console.log(`📄 Next page available`);
        }

        return new Response(
            JSON.stringify({
                orders: data.orders,
                nextPageUrl: nextPageUrl,
                count: data.orders.length,
            }),
            {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 200,
            },
        );
    } catch (error) {
        const errorMessage = error instanceof Error ? error.message : 'Unknown error';
        console.error('❌ Error:', errorMessage);
        return new Response(
            JSON.stringify({
                error: errorMessage,
                orders: [],
                nextPageUrl: null,
            }),
            {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 500,
            },
        );
    }
});
