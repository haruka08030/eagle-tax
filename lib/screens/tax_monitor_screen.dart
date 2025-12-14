import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/state_threshold.dart';
import '../services/supabase_service.dart';
import '../services/shopify_service.dart';
import '../widgets/state_result_card.dart';

class TaxMonitorScreen extends StatefulWidget {
  const TaxMonitorScreen({super.key});

  @override
  State<TaxMonitorScreen> createState() => _TaxMonitorScreenState();
}

class _TaxMonitorScreenState extends State<TaxMonitorScreen> {
  late String _shopName;
  late String _accessToken;
  
  bool _isLoading = false;
  String _statusMessage = 'ボタンを押して診断を開始してください';
  List<Map<String, dynamic>> _results = [];
  List<StateThreshold> _stateThresholds = [];

  final _supabaseService = SupabaseService();
  late ShopifyService _shopifyService;

  @override
  void initState() {
    super.initState();
    _shopName = dotenv.env['SHOPIFY_SHOP_NAME']!;
    _accessToken = dotenv.env['SHOPIFY_ACCESS_TOKEN']!;
    _shopifyService = ShopifyService(
      shopName: _shopName,
      accessToken: _accessToken,
    );
    _loadStateThresholds();
  }

  /// Supabaseから州の基準データを取得
  Future<void> _loadStateThresholds() async {
    try {
      final thresholds = await _supabaseService.fetchStateThresholds();
      setState(() {
        _stateThresholds = thresholds;
      });
      debugPrint('✅ Loaded ${_stateThresholds.length} state thresholds from Supabase');
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading state thresholds: $e');
      debugPrint('Stack trace: $stackTrace');
      setState(() {
        _statusMessage = 'Supabaseからのデータ取得に失敗しました: $e';
      });
    }
  }

  /// Shopifyから注文データを取得して分析
  Future<void> _fetchAndAnalyze() async {
    if (_stateThresholds.isEmpty) {
      setState(() {
        _statusMessage = 'まず州の基準データを読み込んでください';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Shopifyからデータを取得中...';
      _results = [];
    });

    try {
      // 直近12ヶ月の期間を計算
      final now = DateTime.now();
      final twelveMonthsAgo = DateTime(now.year - 1, now.month, now.day);
      
      debugPrint('📅 集計期間: ${twelveMonthsAgo.toString().split(' ')[0]} ~ ${now.toString().split(' ')[0]}');

      // すべての注文を取得
      final allOrders = await _shopifyService.fetchAllOrders(
        onProgress: (pageCount, totalCount) {
          setState(() {
            _statusMessage = 'Shopifyからデータを取得中... (ページ $pageCount)';
          });
          debugPrint('📦 ページ $pageCount: 累計 $totalCount件');
        },
      );

      debugPrint('✅ 全 ${allOrders.length}件の注文を取得完了');

      setState(() {
        _statusMessage = '${allOrders.length}件の注文データを解析中...';
      });

      // 集計処理
      final aggregatedData = _aggregateOrders(allOrders, twelveMonthsAgo);
      
      // 結果リストを作成
      final tempResults = _createResults(aggregatedData);

      setState(() {
        _results = tempResults;
        _isLoading = false;
        _statusMessage = '診断完了 (${tempResults.length}州, 直近12ヶ月: ${aggregatedData['filteredCount']}件の注文)';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'エラーが発生しました: $e';
      });
    }
  }

  /// 注文データを集計
  Map<String, dynamic> _aggregateOrders(List<dynamic> orders, DateTime cutoffDate) {
    Map<String, double> stateSales = {};
    Map<String, int> stateTransactions = {};
    int filteredCount = 0;
    int outOfRangeCount = 0;

    for (var order in orders) {
      var shipping = order['shipping_address'];
      if (shipping == null) continue;
      if (shipping['country_code'] != 'US') continue;

      // 期間フィルタリング
      String? createdAt = order['created_at'];
      if (createdAt != null) {
        DateTime orderDate = DateTime.parse(createdAt);
        if (orderDate.isBefore(cutoffDate)) {
          outOfRangeCount++;
          continue;
        }
      }

      String state = shipping['province_code'];
      double amount = double.parse(order['total_price']);

      stateSales[state] = (stateSales[state] ?? 0.0) + amount;
      stateTransactions[state] = (stateTransactions[state] ?? 0) + 1;
      filteredCount++;
    }

    debugPrint('📊 集計結果: $filteredCount件を集計 ($outOfRangeCount件は期間外のため除外)');

    return {
      'stateSales': stateSales,
      'stateTransactions': stateTransactions,
      'filteredCount': filteredCount,
    };
  }

  /// 集計データから結果リストを作成
  List<Map<String, dynamic>> _createResults(Map<String, dynamic> aggregatedData) {
    final stateSales = aggregatedData['stateSales'] as Map<String, double>;
    final stateTransactions = aggregatedData['stateTransactions'] as Map<String, int>;
    List<Map<String, dynamic>> tempResults = [];

    for (var entry in stateSales.entries) {
      String stateCode = entry.key;
      double totalSales = entry.value;
      int txnCount = stateTransactions[stateCode] ?? 0;

      StateThreshold? threshold = _stateThresholds
          .where((st) => st.code == stateCode)
          .firstOrNull;

      if (threshold == null) {
        debugPrint('⚠️ No threshold found for state: $stateCode');
        continue;
      }

      bool isDanger = threshold.checkNexus(
        totalSales: totalSales,
        transactionCount: txnCount,
      );

      tempResults.add({
        'state': stateCode,
        'stateName': threshold.name,
        'total': totalSales,
        'txnCount': txnCount,
        'salesLimit': threshold.salesThreshold,
        'txnLimit': threshold.txnThreshold,
        'logicType': threshold.logicType,
        'isDanger': isDanger,
      });
    }

    // 危険な順に並び替え
    tempResults.sort((a, b) {
      if (a['isDanger'] != b['isDanger']) {
        return a['isDanger'] ? -1 : 1;
      }
      return b['total'].compareTo(a['total']);
    });

    return tempResults;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🇺🇸 Eagle Tax Monitor'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // コントロールパネル
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        _statusMessage,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _fetchAndAnalyze,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.search),
                        label: const Text('リスク診断を実行'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 30,
                            vertical: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 結果リスト
              Expanded(
                child: _results.isEmpty
                    ? const Center(child: Text('データがありません'))
                    : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          return StateResultCard(result: _results[index]);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
