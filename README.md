# Eagle Tax - US Sales Tax Monitor

日本のShopifyマーチャント向けの「米国売上税（Sales Tax）監視SaaS」。
Shopifyの注文データを取得し、州ごとの「Economic Nexus（経済的ネクサス）」基準を超過していないかを自動判定します。

## 🎯 主な機能

- ✅ **Supabase統合**: 州ごとの最新基準値をデータベースから動的に取得
- ✅ **Edge Functions**: Shopify APIをサーバーサイドで呼び出し、セキュリティとCORSの問題を解決
- ✅ **期間フィルタリング**: 直近12ヶ月の注文のみを集計（正確な判定）
- ✅ **完全なページネーション**: Shopify APIからすべての注文を取得
- ✅ **複数の判定ロジック**: SALES_ONLY、OR、AND、NONEの4つのロジックに対応
- ✅ **リアルタイム診断**: 売上額と取引回数の両方を考慮した判定
- ✅ **セキュア**: アクセストークンをクライアント側に露出しない


## 🗄️ データベース構造

### `states` テーブル

| カラム名 | 型 | 説明 |
|---------|-----|------|
| `code` | `char(2)` | 州コード (PK) 例: 'NY', 'CA' |
| `name` | `text` | 州名 例: 'New York' |
| `sales_threshold` | `int8` | 売上金額基準 (USD) |
| `txn_threshold` | `int4` | 取引回数基準 (NULL許容) |
| `logic_type` | `text` | 判定ロジック ('SALES_ONLY', 'OR', 'AND', 'NONE') |

## 📁 ファイル構成

```
lib/
├── main.dart                       # アプリのエントリーポイント
├── models/
│   └── state_threshold.dart        # 州基準データのモデル
├── services/
│   ├── supabase_service.dart       # Supabase関連のロジック
│   └── shopify_service.dart        # Shopify API呼び出し（Edge Function経由）
├── screens/
│   └── tax_monitor_screen.dart     # メイン画面
└── widgets/
    └── state_result_card.dart      # 州の結果表示カード

supabase/
├── functions/
│   └── fetch-shopify-orders/       # Edge Function
└── SECRETS_SETUP.md                # シークレット設定ガイド

docs/
├── ARCHITECTURE.md                 # システムアーキテクチャ
├── EDGE_FUNCTION_SETUP.md          # Edge Functionデプロイガイド
├── DATE_AND_PAGINATION.md          # 実装詳細
└── IMPROVEMENTS.md                 # 改善履歴
```

## 📝 使用方法

1. アプリを起動すると、自動的にSupabaseから州の基準データを読み込みます
2. 「リスク診断を実行」ボタンをクリック
3. Shopifyから注文データを取得し、州ごとに集計
4. 各州のNexus状態を判定して表示
   - 🔴 **NEXUS REACHED**: 納税義務が発生する可能性あり
   - 🟢 **Safe**: まだ基準に達していない

- 本アプリは情報提供のみを目的としており、法的アドバイスではありません