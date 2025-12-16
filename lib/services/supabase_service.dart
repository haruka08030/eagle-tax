import 'package:eagle_tax/models/profile.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/state_threshold.dart';

/// Supabase関連の処理を管理するサービスクラス
/// データベース・Edge Functionsへのアクセスを一元管理
class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  /// ユーザープロファイルを取得
  Future<Profile?> getProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return null;
    }

    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();
      
      return Profile.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      return null;
    }
  }

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

  /// Shopifyから注文データを取得 (Edge Function経由)
  /// ページネーションを自動で処理して全データを取得します
  Future<List<dynamic>> fetchShopifyOrders({
    required DateTime startDate,
    required DateTime endDate,
    Function(int pageCount, int totalCount)? onProgress,
  }) async {
    List<dynamic> allOrders = [];
    String? nextPageUrl;
    int pageCount = 0;

    // Dates for API
    final startIso = startDate.toIso8601String();
    final endIso = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59).toIso8601String();

    do {
      pageCount++;

      final response = await _client.functions.invoke(
        'fetch-shopify-orders',
        body: {
          if (nextPageUrl != null) 'pageUrl': nextPageUrl,
          if (nextPageUrl == null) 'startDate': startIso,
          if (nextPageUrl == null) 'endDate': endIso,
        },
      );

      if (response.status != 200) {
        final errorData = response.data;
        final errorMessage = errorData is Map ? errorData['error'] : 'Unknown function error';
        throw Exception('Edge Function Error: $errorMessage');
      }

      final data = response.data as Map<String, dynamic>;

      if (data['error'] != null) {
        throw Exception('Shopify API Error: ${data['error']}');
      }

      final List<dynamic> orders = data['orders'] as List<dynamic>;
      allOrders.addAll(orders);

      if (onProgress != null) {
        onProgress(pageCount, allOrders.length);
      }

      nextPageUrl = data['nextPageUrl'] as String?;

      if (nextPageUrl != null) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } while (nextPageUrl != null);

    return allOrders;
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
