import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/state_threshold.dart';

/// Supabase関連の処理を管理するサービスクラス
class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  /// 州の基準データを取得
  Future<List<StateThreshold>> fetchStateThresholds() async {
    final response = await _client
        .from('states')
        .select()
        .order('code', ascending: true);

    final List<StateThreshold> thresholds = [];
    
    for (var json in response as List) {
      try {
        final threshold = StateThreshold.fromJson(json);
        thresholds.add(threshold);
      } catch (e) {
        // エラーが発生したレコードはスキップ
        continue;
      }
    }

    return thresholds;
  }
  /// Shopify認証URLを取得
  Future<Map<String, dynamic>> getShopifyAuthUrl(String shopName, String redirectUri) async {
    final response = await _client.functions.invoke(
      'get-shopify-auth-url',
      body: {
        'shopName': shopName,
        'redirectUri': redirectUri,
      },
    );

    if (response.status >= 200 && response.status < 300) {
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      throw Exception('Invalid response format from server');
    } else {
      final errorMsg = response.data is Map 
          ? response.data['error'] ?? 'Server error' 
          : 'Server error: ${response.status}';
      throw Exception(errorMsg);
    }
  }

  /// Shopify認証コールバック処理（トークン交換）
  Future<void> exchangeShopifyAuthCode(Map<String, String> queryParams) async {
    final response = await _client.functions.invoke(
      'shopify-auth-callback',
      body: queryParams,
    );

    if (response.status < 200 || response.status >= 300) {
      final errorMsg = response.data is Map ? response.data['error'] ?? 'Unknown error' : 'Unknown error';
      throw Exception('Shopify連携に失敗しました: $errorMsg');
    }
  }
}
