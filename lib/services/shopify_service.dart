import 'package:supabase_flutter/supabase_flutter.dart';

/// Shopify注文データを取得するサービスクラス
class ShopifyService {
  final SupabaseClient _client = Supabase.instance.client;
  final String shopName;
  final String accessToken;

  ShopifyService({
    required this.shopName,
    required this.accessToken,
  });

  /// すべての注文を取得（ページネーション対応）
  Future<List<dynamic>> fetchAllOrders({
    required Function(int pageCount, int totalCount) onProgress,
  }) async {
    List<dynamic> allOrders = [];
    String? nextPageUrl;
    int pageCount = 0;

    do {
      pageCount++;
      
      // Supabase Edge Functionを呼び出し
      final response = await _client.functions.invoke(
        'fetch-shopify-orders',
        body: {
          'shopName': shopName,
          'accessToken': accessToken,
          if (nextPageUrl != null) 'pageUrl': nextPageUrl,
        },
      );

      if (response.status != 200) {
        throw Exception('Edge Function Error: ${response.status}');
      }

      final data = response.data as Map<String, dynamic>;
      
      if (data['error'] != null) {
        throw Exception('Shopify API Error: ${data['error']}');
      }

      final List<dynamic> orders = data['orders'] as List<dynamic>;
      allOrders.addAll(orders);

      // 進捗を通知
      onProgress(pageCount, allOrders.length);

      // 次のページのURLを取得
      nextPageUrl = data['nextPageUrl'] as String?;
      
      if (nextPageUrl != null) {
        // API Rate Limitを考慮して待機
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } while (nextPageUrl != null);

    return allOrders;
  }
}
