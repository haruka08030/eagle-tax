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

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
      'sales_threshold': salesThreshold,
      'txn_threshold': txnThreshold,
      'logic_type': logicType,
    };
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
    switch (logicType) {
      case 'NONE':
        return false;

      case 'SALES_ONLY':
        if (salesThreshold == null) return false;
        return totalSales >= salesThreshold!;

      case 'OR':
        final salesExceeded = salesThreshold != null && totalSales >= salesThreshold!;
        final txnsExceeded = txnThreshold != null && transactionCount >= txnThreshold!;
        return salesExceeded || txnsExceeded;

      case 'AND':
        if (salesThreshold == null || txnThreshold == null) return false;
        return totalSales >= salesThreshold! && transactionCount >= txnThreshold!;
        
      default:
        return false;
    }
  }

  @override
  String toString() {
    return 'StateThreshold(code: $code, name: $name, sales: $salesThreshold, txn: $txnThreshold, logic: $logicType)';
  }
}
