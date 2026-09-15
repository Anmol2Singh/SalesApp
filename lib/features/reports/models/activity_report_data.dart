class ActivityReportData {
  final List<Map<String, dynamic>> customers;
  final List<Map<String, dynamic>> pipelines;
  final List<Map<String, dynamic>> complaints;
  final List<Map<String, dynamic>> stepAuditLogs;
  final List<Map<String, dynamic>> communications;
  final List<Map<String, dynamic>> leads;
  final List<Map<String, dynamic>> prospects;
  final List<Map<String, dynamic>> conversions;

  ActivityReportData({
    required this.customers,
    required this.pipelines,
    required this.complaints,
    this.stepAuditLogs = const [],
    this.communications = const [],
    this.leads = const [],
    this.prospects = const [],
    this.conversions = const [],
  });
}

