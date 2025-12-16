import { serve } from 'http/server';
import { createClient } from '@supabase/supabase-js';
import { corsHeaders } from '../_shared/cors.ts';

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { code, shop } = await req.json();

    if (!code || !shop) {
      throw new Error('Missing required parameters: code and shop');
    }

    const shopDomainRegex = /^[a-zA-Z0-9][a-zA-Z0-9\-]*\.myshopify\.com$/;
    if (!shopDomainRegex.test(shop)) {
      throw new Error('Invalid shop domain format');
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
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    if (access_token) {
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

    } else {
      throw new Error('Failed to retrieve access token');
    }

  } catch (error: any) {
    const err = error;
    // Determine appropriate status code based on error type
    let status = 500; // Default to server error
    let message = 'An internal error occurred';

    if (err.message && (err.message.includes('Missing required parameters') ||
      err.message.includes('Invalid shop domain'))) {
      status = 400;
      message = err.message;
    } else if (err.message && (err.message.includes('Authorization') ||
      err.message.includes('Could not get user'))) {
      status = 401;
      message = 'Authentication failed';
    } else if (err.message && err.message.includes('Failed to exchange token')) {
      status = 400;
      message = 'Invalid authorization code or shop';
    } else if (err.message) {
      message = err.message;
    }

    return new Response(JSON.stringify({ error: message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status,
    });
  }
});
