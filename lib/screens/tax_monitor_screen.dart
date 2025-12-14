import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  // Services and config
  late String _shopName;
  late String _accessToken;
  final _supabaseService = SupabaseService();
  late ShopifyService _shopifyService;

  // State variables
  bool _isLoading = false;
  bool _isThresholdsLoading = true;
  String _statusMessage = 'データを読み込んでいます...';
  List<Map<String, dynamic>> _results = [];
  List<StateThreshold> _stateThresholds = [];
  
  // Date range state
  DateTime _startDate = DateTime(DateTime.now().year - 1, DateTime.now().month, DateTime.now().day);
  DateTime _endDate = DateTime.now();
  final DateFormat _dateFormatter = DateFormat.yMMMd('ja');
  static const _cacheKey = 'state_thresholds_cache';

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

  /// 1. Cache -> 2. Network の順でデータを読み込む
  Future<void> _loadStateThresholds() async {
    await _loadThresholdsFromCache();
    await _fetchAndCacheThresholds(isRefresh: _stateThresholds.isEmpty);
  }
  
  /// Cacheからデータを読み込む
  Future<void> _loadThresholdsFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getString(_cacheKey);

    if (cachedData != null) {
      try {
        final List<dynamic> decodedData = jsonDecode(cachedData);
        final thresholds = decodedData
            .map((item) => StateThreshold.fromJson(item as Map<String, dynamic>))
            .toList();
        
        if (thresholds.isNotEmpty && mounted) {
          setState(() {
            _stateThresholds = thresholds;
            _isThresholdsLoading = false; // Show cached data immediately
            _statusMessage = '期間を選択して診断を開始 (キャッシュ)';
          });
          debugPrint('✅ Loaded ${thresholds.length} state thresholds from CACHE');
        }
      } catch (e) {
        debugPrint('❌ Error decoding cached thresholds: $e');
      }
    }
  }

  /// Supabaseからデータを取得してCacheを更新する
  Future<void> _fetchAndCacheThresholds({bool isRefresh = false}) async {
    // Show loading indicator only on forced refresh or if cache was empty
    if (isRefresh && mounted) {
      setState(() {
        _isThresholdsLoading = true;
        _statusMessage = '州のしきい値データを更新中...';
      });
    }

    try {
      final thresholds = await _supabaseService.fetchStateThresholds();
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> jsonData = thresholds.map((t) => t.toJson()).toList();
      await prefs.setString(_cacheKey, jsonEncode(jsonData));
      
      if (mounted) {
        setState(() {
          _stateThresholds = thresholds;
          _isThresholdsLoading = false;
          _statusMessage = _stateThresholds.isEmpty
              ? '州データが見つかりません。'
              : '期間を選択して診断を開始';
        });
      }
      debugPrint('✅ Loaded and cached ${thresholds.length} thresholds from Supabase');
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading thresholds from Supabase: $e');
      debugPrint('Stack trace: $stackTrace');
      
      if (_stateThresholds.isEmpty && mounted) {
        setState(() {
          _statusMessage = 'データ取得に失敗しました: $e';
          _isThresholdsLoading = false;
        });
      }
    }
  }


  /// 期間選択ダイアログを表示
  Future<void> _selectDateRange() async {
    final newDateRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );

    if (newDateRange != null) {
      setState(() {
        _startDate = newDateRange.start;
        _endDate = newDateRange.end;
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
      debugPrint('📅 集計期間: ${_startDate.toString().split(' ')[0]} ~ ${_endDate.toString().split(' ')[0]}');

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

      final aggregatedData = _aggregateOrders(allOrders, _startDate, _endDate);
      final tempResults = _createResults(aggregatedData, _startDate, DateTime.now());

      setState(() {
        _results = tempResults;
        _isLoading = false;
        _statusMessage = '診断完了 (${tempResults.length}州, ${aggregatedData['filteredCount']}件の注文)';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'エラーが発生しました: $e';
      });
    }
  }

  /// 注文データを集計
  Map<String, dynamic> _aggregateOrders(List<dynamic> orders, DateTime startDate, DateTime endDate) {
    Map<String, double> stateSales = {};
    Map<String, int> stateTransactions = {};
    int filteredCount = 0;
    int outOfRangeCount = 0;

    // endDateの時刻を23:59:59に設定して、その日全体が含まれるようにする
    final inclusiveEndDate = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

    for (var order in orders) {
      var shipping = order['shipping_address'];
      if (shipping == null) continue;
      if (shipping['country_code'] != 'US') continue;

      String? createdAt = order['created_at'];
      if (createdAt != null) {
        DateTime orderDate = DateTime.parse(createdAt);
        if (orderDate.isBefore(startDate) || orderDate.isAfter(inclusiveEndDate)) {
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
  List<Map<String, dynamic>> _createResults(Map<String, dynamic> aggregatedData, DateTime startDate, DateTime updateTime) {
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
        'periodStartDate': startDate,
        'lastUpdated': updateTime,
      });
    }

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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('🇺🇸 Eagle Tax Monitor'),
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : () => _fetchAndCacheThresholds(isRefresh: true),
            tooltip: '州のしきい値データを再読み込み',
          ),
        ],
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                       Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.calendar_today, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            '集計期間: ${_dateFormatter.format(_startDate)} - ${_dateFormatter.format(_endDate)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                           IconButton(
                            icon: const Icon(Icons.edit, size: 16),
                            onPressed: _selectDateRange,
                            tooltip: '集計期間を変更',
                          )
                        ],
                      ),
                      const Divider(height: 20),
                      Text(
                        _statusMessage,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: _isLoading || _isThresholdsLoading ? null : _fetchAndAnalyze,
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

              Expanded(
                child: _isThresholdsLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _results.isEmpty && !_isLoading
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
