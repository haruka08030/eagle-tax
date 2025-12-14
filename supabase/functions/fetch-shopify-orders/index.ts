// Supabase Edge Function: fetch-shopify-orders
// Shopify Admin APIから注文データを取得し、CORSとセキュリティの問題を解決

// @deno-types="https://deno.land/std@0.168.0/http/server.ts"
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

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
    // Handle CORS preflight requests
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        // リクエストボディから必要な情報を取得
        const { shopName, accessToken, pageUrl } = await req.json()

        if (!shopName || !accessToken) {
            throw new Error('shopName and accessToken are required')
        }

        // Shopify APIのURLを構築
        const url = pageUrl ||
            `https://${shopName}.myshopify.com/admin/api/2024-01/orders.json?status=any&limit=250`

        console.log(`📦 Fetching orders from: ${url}`)

        // Shopify APIにリクエスト
        const response = await fetch(url, {
            headers: {
                'X-Shopify-Access-Token': accessToken,
                'Content-Type': 'application/json',
            },
        })

        if (!response.ok) {
            throw new Error(`Shopify API Error: ${response.status} ${response.statusText}`)
        }

        const data: ShopifyResponse = await response.json()

        // Linkヘッダーから次のページのURLを取得
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

        console.log(`✅ Retrieved ${data.orders.length} orders`)
        if (nextPageUrl) {
            console.log(`📄 Next page available`)
        }

        // レスポンスを返す
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
