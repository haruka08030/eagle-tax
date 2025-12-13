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
      salesThreshold: _toInt(json['sales_threshold']),
      txnThreshold: json['txn_threshold'] != null 
          ? _toInt(json['txn_threshold']) 
          : null,
      logicType: json['logic_type'] as String,
    );
  }

  /// Helper method to convert various numeric types to int
  static int _toInt(dynamic value) {
    if (value == null) {
      throw ArgumentError('Cannot convert null to int');
    }
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.parse(value);
    // Handle BigInt or other numeric types
    return int.parse(value.toString());
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
