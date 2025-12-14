# Supabase Edge Functions - Secrets Configuration

このファイルは、Supabase Edge Functionsで使用するシークレット（機密情報）の設定方法を説明します。

## 🔐 必要なシークレット

Edge Functionで使用する機密情報:

1. **SHOPIFY_SHOP_NAME** - Shopifyストア名（例: `eagle-tax-dev-01`）
2. **SHOPIFY_ACCESS_TOKEN** - Shopify Admin API アクセストークン

## 📝 シークレットの設定方法

### 方法1: Supabase CLI（推奨）

```bash
# Supabase CLIをインストール（まだの場合）
brew install supabase/tap/supabase

# Supabaseにログイン
supabase login

# プロジェクトにリンク
supabase link --project-ref YOUR_PROJECT_REF

# シークレットを設定
supabase secrets set SHOPIFY_SHOP_NAME=your-shop-name
supabase secrets set SHOPIFY_ACCESS_TOKEN=shpat_xxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### 方法2: Supabase Dashboard

1. https://supabase.com にログイン
2. プロジェクトを選択
3. **Edge Functions** → **Secrets** を開く
4. 以下のシークレットを追加:
   - Name: `SHOPIFY_SHOP_NAME`, Value: `your-shop-name`
   - Name: `SHOPIFY_ACCESS_TOKEN`, Value: `shpat_xxxxxxxxxxxxxxxxxxxxxxxxxxxxx`

## 🚀 Edge Functionのデプロイ

```bash
# Edge Functionをデプロイ
supabase functions deploy fetch-shopify-orders

# デプロイ確認
supabase functions list
```

## 🧪 ローカルテスト

```bash
# ローカルでEdge Functionを起動
supabase start
supabase functions serve fetch-shopify-orders --env-file .env.local

# 別のターミナルでテスト
curl -i --location --request POST 'http://localhost:54321/functions/v1/fetch-shopify-orders' \
  --header 'Authorization: Bearer YOUR_ANON_KEY' \
  --header 'Content-Type: application/json' \
  --data '{"shopName":"your-shop-name","accessToken":"shpat_xxx"}'
```

## 📋 .env.local の例

ローカルテスト用の `.env.local` ファイル:

```env
SHOPIFY_SHOP_NAME=your-shop-name
SHOPIFY_ACCESS_TOKEN=shpat_xxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

**注意**: このファイルは `.gitignore` に追加してください！

## ✅ 確認方法

Edge Functionが正しくデプロイされたか確認:

```bash
# Edge Functionのログを確認
supabase functions logs fetch-shopify-orders

# Edge FunctionのURLを確認
# https://YOUR_PROJECT_REF.supabase.co/functions/v1/fetch-shopify-orders
```

## 🔒 セキュリティのベストプラクティス

1. **アクセストークンを絶対にクライアント側に保存しない**
2. **Supabase RLS（Row Level Security）を有効化**
3. **Edge Functionに認証を追加**（必要に応じて）
4. **Rate Limitingを実装**（大量リクエスト対策）

## 📚 参考資料

- [Supabase Edge Functions Documentation](https://supabase.com/docs/guides/functions)
- [Supabase CLI Reference](https://supabase.com/docs/reference/cli/introduction)
- [Shopify Admin API](https://shopify.dev/api/admin-rest)
