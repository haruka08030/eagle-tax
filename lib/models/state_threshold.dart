class StateThreshold {
  final String code;
  final String name;
  final int? salesThreshold;
  final int? txnThreshold;
  final String logicType;

  StateThreshold({
    required this.code,
    required this.name,
    this.salesThreshold,
    this.txnThreshold,
    required this.logicType,
  });

  factory StateThreshold.fromJson(Map<String, dynamic> json) {
    return StateThreshold(
      code: json['code'] as String,
      name: json['name'] as String,
      salesThreshold: json['sales_threshold'] != null
          ? _toInt(json['sales_threshold'])
          : null,
      txnThreshold: json['txn_threshold'] != null 
          ? _toInt(json['txn_threshold']) 
          : null,
      logicType: json['logic_type'] as String,
    );
  }

  static int _toInt(dynamic value) {
    if (value == null) {
      throw ArgumentError('Cannot convert null to int');
    }
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.parse(value);
    return int.parse(value.toString());
  }

  bool checkNexus({
    required double totalSales,
    required int transactionCount,
  }) {
    if (logicType == 'NONE') return false;
    if (salesThreshold == null) return false;
    if (txnThreshold == null) return false;
    final limit = salesThreshold!;
    final countLimit = txnThreshold!;
    
    switch (logicType) {
      case 'SALES_ONLY':
        return totalSales >= limit;
      case 'OR':
        return totalSales >= limit ||
            (txnThreshold != null && transactionCount >= countLimit);
      case 'AND':
        return totalSales >= limit &&
            (txnThreshold != null && transactionCount >= countLimit);
      default:
        return false;
    }
  }

  @override
  String toString() {
    return 'StateThreshold(code: $code, name: $name, sales: $salesThreshold, txn: $txnThreshold, logic: $logicType)';
  }
}
