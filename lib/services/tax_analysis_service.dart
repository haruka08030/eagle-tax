import '../models/state_threshold.dart';

class AnalysisResult {
  final List<Map<String, dynamic>> details;
  final int atRiskCount;
  final int warningCount;
  final double totalAnalyzedSales;

  AnalysisResult({
    required this.details,
    required this.atRiskCount,
    required this.warningCount,
    required this.totalAnalyzedSales,
  });
}

class TaxAnalysisService {
  
  /// 注文データを集計
  Map<String, dynamic> aggregateOrders(List<dynamic> orders, DateTime startDate, DateTime endDate) {
    Map<String, double> stateSales = {};
    Map<String, int> stateTransactions = {};
    int filteredCount = 0;
    final inclusiveEndDate = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

    for (var order in orders) {
      final shipping = order['shipping_address'];
      if (shipping == null || shipping['country_code'] != 'US') continue;

      final createdAt = order['created_at'];
      if (createdAt != null) {
        final orderDate = DateTime.parse(createdAt);
        if (orderDate.isBefore(startDate) || orderDate.isAfter(inclusiveEndDate)) {
          continue;
        }
      }

      final state = shipping['province_code'];
      if (state == null) continue;

      final totalPriceStr = order['total_price'];
      if (totalPriceStr == null) continue;

      final amount = double.tryParse(totalPriceStr.toString());
      if (amount == null) continue;
      stateSales[state] = (stateSales[state] ?? 0.0) + amount;
      stateTransactions[state] = (stateTransactions[state] ?? 0) + 1;
      filteredCount++;
    }
    return { 'stateSales': stateSales, 'stateTransactions': stateTransactions, 'filteredCount': filteredCount };
  }

  /// 集計データから結果リストを作成
  AnalysisResult createResults(
      Map<String, dynamic> aggregatedData, 
      DateTime startDate, 
      DateTime updateTime,
      List<StateThreshold> stateThresholds
  ) {
    final stateSales = aggregatedData['stateSales'] as Map<String, double>;
    final stateTransactions = aggregatedData['stateTransactions'] as Map<String, int>;
    List<Map<String, dynamic>> tempResults = [];

    int atRisk = 0;
    int warning = 0;
    double totalSalesSum = 0;

    for (var entry in stateSales.entries) {
      String stateCode = entry.key;
      double totalSales = entry.value;
      int txnCount = stateTransactions[stateCode] ?? 0;
      
      totalSalesSum += totalSales;

      StateThreshold? threshold = stateThresholds
          .where((st) => st.code == stateCode)
          .firstOrNull;

      if (threshold == null) continue;

      bool isDanger = threshold.checkNexus(
        totalSales: totalSales,
        transactionCount: txnCount,
      );

       if (isDanger) {
        atRisk++;
      } else {
        // Warning判定 (80%超え)
        bool isSalesWarning = threshold.salesThreshold != null && totalSales >= threshold.salesThreshold! * 0.8;
        bool isTxnWarning = threshold.txnThreshold != null && txnCount >= threshold.txnThreshold! * 0.8;
        
        bool isWarning = false;
        if (threshold.logicType == 'AND') {
           isWarning = isSalesWarning && isTxnWarning;
        } else {
           isWarning = isSalesWarning || isTxnWarning;
        }

        if (isWarning) warning++;
      }
      
      tempResults.add({
        'state': stateCode, 'stateName': threshold.name, 'total': totalSales,
        'txnCount': txnCount, 'salesLimit': threshold.salesThreshold, 'txnLimit': threshold.txnThreshold,
        'logicType': threshold.logicType, 'isDanger': isDanger, 'periodStartDate': startDate, 'lastUpdated': updateTime,
      });
    }

    tempResults.sort((a, b) {
      if (a['isDanger'] != b['isDanger']) return a['isDanger'] ? -1 : 1;
      return b['total'].compareTo(a['total']);
    });

    return AnalysisResult(
      details: tempResults,
      atRiskCount: atRisk,
      warningCount: warning,
      totalAnalyzedSales: totalSalesSum,
    );
  }
}
