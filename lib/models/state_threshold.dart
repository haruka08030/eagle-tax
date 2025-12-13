/// Model class representing a US state's sales tax threshold data
class StateThreshold {
  final String code;
  final String name;
  final int salesThreshold;
  final int? txnThreshold;
  final String logicType;

  StateThreshold({
    required this.code,
    required this.name,
    required this.salesThreshold,
    this.txnThreshold,
    required this.logicType,
  });

  /// Create StateThreshold from Supabase JSON response
  factory StateThreshold.fromJson(Map<String, dynamic> json) {
    return StateThreshold(
      code: json['code'] as String,
      name: json['name'] as String,
      salesThreshold: json['sales_threshold'] as int,
      txnThreshold: json['txn_threshold'] as int?,
      logicType: json['logic_type'] as String,
    );
  }

  /// Check if nexus is reached based on logic type
  bool checkNexus({
    required double totalSales,
    required int transactionCount,
  }) {
    switch (logicType) {
      case 'SALES_ONLY':
        return totalSales >= salesThreshold;
      case 'OR':
        return totalSales >= salesThreshold ||
            (txnThreshold != null && transactionCount >= txnThreshold!);
      case 'AND':
        return totalSales >= salesThreshold &&
            (txnThreshold != null && transactionCount >= txnThreshold!);
      default:
        return false;
    }
  }

  @override
  String toString() {
    return 'StateThreshold(code: $code, name: $name, sales: $salesThreshold, txn: $txnThreshold, logic: $logicType)';
  }
}
