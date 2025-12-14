import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DashboardSummaryCard extends StatelessWidget {
  final int atRiskCount;
  final int warningCount;
  final double totalAnalyzedSales;

  const DashboardSummaryCard({
    super.key,
    required this.atRiskCount,
    required this.warningCount,
    required this.totalAnalyzedSales,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: IntrinsicHeight( // 内部の高さを統一
          child: Row(
            children: [
              // 🚨 At Risk
              Expanded(
                child: _buildSummaryItem(
                  context,
                  label: 'Nexus Reached',
                  value: atRiskCount.toString(),
                  icon: Icons.warning_rounded,
                  color: const Color(0xFFEF4444), // Red
                  unit: 'States',
                ),
              ),
              const VerticalDivider(width: 32, thickness: 1), // 仕切り線
              
              // ⚠️ Warning
              Expanded(
                child: _buildSummaryItem(
                  context,
                  label: 'Warning (>80%)',
                  value: warningCount.toString(),
                  icon: Icons.notifications_active_rounded,
                  color: Colors.yellow.shade800, // Darker Yellow
                  unit: 'States',
                ),
              ),
              const VerticalDivider(width: 32, thickness: 1),

              // 💰 Total Analyzed
              Expanded(
                flex: 2, // 売上は少し広めに
                child: _buildSummaryItem(
                  context,
                  label: 'Analyzed Sales (12mo)',
                  value: NumberFormat.currency(locale: 'en_US', symbol: '\$')
                      .format(totalAnalyzedSales),
                  icon: Icons.attach_money_rounded,
                  color: const Color(0xFF4F46E5), // Indigo
                  unit: 'Total',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required String unit,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          unit,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }
}
