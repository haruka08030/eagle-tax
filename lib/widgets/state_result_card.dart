import 'package:flutter/material.dart';

/// 州の診断結果を表示するカードウィジェット
class StateResultCard extends StatelessWidget {
  final Map<String, dynamic> result;

  const StateResultCard({
    super.key,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final isDanger = result['isDanger'] as bool;
    final logicType = result['logicType'] as String;
    final txnLimit = result['txnLimit'] as int?;
    final salesLimit = result['salesLimit'] as int?;

    return Card(
      elevation: isDanger ? 4 : 1,
      color: isDanger ? Colors.red[50] : Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isDanger ? Colors.red : Colors.green,
          child: Icon(
            isDanger ? Icons.warning : Icons.check,
            color: Colors.white,
          ),
        ),
        title: Text(
          '${result['state']} - ${result['stateName']}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              logicType == 'NONE'
                  ? '💰 売上: \$${result['total'].toStringAsFixed(0)} / (免税)'
                  : '💰 売上: \$${result['total'].toStringAsFixed(0)} / \$${salesLimit ?? 0}',
              style: TextStyle(
                fontWeight: salesLimit != null && result['total'] >= salesLimit
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
            if (txnLimit != null)
              Text(
                '📦 取引数: ${result['txnCount']} / $txnLimit',
                style: TextStyle(
                  fontWeight: result['txnCount'] >= txnLimit
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
  }
}
