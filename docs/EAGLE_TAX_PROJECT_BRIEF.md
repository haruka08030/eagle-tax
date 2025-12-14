# Eagle Tax (US Sales Tax Monitor) - Project Brief

## 1. プロジェクト概要
日本のShopifyマーチャント（越境ECセラー）向けの「米国売上税（Sales Tax）監視SaaS」。
Shopifyの注文データを取得し、州ごとの「Economic Nexus（経済的ネクサス）」基準を超過していないかを自動判定し、納税義務が発生しそうな州を警告する。

## 2. 技術スタック
* **Frontend:** Flutter (Web build)
* **Backend / DB:** Supabase (PostgreSQL)
* **Data Source:** Shopify Admin API (REST)
* **Language:** Dart

## 3. 現在のステータス (Current Status)
* **Supabase:**
    * `states` テーブル作成済み。全50州+DCの最新（2025年基準）ルール格納済み。
* **Shopify:**
    * 開発ストア (`eagle-tax-dev`) 開設済み。
    * Custom Appにて `read_orders`, `read_all_orders` 権限のAccess Token取得済み。
    * テストデータ（NY州 $600k, AK州 $600k）作成済み。
* **Flutter App:**
    * `lib/main.dart` にてプロトタイプ実装済み。
    * Shopify APIからJSONを取得し、ハードコーディングされた簡易基準と比較してリスト表示する機能まで完成。

## 4. データベース設計 (Supabase)
**Table: `public.states`**

| Column | Type | Description |
| :--- | :--- | :--- |
| `code` | `char(2)` | PK. 州コード (例: 'CA', 'NY') |
| `name` | `text` | 州名 |
| `sales_threshold` | `int8` | 売上金額基準 (USD) |
| `txn_threshold` | `int4` | 取引回数基準 (回) / NULL許容 |
| `logic_type` | `text` | 判定ロジック ('SALES_ONLY', 'OR', 'AND') |

* **Logic Types:**
    * `SALES_ONLY`: 売上金額 >= 基準値 でアウト。
    * `OR`: (売上 >= 基準値) **または** (取引数 >= 基準値) でアウト。
    * `AND`: (売上 >= 基準値) **かつ** (取引数 >= 基準値) でアウト。(例: NY, CT)

## 5. 実装すべきロジック (Business Logic)
アプリケーションは以下の手順で処理を行う必要がある。

1.  **データ取得:**
    * Supabaseから `states` テーブル全件を取得（マスターデータ）。
    * Shopify APIから `orders` を取得（ページネーション対応が必要だが、MVPでは直近250件でOK）。
2.  **データ整形 (Aggregation):**
    * 注文データから `shipping_address.province_code` (州コード) を抽出。
    * 州ごとに以下の2つを集計する。
        * `total_sales`: `total_price` の合計値。
        * `transaction_count`: 注文回数の合計値。
    * *除外条件:* `shipping_address` がNULL、または `country_code` が 'US' 以外は無視。
3.  **判定 (Evaluation):**
    * 集計した各州のデータと、Supabaseの基準値を比較する。
    * `states.logic_type` に応じて判定式を切り替える。
        * 例: NY州 (`AND`) は、売上$500k超 **かつ** 100件超 の場合のみ `isDanger = true`。
4.  **表示 (UI):**
    * 危険な州（Nexus Reached）をリストの上位に表示し、赤色で警告。
    * 安全な州は下位に表示。

## 6. 次の実装タスク (Next Tasks for AI)
以下の順でコードを修正・拡張すること。

1.  **Supabase連携:**
    * `supabase_flutter` パッケージを導入。
    * `main.dart` 内のハードコーディングされた `_thresholds` マップを廃止し、Supabaseから動的に `states` リストを取得する処理に書き換える。
2.  **ロジック強化:**
    * 現在は「金額」しか見ていない。`transaction_count` (取引数) もカウントするように集計ロジックを修正する。
    * `logic_type` ('AND', 'OR') を考慮した判定関数 (`bool checkNexus(...)`) を実装する。
3.  **UI改善:**
    * 各カードに「売上額」だけでなく「取引回数」も表示する。
    * Supabaseの `anon_key` と `url` を設定するための定数エリアを用意する。

## 7. 環境変数・シークレット (Secrets)
* **Shopify Access Token:** `shpat_xxxxxxxx...` (ユーザーが保持)
* **Supabase URL/Key:** (ユーザーが保持)

---
End of Brief