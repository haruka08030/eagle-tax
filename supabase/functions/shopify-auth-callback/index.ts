import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsHeaders } from '../_shared/cors.ts';

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { code, shop } = await req.json();

    if (!code || !shop) {
      throw new Error('Missing required parameters: code and shop');
    }

    // These should be set in your Supabase project's environment variables
    const shopifyApiKey = Deno.env.get('SHOPIFY_API_KEY');
    const shopifyApiSecret = Deno.env.get('SHOPIFY_API_SECRET_KEY');

    if (!shopifyApiKey || !shopifyApiSecret) {
      throw new Error('Missing Shopify API credentials in environment variables.');
    }

    // 1. Exchange the authorization code for a permanent access token
    const tokenUrl = `https://${shop}/admin/oauth/access_token`;
    const tokenResponse = await fetch(tokenUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        client_id: shopifyApiKey,
        client_secret: shopifyApiSecret,
        code,
      }),
    });

    if (!tokenResponse.ok) {
      const errorText = await tokenResponse.text();
      throw new Error(`Failed to exchange token: ${errorText}`);
    }

    const { access_token } = await tokenResponse.json();

    if (!access_token) {
      throw new Error('Access token not found in Shopify response.');
    }

    // 2. Save the access token and shop name to the user's profile
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    );
    
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      throw new Error('Missing Authorization header');
    }
    const { data: { user } } = await supabaseAdmin.auth.getUser(authHeader.replace('Bearer ', ''));

    if (!user) {
      throw new Error('Could not get user from JWT');
    }

    const { error: updateError } = await supabaseAdmin
      .from('profiles')
      .upsert({
        id: user.id,
        shopify_shop_name: shop,
        shopify_access_token: access_token,
        updated_at: new Date().toISOString(),
      });

    if (updateError) {
      throw updateError;
    }

    return new Response(JSON.stringify({ message: 'Shopify store connected successfully.' }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });

  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    });
  }
});
