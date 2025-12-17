import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { corsHeaders } from '../_shared/cors.ts';

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { shop_name } = await req.json();

    if (!shop_name) {
      throw new Error('Missing required parameter: shop_name');
    }

    // Validate shop_name format (alphanumeric and hyphens only)
    if (!/^[a-zA-Z0-9][a-zA-Z0-9\-]*$/.test(shop_name)) {
      throw new Error('Invalid shop_name format. Only alphanumeric characters and hyphens are allowed.');
    }

    const shopifyApiKey = Deno.env.get('SHOPIFY_API_KEY');
    const redirectUri = Deno.env.get('SHOPIFY_REDIRECT_URI');
    const scopes = 'read_orders';

    if (!shopifyApiKey || !redirectUri) {
      throw new Error('Missing Shopify API credentials in environment variables.');
    }

    const authUrl = `https://${shop_name}.myshopify.com/admin/oauth/authorize?client_id=${encodeURIComponent(shopifyApiKey)}&scope=${encodeURIComponent(scopes)}&redirect_uri=${encodeURIComponent(redirectUri)}`;

    return new Response(
      JSON.stringify({ authUrl }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    });
  }
});
