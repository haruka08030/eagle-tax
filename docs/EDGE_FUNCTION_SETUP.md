# Supabase Edge Functions セットアップガイド

## 🎯 概要

Shopify Admin APIはブラウザからの直接アクセスを許可していません（CORS制限）。
この問題を解決するため、Supabase Edge Functionsを使用してサーバーサイドでAPIを呼び出します。

### メリット

✅ **セキュリティ**: アクセストークンをクライアント側に露出しない  
✅ **CORS回避**: サーバーサイドからAPIを呼び出すため、CORS制限なし  
✅ **集中管理**: 認証情報をSupabaseで一元管理  
✅ **スケーラブル**: Supabaseのインフラで自動スケール  

---

## 📋 前提条件

1. **Supabase CLI**をインストール
2. **Supabaseプロジェクト**を作成済み
3. **Shopify Access Token**を取得済み

---

## 🚀 セットアップ手順

### Step 1: Supabase CLIのインストール

```bash
# Homebrewを使用（Mac）
brew install supabase/tap/supabase

# または、npm経由
npm install -g supabase

# インストール確認
supabase --version
```

### Step 2: Supabaseにログイン

```bash
# ブラウザでログイン画面が開きます
supabase login
```

### Step 3: プロジェクトにリンク

```bash
# プロジェクトディレクトリに移動
cd /Users/haruka08030/Development/eagle_tax

# Supabaseプロジェクトにリンク
supabase link --project-ref YOUR_PROJECT_REF
```

**PROJECT_REFの確認方法:**
1. https://supabase.com にログイン
2. プロジェクトを選択
3. Settings → General → Reference ID

### Step 4: シークレットを設定

```bash
# Shopify認証情報をSupabaseシークレットとして保存
supabase secrets set SHOPIFY_SHOP_NAME=your-shop-name
supabase secrets set SHOPIFY_ACCESS_TOKEN=shpat_xxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# 設定確認
supabase secrets list
```

### Step 5: Edge Functionをデプロイ

```bash
# Edge Functionをデプロイ
supabase functions deploy fetch-shopify-orders

# デプロイ確認
supabase functions list
```

成功すると、以下のようなURLが表示されます:
```
https://YOUR_PROJECT_REF.supabase.co/functions/v1/fetch-shopify-orders
```

---

## 🧪 テスト方法

### ローカルテスト

```bash
# Supabaseをローカルで起動
supabase start

# Edge Functionをローカルで実行
supabase functions serve fetch-shopify-orders

# 別のターミナルでテスト
curl -i --location --request POST \
  'http://localhost:54321/functions/v1/fetch-shopify-orders' \
  --header 'Authorization: Bearer YOUR_ANON_KEY' \
  --header 'Content-Type: application/json' \
  --data '{
    "shopName": "your-shop-name",
    "accessToken": "shpat_xxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
  }'
```

### 本番環境テスト

```bash
curl -i --location --request POST \
  'https://YOUR_PROJECT_REF.supabase.co/functions/v1/fetch-shopify-orders' \
  --header 'Authorization: Bearer YOUR_ANON_KEY' \
  --header 'Content-Type: application/json' \
  --header 'apikey: YOUR_ANON_KEY' \
  --data '{
    "shopName": "your-shop-name",
    "accessToken": "shpat_xxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
  }'
```

**期待されるレスポンス:**
```json
{
  "orders": [...],
  "nextPageUrl": "https://...",
  "count": 250
}
```

---

## 📝 .envファイルの更新

`.env`ファイルから、Shopify認証情報を削除できます（オプション）:

```env
# Supabase設定
SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

# Shopify設定（Edge Functionで使用するため、ローカルテスト用に残す）
SHOPIFY_SHOP_NAME=your-shop-name
SHOPIFY_ACCESS_TOKEN=shpat_xxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

---

## 🔍 ログの確認

### Edge Functionのログを確認

```bash
# リアルタイムでログを表示
supabase functions logs fetch-shopify-orders --follow

# 最新100件のログを表示
supabase functions logs fetch-shopify-orders --limit 100
```

### Supabase Dashboardでログを確認

1. https://supabase.com にログイン
2. プロジェクトを選択
3. **Edge Functions** → **fetch-shopify-orders** → **Logs**

---

## 🔄 更新とデプロイ

Edge Functionのコードを更新した場合:

```bash
# 再デプロイ
supabase functions deploy fetch-shopify-orders

# 特定のバージョンを確認
supabase functions list
```

---

## ⚠️ トラブルシューティング

### エラー: "Edge Function Error: 500"

**原因**: Shopify認証情報が正しくない、またはAPIエラー

**解決策**:
1. シークレットが正しく設定されているか確認
   ```bash
   supabase secrets list
   ```
2. Edge Functionのログを確認
   ```bash
   supabase functions logs fetch-shopify-orders
   ```

### エラー: "CORS policy"

**原因**: Edge FunctionのCORSヘッダーが正しく設定されていない

**解決策**:
- `index.ts`の`corsHeaders`を確認
- OPTIONSリクエストが正しく処理されているか確認

### エラー: "Unauthorized"

**原因**: Supabase Anon Keyが正しくない

**解決策**:
1. `.env`ファイルの`SUPABASE_ANON_KEY`を確認
2. Supabase Dashboard → Settings → API → Project API keys

---

## 📊 パフォーマンス

### Edge Functionのコールドスタート

- 初回リクエスト: ~1-2秒
- 以降のリクエスト: ~100-300ms

### Rate Limit

- Supabase Edge Functions: 制限なし（フェアユース）
- Shopify API: 2リクエスト/秒

---

## 🔒 セキュリティのベストプラクティス

### 1. Row Level Security (RLS)

将来的に、ユーザー認証を追加する場合:

```sql
-- usersテーブルにRLSを設定
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can only access their own data"
ON users FOR SELECT
USING (auth.uid() = id);
```

### 2. Edge Functionの認証

現在は`SUPABASE_ANON_KEY`で認証していますが、将来的にはユーザー認証を追加:

```typescript
// Edge Function内で
const authHeader = req.headers.get('Authorization')
const token = authHeader?.replace('Bearer ', '')
const { data: { user }, error } = await supabaseClient.auth.getUser(token)

if (error || !user) {
  return new Response('Unauthorized', { status: 401 })
}
```

### 3. Rate Limiting

大量リクエスト対策として、Upstashなどを使用したRate Limitingを実装:

```typescript
import { Ratelimit } from "@upstash/ratelimit"

const ratelimit = new Ratelimit({
  redis: Redis.fromEnv(),
  limiter: Ratelimit.slidingWindow(10, "10 s"),
})

const { success } = await ratelimit.limit(identifier)
if (!success) {
  return new Response('Too Many Requests', { status: 429 })
}
```

---

## 📚 参考資料

- [Supabase Edge Functions Documentation](https://supabase.com/docs/guides/functions)
- [Supabase CLI Reference](https://supabase.com/docs/reference/cli/introduction)
- [Deno Documentation](https://deno.land/manual)
- [Shopify Admin API](https://shopify.dev/api/admin-rest)

---

## ✅ チェックリスト

デプロイ前の確認:

- [ ] Supabase CLIをインストール
- [ ] Supabaseにログイン
- [ ] プロジェクトにリンク
- [ ] シークレットを設定
- [ ] Edge Functionをデプロイ
- [ ] ローカルでテスト
- [ ] 本番環境でテスト
- [ ] ログを確認
- [ ] Flutterアプリで動作確認

---

## 🎉 完了！

これで、Shopify APIへのアクセスがセキュアになり、CORS問題も解決されました！
