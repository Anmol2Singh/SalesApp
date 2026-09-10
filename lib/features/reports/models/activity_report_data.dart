class ActivityReportData {
  final List<Map<String, dynamic>> customers;
  final List<Map<String, dynamic>> pipelines;
  final List<Map<String, dynamic>> complaints;

  ActivityReportData({
    required this.customers,
    required this.pipelines,
    required this.complaints,
  });
}
