import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// 州の診断結果を表示するカードウィジェット
class StateResultCard extends StatelessWidget {
  final Map<String, dynamic> result;

  const StateResultCard({
    super.key,
    required this.result,
  });

  /// しきい値に対する進捗を表示するウィジェットを構築
  Widget _buildProgressInfo(
      BuildContext context, double currentValue, int? limitValue, String label) {
    if (limitValue == null || limitValue == 0) {
      return const SizedBox.shrink();
    }

    final double progress = currentValue / limitValue;
    final double displayProgress = progress.clamp(0.0, 1.0);
    final currencyFormatter = NumberFormat.currency(locale: 'en_US', symbol: '\$');
    final String progressText = label == '売上'
        ? '${currencyFormatter.format(currentValue)} / ${currencyFormatter.format(limitValue)}'
        : '${currentValue.toInt()} / $limitValue';

    Color progressColor;
    if (progress >= 1.0) {
      progressColor = const Color(0xFFEF4444); // Soft Red
    } else if (progress >= 0.8) {
      progressColor = Colors.yellow.shade700; // Warning Yellow
    } else {
      progressColor = const Color(0xFF10B981); // Emerald
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          '$label (${(progress * 100).toStringAsFixed(0)}%)',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: displayProgress,
            minHeight: 8,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
          ),
        ),
        const SizedBox(height: 2),
        Align(
          alignment: Alignment.centerRight,
          child: Text(progressText, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ),
      ],
    );
  }

  Widget _buildInfoText(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 12, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // --- データ抽出 ---
    final isDanger = result['isDanger'] as bool;
    final stateCode = result['state'] as String;
    final stateName = result['stateName'] as String;
    final logicType = result['logicType'] as String;
    final txnLimit = result['txnLimit'] as int?;
    final salesLimit = result['salesLimit'] as int?;
    final totalSales = result['total'] as double;
    final txnCount = result['txnCount'] as int;
    final periodStartDate = result['periodStartDate'] as DateTime?;
    final lastUpdated = result['lastUpdated'] as DateTime?;

    // --- フォーマッター ---
    final dateFormatter = DateFormat.yMMMd('ja');
    final timeFormatter = DateFormat.Hm('ja');

    return Card(
      elevation: isDanger ? 4 : 1,
      color: isDanger ? const Color(0xFFFEF2F2) : Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 左カラム: 州コード ---
            CircleAvatar(
              radius: 20,
              backgroundColor: isDanger ? const Color(0xFFEF4444) : const Color(0xFF10B981),
              child: Text(stateCode, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),

            // --- 中央カラム: 詳細 ---
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(stateName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  _buildProgressInfo(context, totalSales, salesLimit, '売上'),
                  if (logicType != 'SALES_ONLY' && txnLimit != null)
                    _buildProgressInfo(context, txnCount.toDouble(), txnLimit, '取引数'),
                  
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      _buildInfoText(Icons.code, 'ロジック: $logicType'),
                      if(periodStartDate != null)
                        _buildInfoText(Icons.date_range, '期間: ${dateFormatter.format(periodStartDate)} ~'),
                      if(lastUpdated != null)
                        _buildInfoText(Icons.update, '更新: ${timeFormatter.format(lastUpdated)}'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // --- 右カラム: ステータス ---
            isDanger
                ? const Chip(
                    label: Text('NEXUS'),
                    backgroundColor: Color(0xFFEF4444),
                    labelStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    visualDensity: VisualDensity.compact,
                  )
                : const Chip(
                    label: Text('Safe'),
                    backgroundColor: Color(0xFF10B981),
                    labelStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    visualDensity: VisualDensity.compact,
                  ),
          ],
        ),
      ),
    );
  }
}
