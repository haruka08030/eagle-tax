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
      BuildContext context, double currentValue, int? limitValue) {
    if (limitValue == null || limitValue == 0) {
      return const SizedBox.shrink(); // しきい値がなければ何も表示しない
    }

    final double progress = currentValue / limitValue;
    final double displayProgress = progress.clamp(0.0, 1.0);
    final String percentage = '${(progress * 100).toStringAsFixed(0)}%';

    Color progressColor;
    if (progress >= 1.0) {
      progressColor = Colors.red;
    } else if (progress >= 0.8) {
      progressColor = Colors.orange.shade600;
    } else {
      progressColor = Colors.green;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: displayProgress,
            minHeight: 12,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            percentage,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: progressColor,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDanger = result['isDanger'] as bool;
    final logicType = result['logicType'] as String;
    final txnLimit = result['txnLimit'] as int?;
    final salesLimit = result['salesLimit'] as int?;
    final currencyFormatter =
        NumberFormat.currency(locale: 'en_US', symbol: '\$');

    return Card(
      elevation: isDanger ? 4 : 1,
      color: isDanger ? Colors.red[50] : Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー部分 (州名とステータス)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: isDanger ? Colors.red : Colors.green,
                      child: Icon(
                        isDanger ? Icons.warning_amber_rounded : Icons.check,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${result['state']} - ${result['stateName']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                isDanger
                    ? const Chip(
                        label: Text('NEXUS REACHED'),
                        backgroundColor: Colors.red,
                        labelStyle: TextStyle(color: Colors.white),
                        visualDensity: VisualDensity.compact,
                      )
                    : const Chip(
                        label: Text('Safe'),
                        backgroundColor: Colors.green,
                        labelStyle: TextStyle(color: Colors.white),
                        visualDensity: VisualDensity.compact,
                      ),
              ],
            ),
            const Divider(height: 16),

            // 売上情報
            Text(
              logicType == 'NONE'
                  ? '💰 売上: ${currencyFormatter.format(result['total'])} / (経済ネクサスなし)'
                  : '💰 売上: ${currencyFormatter.format(result['total'])} / ${currencyFormatter.format(salesLimit ?? 0)}',
            ),
            _buildProgressInfo(context, result['total'] as double, salesLimit),

            // 取引数情報 (もしあれば)
            if (logicType != 'SALES_ONLY' && txnLimit != null) ...[
              const SizedBox(height: 12),
              Text('📦 取引数: ${result['txnCount']} / $txnLimit'),
              _buildProgressInfo(
                  context, (result['txnCount'] as int).toDouble(), txnLimit),
            ],
            
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '判定ロジック: $logicType',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
