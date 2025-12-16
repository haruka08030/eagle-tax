import { serve } from "http/server";
import { createClient } from "@supabase/supabase-js";
import { corsHeaders } from '../_shared/cors.ts'

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
    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')

    if (!supabaseUrl || !supabaseAnonKey) {
      throw new Error('Missing required environment variables: SUPABASE_URL or SUPABASE_ANON_KEY')
    }

    const supabaseClient = createClient(
      supabaseUrl,
      supabaseAnonKey,
      { global: { headers: { Authorization: req.headers.get('Authorization') ?? '' } } }
    )

    const { data: { user } } = await supabaseClient.auth.getUser()

    if (!user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 401,
      })
    }

    const { data: profile, error: profileError } = await supabaseClient
      .from('profiles')
      .select('shopify_access_token, shopify_shop_name')
      .eq('id', user.id)
      .single()

    if (profileError || !profile) {
      console.error('Profile fetch error:', profileError)
      return new Response(JSON.stringify({ error: 'Profile not found or error fetching it.' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 404,
      })
    }

    const { shopify_access_token: accessToken, shopify_shop_name: shopName } = profile

    if (!shopName || !accessToken) {
      return new Response(JSON.stringify({ error: 'Shopify integration not complete. Missing token or shop name.' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      })
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
          return new Response(
            JSON.stringify({ error: 'Invalid Shopify URL provided' }),
            {
              headers: { ...corsHeaders, 'Content-Type': 'application/json' },
              status: 400,
            }
          );
        }
      } catch {
        return new Response(
          JSON.stringify({ error: 'Invalid URL format' }),
          {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 400,
          }
        );
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
    )
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error'
    console.error('❌ Error:', errorMessage)
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
    )
  }
})
