import { serve } from 'http/server';

import { corsHeaders } from '../_shared/cors.ts';
import { createAdminClient } from '../_shared/supabase-client.ts';
import { errorResponse, successResponse } from '../_shared/response-utils.ts';

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const queryParams = await req.json();
    const { code, shop, hmac, ...rest } = queryParams;

    if (!code || !shop || !hmac) {
      throw new Error('Missing required parameters: code, shop, or hmac');
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

    // HMAC Validation
    // 1. Remove 'hmac' and create a map of remaining params
    const messageParams = { code, shop, ...rest };

    // 2. Sort keys lexicographically and construct query string
    const message = Object.keys(messageParams)
      .sort()
      .map(key => `${key}=${messageParams[key]}`)
      .join('&');

    // 3. Calculate HMAC
    const encoder = new TextEncoder();
    const keyData = encoder.encode(shopifyApiSecret);
    const messageData = encoder.encode(message);

    const key = await crypto.subtle.importKey(
      'raw',
      keyData,
      { name: 'HMAC', hash: 'SHA-256' },
      false,
      ['verify']
    );

    // Convert hex hmac to ArrayBuffer
    // The hmac from Shopify is a hex string. We need to parse it to a buffer or verify against it.
    // crypto.subtle.verify takes the signature as a BufferSource.

    // Helper to convert hex string to Uint8Array
    const fromHexString = (hexString: string) =>
      new Uint8Array(hexString.match(/.{1,2}/g)!.map(byte => parseInt(byte, 16)));

    const signature = fromHexString(hmac);

    const isValid = await crypto.subtle.verify(
      'HMAC',
      key,
      signature,
      messageData
    );

    if (!isValid) {
      return errorResponse('HMAC verification failed', 400);
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
      throw new Error('Failed to retrieve access token');
    }

    const supabaseAdmin = createAdminClient();

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

    return successResponse({ message: 'Shopify store connected successfully.' });

  } catch (error: any) {
    const err = error;
    // Determine appropriate status code based on error type
    let status = 500; // Default to server error
    let message = 'An internal error occurred';

    if (err.message && (err.message.includes('Missing required parameters') ||
      err.message.includes('Invalid shop domain') || err.message.includes('HMAC'))) {
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

    return errorResponse(message, status);
  }
});
