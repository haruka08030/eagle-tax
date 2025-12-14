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
}
