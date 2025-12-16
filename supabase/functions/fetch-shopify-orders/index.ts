import { serve } from "http/server";
import { createClient } from "@supabase/supabase-js";
import { corsHeaders } from '../_shared/cors.ts'
import { createAuthenticatedClient } from '../_shared/supabase-client.ts'
import { errorResponse, successResponse } from '../_shared/response-utils.ts'

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
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseClient = createAuthenticatedClient(req);
    const { data: { user } } = await supabaseClient.auth.getUser()

    if (!user) {
      return errorResponse('Unauthorized', 401)
    }

    const { data: profile, error: profileError } = await supabaseClient
      .from('profiles')
      .select('shopify_access_token, shopify_shop_name')
      .eq('id', user.id)
      .single()

    if (profileError || !profile) {
      console.error('Profile fetch error:', profileError)
      return errorResponse('Profile not found or error fetching it.', 404)
    }

    const { shopify_access_token: accessToken, shopify_shop_name: shopName } = profile

    if (!shopName || !accessToken) {
      return errorResponse('Shopify integration not complete. Missing token or shop name.', 400)
    }

    const { pageUrl } = await req.json().catch(() => ({ pageUrl: null }));

    // Validate pageUrl if provided
    if (pageUrl) {
      try {
        const parsedUrl = new URL(pageUrl);
        const isValidShopifyDomain =
          parsedUrl.hostname === `${shopName}.myshopify.com` ||
          parsedUrl.hostname.endsWith('.myshopify.com');

        if (!isValidShopifyDomain) {
          return errorResponse('Invalid Shopify URL provided', 400);
        }
      } catch {
        return errorResponse('Invalid URL format', 400);
      }
    }

    const url = pageUrl ||
      `https://${shopName}.myshopify.com/admin/api/2024-01/orders.json?status=any&limit=250`

    console.log(`📦 Fetching orders from: ${url}`)

    const response = await fetch(url, {
      headers: {
        'X-Shopify-Access-Token': accessToken,
        'Content-Type': 'application/json',
      },
    })

    if (!response.ok) {
      const responseBody = await response.text();
      console.error(`Shopify API Error: ${response.status} ${response.statusText}`, responseBody);
      throw new Error(`Shopify API Error: ${response.status} ${response.statusText}. ${responseBody}`);
    }

    const data: ShopifyResponse = await response.json()

    const linkHeader = response.headers.get('link')
    let nextPageUrl: string | null = null

    if (linkHeader) {
      const links = linkHeader.split(',')
      for (const link of links) {
        if (link.includes('rel="next"')) {
          const match = link.match(/<(.+?)>/)
          if (match) {
            nextPageUrl = match[1]
          }
        }
      }
    }

    console.log(`✅ Retrieved ${data.orders.length} orders for shop ${shopName}`)
    if (nextPageUrl) {
      console.log(`📄 Next page available`)
    }

    return successResponse({
      orders: data.orders,
      nextPageUrl: nextPageUrl,
      count: data.orders.length,
    })

  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error'
    console.error('❌ Error:', errorMessage)
    return errorResponse(errorMessage, 500, {
      orders: [],
      nextPageUrl: null,
    })
  }
})

