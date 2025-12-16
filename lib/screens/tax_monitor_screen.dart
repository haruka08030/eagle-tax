import 'dart:convert';
import 'package:eagle_tax/models/profile.dart';
import 'package:app_links/app_links.dart';
import 'package:eagle_tax/screens/connect_shopify_screen.dart';
import 'package:eagle_tax/services/tax_analysis_service.dart';
import 'package:eagle_tax/widgets/dashboard_summary_card.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/state_threshold.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';
import '../widgets/state_result_card.dart';

class TaxMonitorScreen extends StatefulWidget {
  const TaxMonitorScreen({super.key});

  @override
  State<TaxMonitorScreen> createState() => _TaxMonitorScreenState();
}

class _TaxMonitorScreenState extends State<TaxMonitorScreen> {
  // Services
  final _supabaseService = SupabaseService();
  final _authService = AuthService();
  final _taxAnalysisService = TaxAnalysisService();

  // State variables
  bool _isLoading = false;
  bool _isInitialising = true;
  String _statusMessage = 'データを読み込んでいます...';
  List<Map<String, dynamic>> _results = [];
  List<StateThreshold> _stateThresholds = [];
  Profile? _profile;
  
  // Date range state
  DateTime _startDate = DateTime(DateTime.now().year - 1, DateTime.now().month, DateTime.now().day);
  DateTime _endDate = DateTime.now();
  final DateFormat _dateFormatter = DateFormat.yMMMd('ja');
  static const _cacheKey = 'state_thresholds_cache';

  // State variables for summary
  int _atRiskCount = 0;
  int _warningCount = 0;
  double _totalAnalyzedSales = 0;

  @override
  void initState() {
    super.initState();
    _initServices();
    _checkDeepLink();
  }

  Future<void> _checkDeepLink() async {
    final appLinks = AppLinks();
    try {
      final uri = await appLinks.getInitialLink();
      if (uri != null) {
        _handleDeepLink(uri);
      }
    } catch (e) {
      debugPrint('Deep link error: $e');
    }
  }

  void _handleDeepLink(Uri uri) {
   final code = uri.queryParameters['code'];
   final shop = uri.queryParameters['shop'];
   if (code != null && shop != null) {
      debugPrint('Shopify callback detected: $uri');
      WidgetsBinding.instance.addPostFrameCallback((_) {
         Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ConnectShopifyScreen(initialQueryParams: uri.queryParameters)),
        ).then((result) {
           if (result == true && mounted) {
             _initServices(); // Refresh profile after successful connection
           }
        });
      });
    }
  }
  
  Future<void> _initServices() async {
    if (!mounted) return;
    setState(() {
      _isInitialising = true;
      _statusMessage = 'ユーザー情報を確認中...';
    });
    try {
      final profileData = await _supabaseService.getProfile();
      
      if (!mounted) return;

      setState(() {
        _profile = profileData;
        _isInitialising = false;
      });

      if (profileData?.isShopifyConnected == true) {
        await _loadStateThresholds();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitialising = false;
          _statusMessage = 'ユーザー情報の取得に失敗しました: $e';
        });
      }
    }
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
            _statusMessage = '期間を選択して診断を開始 (キャッシュ)';
          });
        }
      } catch (e) {
        debugPrint('❌ Error decoding cached thresholds: $e');
      }
    }
  }

  /// Supabaseからデータを取得してCacheを更新する
  Future<void> _fetchAndCacheThresholds({bool isRefresh = false}) async {
    if (isRefresh && mounted) {
      setState(() {
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
        });
      }
    }
  }

  Future<void> _handleSignOut() async {
    try {
      await _authService.signOut();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('サインアウトに失敗しました: ${e.toString()}')),
        );
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
      if (!mounted) return;
      setState(() {
        _startDate = newDateRange.start;
        _endDate = newDateRange.end;
      });
    }
  }

  /// Shopifyから注文データを取得して分析
  Future<void> _fetchAndAnalyze() async {
    if (_profile?.isShopifyConnected != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shopifyが連携されていません。')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Shopifyからデータを取得中...';
      _results = [];
    });

    try {
      debugPrint('📅 集計期間: ${_startDate.toString().split(' ')[0]} ~ ${_endDate.toString().split(' ')[0]}');

      // Use SupabaseService to fetch orders
      final allOrders = await _supabaseService.fetchShopifyOrders(
        startDate: _startDate,
        endDate: _endDate,
        onProgress: (pageCount, totalCount) {
          if (mounted) {
            setState(() {
              _statusMessage = 'Shopifyからデータを取得中... ($totalCount件)';
            });
          }
        },
      );

      debugPrint('✅ 全 ${allOrders.length}件の注文を取得完了');

      if (mounted) {
        setState(() {
          _statusMessage = '${allOrders.length}件の注文データを解析中...';
        });
      }

      // Use TaxAnalysisService for business logic
      final aggregatedData = _taxAnalysisService.aggregateOrders(allOrders, _startDate, _endDate);
      final analysisResult = _taxAnalysisService.createResults(aggregatedData, _startDate, DateTime.now(), _stateThresholds);

      if (mounted) {
        setState(() {
          _results = analysisResult.details;
          _atRiskCount = analysisResult.atRiskCount;
          _warningCount = analysisResult.warningCount;
          _totalAnalyzedSales = analysisResult.totalAnalyzedSales;
          _isLoading = false;
          _statusMessage = '診断完了 (${analysisResult.details.length}州, ${aggregatedData['filteredCount']}件の注文)';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'エラーが発生しました: $e';
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(_profile?.shopifyShopName ?? '🇺🇸 Eagle Tax Monitor'),
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        actions: [
          if (_profile?.isShopifyConnected == true)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _isLoading ? null : () => _fetchAndCacheThresholds(isRefresh: true),
              tooltip: '州のしきい値データを再読み込み',
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleSignOut,
            tooltip: 'サインアウト',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isInitialising) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_profile?.isShopifyConnected != true) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.store_mall_directory, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Shopifyストアと連携してください',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ConnectShopifyScreen()),
                );
                if (result == true && mounted) {
                  _initServices(); // Re-initialize everything
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF95BF47), // Shopify Green
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: const Text('Shopifyと連携する'),
            ),
          ],
        ),
      );
    }
    
    // Main Tax Monitor UI
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 900),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // サマリーカード (結果がある場合のみ表示)
            if (_results.isNotEmpty) ...[
              DashboardSummaryCard(
                atRiskCount: _atRiskCount,
                warningCount: _warningCount,
                totalAnalyzedSales: _totalAnalyzedSales,
              ),
              const SizedBox(height: 16),
            ],

            // コントロールパネル
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
                    if (_statusMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(_statusMessage, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700])),
                      ),
                    ElevatedButton.icon(
                      onPressed: _isLoading || _isInitialising ? null : _fetchAndAnalyze,
                      icon: _isLoading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.search),
                      label: const Text('リスク診断を実行'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // リストタイトル
            if (_results.isNotEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Text('州ごとの詳細レポート', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
              ),

            Expanded(
              child: _stateThresholds.isEmpty
                  ? const Center(child: Text('表示する州データがありません。'))
                  : _results.isEmpty && !_isLoading
                      ? const Center(child: Text('上のボタンを押して診断を開始してください。'))
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
    );
  }
}
