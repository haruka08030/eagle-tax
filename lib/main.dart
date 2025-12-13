import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/state_threshold.dart';
import 'dart:convert';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  final String supabaseUrl = dotenv.env['SUPABASE_URL']!;
  final String supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY']!;

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
  
  runApp(const EagleTaxApp());
}

class EagleTaxApp extends StatelessWidget {
  const EagleTaxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eagle Tax MVP',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      home: const TaxMonitorScreen(),
    );
  }
}

class TaxMonitorScreen extends StatefulWidget {
  const TaxMonitorScreen({super.key});

  @override
  State<TaxMonitorScreen> createState() => _TaxMonitorScreenState();
}

class _TaxMonitorScreenState extends State<TaxMonitorScreen> {
  late String shopName;
  late String accessToken;


  bool _isLoading = false;
  String _statusMessage = 'ボタンを押して診断を開始してください';
  List<Map<String, dynamic>> _results = [];
  List<StateThreshold> _stateThresholds = [];

  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    shopName = dotenv.env['SHOPIFY_SHOP_NAME']!;
    accessToken = dotenv.env['SHOPIFY_ACCESS_TOKEN']!;
    _loadStateThresholds();
  }

  /// Supabaseから州の基準データを取得
  Future<void> _loadStateThresholds() async {
    try {
      final response = await supabase
          .from('states')
          .select()
          .order('code', ascending: true);

      debugPrint('📥 Received ${(response as List).length} records from Supabase');

      List<StateThreshold> thresholds = [];
      for (var json in response) {
        try {
          final threshold = StateThreshold.fromJson(json);
          thresholds.add(threshold);
        } catch (e) {
          debugPrint('⚠️ Error parsing state record: $json');
          debugPrint('⚠️ Parse error: $e');
          // Continue processing other records
        }
      }

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

      // すべての注文を取得（ページネーション対応）
      List<dynamic> allOrders = [];
      String? nextPageUrl;
      int pageCount = 0;
      
      // 初回リクエスト
      var url = Uri.parse(
          'https://$shopName.myshopify.com/admin/api/2024-01/orders.json?status=any&limit=250');

      do {
        pageCount++;
        setState(() {
          _statusMessage = 'Shopifyからデータを取得中... (ページ $pageCount)';
        });

        final response = await http.get(
          url,
          headers: {'X-Shopify-Access-Token': accessToken},
        );

        if (response.statusCode != 200) {
          throw Exception('API Error: ${response.statusCode}');
        }

        final data = json.decode(response.body);
        final List<dynamic> orders = data['orders'];
        allOrders.addAll(orders);

        debugPrint('📦 ページ $pageCount: ${orders.length}件取得 (累計: ${allOrders.length}件)');

        // 次のページのURLを取得（Linkヘッダーから）
        nextPageUrl = _getNextPageUrl(response.headers['link']);
        
        if (nextPageUrl != null) {
          url = Uri.parse(nextPageUrl);
          // API Rate Limitを考慮して少し待機
          await Future.delayed(const Duration(milliseconds: 500));
        }
      } while (nextPageUrl != null);

      debugPrint('✅ 全 ${allOrders.length}件の注文を取得完了');

      setState(() {
        _statusMessage = '${allOrders.length}件の注文データを解析中...';
      });

      // 集計ロジック: 売上額と取引回数の両方をカウント（期間フィルタリング付き）
      Map<String, double> stateSales = {};
      Map<String, int> stateTransactions = {};
      int filteredCount = 0;
      int outOfRangeCount = 0;

      for (var order in allOrders) {
        // 配送先住所がない、または米国以外はスキップ
        var shipping = order['shipping_address'];
        if (shipping == null) continue;
        if (shipping['country_code'] != 'US') continue;

        // 注文日時をチェック（直近12ヶ月のみ）
        String? createdAt = order['created_at'];
        if (createdAt != null) {
          DateTime orderDate = DateTime.parse(createdAt);
          if (orderDate.isBefore(twelveMonthsAgo)) {
            outOfRangeCount++;
            continue; // 12ヶ月より古い注文はスキップ
          }
        }

        String state = shipping['province_code'];
        double amount = double.parse(order['total_price']);

        stateSales[state] = (stateSales[state] ?? 0.0) + amount;
        stateTransactions[state] = (stateTransactions[state] ?? 0) + 1;
        filteredCount++;
      }

      debugPrint('📊 集計結果: $filteredCount件を集計 ($outOfRangeCount件は期間外のため除外)');

      // 結果リストを作成
      List<Map<String, dynamic>> tempResults = [];
      
      for (var entry in stateSales.entries) {
        String stateCode = entry.key;
        double totalSales = entry.value;
        int txnCount = stateTransactions[stateCode] ?? 0;

        // Supabaseから該当する州の基準を取得
        StateThreshold? threshold = _stateThresholds
            .where((st) => st.code == stateCode)
            .firstOrNull;

        if (threshold == null) {
          debugPrint('⚠️ No threshold found for state: $stateCode');
          continue;
        }

        // logic_typeに応じた判定
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

      // 危険な順に並び替え (危険 → 売上額の大きい順)
      tempResults.sort((a, b) {
        if (a['isDanger'] != b['isDanger']) {
          return a['isDanger'] ? -1 : 1;
        }
        return b['total'].compareTo(a['total']);
      });

      setState(() {
        _results = tempResults;
        _isLoading = false;
        _statusMessage = '診断完了 (${tempResults.length}州, 直近12ヶ月: $filteredCount件の注文)';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'エラーが発生しました: $e';
      });
    }
  }

  /// Linkヘッダーから次のページのURLを抽出
  String? _getNextPageUrl(String? linkHeader) {
    if (linkHeader == null) return null;

    // Linkヘッダーの形式: <url>; rel="next", <url>; rel="previous"
    final links = linkHeader.split(',');
    for (var link in links) {
      if (link.contains('rel="next"')) {
        final match = RegExp(r'<(.+?)>').firstMatch(link);
        return match?.group(1);
      }
    }
    return null;
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
          constraints: const BoxConstraints(maxWidth: 800), // PCで見やすく
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // コントロールパネル
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(_statusMessage,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _fetchAndAnalyze,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.search),
                        label: const Text('リスク診断を実行'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 30, vertical: 15),
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
                          final item = _results[index];
                          final isDanger = item['isDanger'] as bool;
                          final logicType = item['logicType'] as String;
                          final txnLimit = item['txnLimit'] as int?;

                          return Card(
                            elevation: isDanger ? 4 : 1,
                            color: isDanger ? Colors.red[50] : Colors.white,
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    isDanger ? Colors.red : Colors.green,
                                child: Icon(
                                  isDanger ? Icons.warning : Icons.check,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(
                                '${item['state']} - ${item['stateName']}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    '💰 売上: \$${item['total'].toStringAsFixed(0)} / \$${item['salesLimit']}',
                                    style: TextStyle(
                                      fontWeight: item['total'] >= item['salesLimit']
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  if (txnLimit != null)
                                    Text(
                                      '📦 取引数: ${item['txnCount']} / $txnLimit',
                                      style: TextStyle(
                                        fontWeight: item['txnCount'] >= txnLimit
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '判定ロジック: $logicType',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              trailing: isDanger
                                  ? const Chip(
                                      label: Text('NEXUS REACHED'),
                                      backgroundColor: Colors.red,
                                      labelStyle: TextStyle(color: Colors.white),
                                    )
                                  : const Chip(
                                      label: Text('Safe'),
                                      backgroundColor: Colors.green,
                                      labelStyle: TextStyle(color: Colors.white),
                                    ),
                            ),
                          );
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