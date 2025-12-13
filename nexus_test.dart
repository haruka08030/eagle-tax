void main() {
  // 1. あなたが取得したShopifyの生データ (簡易版)
  // ※本来はAPIから取ってきますが、まずは固定データでテストします
  final orders = [
    {
      "id": 1001,
      "total_price": "600000.00",
      "shipping_address": {"province_code": "AK"} // アラスカ
    },
    {
      "id": 1002,
      "total_price": "600000.00",
      "shipping_address": {"province_code": "AK"} // アラスカ
    },
    {
      "id": 1003,
      "total_price": "50.00",
      "shipping_address": {"province_code": "NY"} // ニューヨーク
    }
  ];

  // 2. Supabaseに入っている基準データ (簡易版)
  final thresholds = {
    "AK": 100000, // アラスカ: 10万ドルでアウト
    "NY": 500000, // ニューヨーク: 50万ドルでアウト
    "CA": 500000, // カリフォルニア
  };

  print("🚀 判定を開始します...\n");

  // 3. 集計ロジック: 州ごとの売上合計を計算する
  Map<String, double> stateSales = {};

  for (var order in orders) {
    // 住所がないデータはスキップ
    if (order['shipping_address'] == null) continue;
    
    // データ型を変換 (String -> double)
    String state = (order['shipping_address'] as Map)['province_code'];
    double amount = double.parse(order['total_price'] as String);

    // 加算する
    if (!stateSales.containsKey(state)) {
      stateSales[state] = 0.0;
    }
    stateSales[state] = stateSales[state]! + amount;
  }

  // 4. 判定ロジック: 基準を超えているかチェック
  stateSales.forEach((state, total) {
    double limit = (thresholds[state] ?? 999999999).toDouble(); // 基準がない州は無視
    bool isDanger = total >= limit;

    print("State: $state");
    print("  - Total Sales: \$${total.toStringAsFixed(2)}");
    print("  - Threshold:   \$${limit.toStringAsFixed(2)}");
    
    if (isDanger) {
      print("  => 🚨 DANGER! (基準超過)");
    } else {
      print("  => ✅ Safe");
    }
    print("-------------------------");
  });
}