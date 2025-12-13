# 期間フィルタリングとページネーション実装ガイド

## 📅 期間フィルタリング (Date Logic)

### 実装内容

直近12ヶ月の注文のみを集計するように修正しました。

```dart
// 直近12ヶ月の期間を計算
final now = DateTime.now();
final twelveMonthsAgo = DateTime(now.year - 1, now.month, now.day);

// 注文日時をチェック
String? createdAt = order['created_at'];
if (createdAt != null) {
  DateTime orderDate = DateTime.parse(createdAt);
  if (orderDate.isBefore(twelveMonthsAgo)) {
    outOfRangeCount++;
    continue; // 12ヶ月より古い注文はスキップ
  }
}
```

### なぜ重要か

多くの州のEconomic Nexusルールは「直近の1年間（Current or Previous Calendar Year）」を基準としています。

**修正前の問題:**
- 3年前の注文も含めて集計
- 実際には基準を下回っているのに「危険」と誤判定
- 不要な納税義務の警告

**修正後:**
- 直近12ヶ月のみを集計
- 正確な判定が可能
- 期間外の注文数もログに表示

### ログ出力例

```
📅 集計期間: 2024-12-13 ~ 2025-12-13
📊 集計結果: 450件を集計 (150件は期間外のため除外)
診断完了 (15州, 直近12ヶ月: 450件の注文)
```

---

## 📦 完全なページネーション (Pagination)

### 実装内容

Shopify APIのすべてのページを取得するように修正しました。

```dart
List<dynamic> allOrders = [];
String? nextPageUrl;
int pageCount = 0;

var url = Uri.parse(
    'https://$shopName.myshopify.com/admin/api/2024-01/orders.json?status=any&limit=250');

do {
  pageCount++;
  
  final response = await http.get(
    url,
    headers: {'X-Shopify-Access-Token': accessToken},
  );
  
  final data = json.decode(response.body);
  final List<dynamic> orders = data['orders'];
  allOrders.addAll(orders);
  
  // 次のページのURLを取得
  nextPageUrl = _getNextPageUrl(response.headers['link']);
  
  if (nextPageUrl != null) {
    url = Uri.parse(nextPageUrl);
    // API Rate Limitを考慮して待機
    await Future.delayed(const Duration(milliseconds: 500));
  }
} while (nextPageUrl != null);
```

### Linkヘッダーの解析

Shopify APIは次のページのURLを `Link` ヘッダーで返します:

```
Link: <https://shop.myshopify.com/admin/api/2024-01/orders.json?page_info=xxx>; rel="next"
```

このURLを正規表現で抽出:

```dart
String? _getNextPageUrl(String? linkHeader) {
  if (linkHeader == null) return null;
  
  final links = linkHeader.split(',');
  for (var link in links) {
    if (link.contains('rel="next"')) {
      final match = RegExp(r'<(.+?)>').firstMatch(link);
      return match?.group(1);
    }
  }
  return null;
}
```

### なぜ重要か

**修正前の問題:**
- 最初の250件のみ取得
- 1,000件の注文がある場合、750件が無視される
- 正確な税金判定が不可能

**修正後:**
- すべての注文を取得
- 正確な売上額と取引回数を集計
- 信頼できる判定結果

### API Rate Limit対策

Shopify APIには以下のRate Limitがあります:
- REST Admin API: 2リクエスト/秒

対策として、各ページ取得後に500ms待機:

```dart
await Future.delayed(const Duration(milliseconds: 500));
```

### ログ出力例

```
📦 ページ 1: 250件取得 (累計: 250件)
📦 ページ 2: 250件取得 (累計: 500件)
📦 ページ 3: 250件取得 (累計: 750件)
📦 ページ 4: 150件取得 (累計: 900件)
✅ 全 900件の注文を取得完了
```

---

## 🔍 動作確認

### 1. Chrome DevToolsでログを確認

アプリ実行中にChrome DevToolsのコンソールを開き、以下を確認:

```
📅 集計期間: 2024-12-13 ~ 2025-12-13
📦 ページ 1: 250件取得 (累計: 250件)
📦 ページ 2: 250件取得 (累計: 500件)
✅ 全 500件の注文を取得完了
500件の注文データを解析中...
📊 集計結果: 450件を集計 (50件は期間外のため除外)
診断完了 (15州, 直近12ヶ月: 450件の注文)
```

### 2. UIで結果を確認

ステータスメッセージに以下が表示されます:

```
診断完了 (15州, 直近12ヶ月: 450件の注文)
```

これにより:
- 集計対象の州数
- 集計期間（直近12ヶ月）
- 実際に集計した注文数

が一目でわかります。

---

## 📊 パフォーマンス

### 処理時間の目安

| 注文数 | ページ数 | 取得時間 | 集計時間 | 合計 |
|--------|----------|----------|----------|------|
| 250件 | 1ページ | ~1秒 | ~0.1秒 | ~1.1秒 |
| 500件 | 2ページ | ~2秒 | ~0.2秒 | ~2.2秒 |
| 1,000件 | 4ページ | ~4秒 | ~0.4秒 | ~4.4秒 |
| 5,000件 | 20ページ | ~20秒 | ~2秒 | ~22秒 |

※ネットワーク速度やAPIレスポンス時間により変動

### 最適化のポイント

1. **Rate Limit対策**: 500ms待機でAPI制限を回避
2. **並列処理なし**: 順次取得でエラーを防止
3. **メモリ効率**: すべての注文をメモリに保持（将来的にはストリーム処理も検討）

---

## 🚀 今後の改善案

### 1. 期間選択機能
ユーザーが集計期間を選択できるようにする:
- 直近12ヶ月（デフォルト）
- 今年（Calendar Year）
- 前年（Previous Calendar Year）
- カスタム期間

### 2. バックグラウンド処理
大量の注文がある場合、バックグラウンドで処理:
- Isolateを使用した並列処理
- プログレスバーの表示
- キャンセル機能

### 3. キャッシング
取得した注文データをローカルにキャッシュ:
- IndexedDB（Web）
- SharedPreferences（モバイル）
- 差分更新のみ実行

### 4. エクスポート機能
診断結果をエクスポート:
- CSV形式
- PDF形式
- 集計期間と取得件数を含める

---

## 📝 まとめ

この実装により、以下の重要な問題が解決されました:

✅ **正確な期間集計**: 直近12ヶ月のみを対象  
✅ **完全なデータ取得**: すべての注文を取得  
✅ **信頼できる判定**: 正確な売上額と取引回数  
✅ **透明性**: 詳細なログで処理内容を確認可能  

これにより、ユーザーは信頼できる税金判定結果を得ることができます。
