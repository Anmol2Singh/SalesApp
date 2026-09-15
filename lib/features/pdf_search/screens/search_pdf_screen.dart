// lib/features/pdf_search/screens/search_pdf_screen.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/services/pdf_service.dart';
import '../../../core/widgets/pdf_preview_screen.dart';
import '../../../core/models/quotation.dart';
import '../../../core/models/sales_order.dart';
import '../../../core/models/customer.dart';
import '../../../core/models/product.dart';
import '../../../core/models/factory_order.dart';
import '../../../core/models/purchase_order.dart';
import '../../../core/models/boq.dart';
import '../../../core/models/warranty_card.dart';
import '../../../core/models/amc_contract.dart';

class SearchPdfScreen extends ConsumerStatefulWidget {
  const SearchPdfScreen({super.key});

  @override
  ConsumerState<SearchPdfScreen> createState() => _SearchPdfScreenState();
}

enum SearchMode { directNumber, typeAndInteger }

class DocSearchResult {
  final String docType; // 'quotation', 'sales_order', 'factory_order', 'purchase_order', 'boq', 'amc_contract', 'warranty_card'
  final String docNumber;
  final String title;
  final String customerName;
  final String? productName;
  final DateTime? date;
  final double? amount;
  final String? status;
  final Map<String, dynamic> rawData;

  DocSearchResult({
    required this.docType,
    required this.docNumber,
    required this.title,
    required this.customerName,
    this.productName,
    this.date,
    this.amount,
    this.status,
    required this.rawData,
  });

  String get docTypeDisplayName {
    switch (docType) {
      case 'quotation':
        return 'Quotation';
      case 'sales_order':
        return 'Sales Order';
      case 'factory_order':
        return 'Factory Order';
      case 'purchase_order':
        return 'Purchase Order';
      case 'boq':
        return 'BOQ';
      case 'amc_contract':
        return 'AMC Contract';
      case 'warranty_card':
        return 'Warranty Card';
      default:
        return docType.toUpperCase();
    }
  }

  IconData get icon {
    switch (docType) {
      case 'quotation':
        return Icons.request_quote_outlined;
      case 'sales_order':
        return Icons.receipt_long_outlined;
      case 'factory_order':
        return Icons.precision_manufacturing_outlined;
      case 'purchase_order':
        return Icons.shopping_cart_outlined;
      case 'boq':
        return Icons.format_list_numbered_outlined;
      case 'amc_contract':
        return Icons.verified_user_outlined;
      case 'warranty_card':
        return Icons.card_membership_outlined;
      default:
        return Icons.picture_as_pdf_outlined;
    }
  }
}

class _SearchPdfScreenState extends ConsumerState<SearchPdfScreen> {
  SearchMode _mode = SearchMode.directNumber;

  final TextEditingController _directNumberCtrl = TextEditingController();
  final TextEditingController _integerCtrl = TextEditingController();

  String _selectedDocType = 'quotation';

  bool _isSearching = false;
  bool _hasSearched = false;
  List<DocSearchResult> _results = [];
  String? _generatingDocId;

  final List<Map<String, String>> _docTypes = [
    {'key': 'quotation', 'label': 'Quotation (IZY/QT/...)', 'prefix': 'IZY/QT'},
    {'key': 'sales_order', 'label': 'Sales Order (IZY/SO/...)', 'prefix': 'IZY/SO'},
    {'key': 'factory_order', 'label': 'Factory Order (IZY/FO/...)', 'prefix': 'IZY/FO'},
    {'key': 'purchase_order', 'label': 'Purchase Order (IZY/PO/...)', 'prefix': 'IZY/PO'},
    {'key': 'boq', 'label': 'BOQ (IZY/BOQ/...)', 'prefix': 'IZY/BOQ'},
    {'key': 'amc_contract', 'label': 'AMC Contract (IZY/AMC/...)', 'prefix': 'IZY/AMC'},
    {'key': 'warranty_card', 'label': 'Warranty Card', 'prefix': 'WC'},
  ];

  @override
  void dispose() {
    _directNumberCtrl.dispose();
    _integerCtrl.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final supabase = ref.read(supabaseClientProvider);
    setState(() {
      _isSearching = true;
      _hasSearched = true;
      _results = [];
    });

    try {
      if (_mode == SearchMode.directNumber) {
        final query = _directNumberCtrl.text.trim();
        if (query.isEmpty) {
          setState(() => _isSearching = false);
          return;
        }
        await _searchDirectNumber(supabase, query);
      } else {
        final rawInt = _integerCtrl.text.trim();
        if (rawInt.isEmpty) {
          setState(() => _isSearching = false);
          return;
        }
        await _searchByTypeAndInteger(supabase, _selectedDocType, rawInt);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _searchDirectNumber(dynamic supabase, String query) async {
    final cleanQuery = query.replaceAll(' ', '').toUpperCase();
    final List<DocSearchResult> list = [];

    // Check by prefix first
    if (cleanQuery.contains('QT') || cleanQuery.startsWith('IZY/QT')) {
      list.addAll(await _queryQuotations(supabase, cleanQuery));
    } else if (cleanQuery.contains('SO') || cleanQuery.startsWith('IZY/SO')) {
      list.addAll(await _querySalesOrders(supabase, cleanQuery));
    } else if (cleanQuery.contains('FO') || cleanQuery.startsWith('IZY/FO')) {
      list.addAll(await _queryFactoryOrders(supabase, cleanQuery));
    } else if (cleanQuery.contains('PO') || cleanQuery.startsWith('IZY/PO')) {
      list.addAll(await _queryPurchaseOrders(supabase, cleanQuery));
    } else if (cleanQuery.contains('BOQ') || cleanQuery.startsWith('IZY/BOQ')) {
      list.addAll(await _queryBoqs(supabase, cleanQuery));
    } else if (cleanQuery.contains('AMC') || cleanQuery.startsWith('IZY/AMC')) {
      list.addAll(await _queryAmcContracts(supabase, cleanQuery));
    } else if (cleanQuery.contains('WC') || cleanQuery.startsWith('IZY/WC')) {
      list.addAll(await _queryWarrantyCards(supabase, cleanQuery));
    } else {
      // Parallel search across all tables
      final futures = await Future.wait([
        _queryQuotations(supabase, cleanQuery),
        _querySalesOrders(supabase, cleanQuery),
        _queryFactoryOrders(supabase, cleanQuery),
        _queryPurchaseOrders(supabase, cleanQuery),
        _queryBoqs(supabase, cleanQuery),
        _queryAmcContracts(supabase, cleanQuery),
        _queryWarrantyCards(supabase, cleanQuery),
      ]);
      for (final res in futures) {
        list.addAll(res);
      }
    }

    setState(() => _results = list);

    if (list.length == 1) {
      _openPdf(list.first);
    }
  }

  Future<void> _searchByTypeAndInteger(dynamic supabase, String type, String integerStr) async {
    final cleanInt = integerStr.trim();
    List<DocSearchResult> list = [];

    switch (type) {
      case 'quotation':
        list = await _queryQuotations(supabase, cleanInt, matchTrailingInteger: true);
        break;
      case 'sales_order':
        list = await _querySalesOrders(supabase, cleanInt, matchTrailingInteger: true);
        break;
      case 'factory_order':
        list = await _queryFactoryOrders(supabase, cleanInt, matchTrailingInteger: true);
        break;
      case 'purchase_order':
        list = await _queryPurchaseOrders(supabase, cleanInt, matchTrailingInteger: true);
        break;
      case 'boq':
        list = await _queryBoqs(supabase, cleanInt, matchTrailingInteger: true);
        break;
      case 'amc_contract':
        list = await _queryAmcContracts(supabase, cleanInt, matchTrailingInteger: true);
        break;
      case 'warranty_card':
        list = await _queryWarrantyCards(supabase, cleanInt, matchTrailingInteger: true);
        break;
    }

    setState(() => _results = list);

    if (list.length == 1) {
      _openPdf(list.first);
    }
  }

  // --- QUERY HELPERS ---

  Future<List<DocSearchResult>> _queryQuotations(dynamic supabase, String query, {bool matchTrailingInteger = false}) async {
    try {
      final padded = query.padLeft(4, '0');
      var q = supabase.from('quotations').select('*, sales_pipelines(*, customers(*), products(*))');
      if (matchTrailingInteger) {
        q = q.or('quotation_number.ilike.%$padded,quotation_number.ilike.%/$query');
      } else {
        q = q.ilike('quotation_number', '%$query%');
      }
      final res = await q.order('created_at', ascending: false).limit(10);
      return (res as List).map((row) {
        final pipeline = row['sales_pipelines'] as Map<String, dynamic>? ?? {};
        final customer = pipeline['customers'] as Map<String, dynamic>? ?? {};
        final product = pipeline['products'] as Map<String, dynamic>? ?? {};
        return DocSearchResult(
          docType: 'quotation',
          docNumber: row['quotation_number']?.toString() ?? 'Quotation',
          title: 'Quotation • ${row['quotation_number']}',
          customerName: customer['customer_name']?.toString() ?? customer['company_name']?.toString() ?? 'Customer',
          productName: product['name']?.toString(),
          date: DateTime.tryParse(row['created_at']?.toString() ?? ''),
          amount: (row['grand_total'] as num?)?.toDouble(),
          status: row['status']?.toString(),
          rawData: row as Map<String, dynamic>,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<DocSearchResult>> _querySalesOrders(dynamic supabase, String query, {bool matchTrailingInteger = false}) async {
    try {
      final padded = query.padLeft(4, '0');
      var q = supabase.from('sales_orders').select('*, sales_pipelines(*, customers(*), products(*))');
      if (matchTrailingInteger) {
        q = q.or('sales_order_number.ilike.%$padded,sales_order_number.ilike.%/$query');
      } else {
        q = q.or('sales_order_number.ilike.%$query%');
      }
      final res = await q.order('created_at', ascending: false).limit(10);
      return (res as List).map((row) {
        final pipeline = row['sales_pipelines'] as Map<String, dynamic>? ?? {};
        final customer = pipeline['customers'] as Map<String, dynamic>? ?? {};
        final product = pipeline['products'] as Map<String, dynamic>? ?? {};
        return DocSearchResult(
          docType: 'sales_order',
          docNumber: row['sales_order_number']?.toString() ?? 'Sales Order',
          title: 'Sales Order • ${row['sales_order_number']}',
          customerName: customer['customer_name']?.toString() ?? customer['company_name']?.toString() ?? 'Customer',
          productName: product['name']?.toString(),
          date: DateTime.tryParse(row['created_at']?.toString() ?? ''),
          amount: (row['grand_total'] as num?)?.toDouble(),
          status: row['status']?.toString(),
          rawData: row as Map<String, dynamic>,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<DocSearchResult>> _queryFactoryOrders(dynamic supabase, String query, {bool matchTrailingInteger = false}) async {
    try {
      final padded = query.padLeft(4, '0');
      var q = supabase.from('factory_orders').select('*, sales_pipelines(*, customers(*), products(*))');
      if (matchTrailingInteger) {
        q = q.or('order_number.ilike.%$padded,order_number.ilike.%/$query');
      } else {
        q = q.ilike('order_number', '%$query%');
      }
      final res = await q.order('created_at', ascending: false).limit(10);
      return (res as List).map((row) {
        final pipeline = row['sales_pipelines'] as Map<String, dynamic>? ?? {};
        final customer = pipeline['customers'] as Map<String, dynamic>? ?? {};
        final product = pipeline['products'] as Map<String, dynamic>? ?? {};
        return DocSearchResult(
          docType: 'factory_order',
          docNumber: row['order_number']?.toString() ?? 'Factory Order',
          title: 'Factory Order • ${row['order_number']}',
          customerName: customer['customer_name']?.toString() ?? customer['company_name']?.toString() ?? 'Customer',
          productName: product['name']?.toString(),
          date: DateTime.tryParse(row['created_at']?.toString() ?? ''),
          status: row['status']?.toString(),
          rawData: row as Map<String, dynamic>,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<DocSearchResult>> _queryPurchaseOrders(dynamic supabase, String query, {bool matchTrailingInteger = false}) async {
    try {
      final padded = query.padLeft(4, '0');
      var q = supabase.from('purchase_orders').select('*, sales_pipelines(*, customers(*), products(*))');
      if (matchTrailingInteger) {
        q = q.or('po_number.ilike.%$padded,po_number.ilike.%/$query');
      } else {
        q = q.ilike('po_number', '%$query%');
      }
      final res = await q.order('created_at', ascending: false).limit(10);
      return (res as List).map((row) {
        final pipeline = row['sales_pipelines'] as Map<String, dynamic>? ?? {};
        final customer = pipeline['customers'] as Map<String, dynamic>? ?? {};
        final product = pipeline['products'] as Map<String, dynamic>? ?? {};
        return DocSearchResult(
          docType: 'purchase_order',
          docNumber: row['po_number']?.toString() ?? 'Purchase Order',
          title: 'Purchase Order • ${row['po_number']}',
          customerName: customer['customer_name']?.toString() ?? customer['company_name']?.toString() ?? 'Customer',
          productName: product['name']?.toString(),
          date: DateTime.tryParse(row['created_at']?.toString() ?? ''),
          amount: (row['total_amount'] as num?)?.toDouble(),
          status: row['status']?.toString(),
          rawData: row as Map<String, dynamic>,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<DocSearchResult>> _queryBoqs(dynamic supabase, String query, {bool matchTrailingInteger = false}) async {
    try {
      final padded = query.padLeft(4, '0');
      var q = supabase.from('boqs').select('*, sales_pipelines(*, customers(*), products(*), quotations(*))');
      if (matchTrailingInteger) {
        q = q.or('boq_number.ilike.%$padded,boq_number.ilike.%/$query');
      } else {
        q = q.ilike('boq_number', '%$query%');
      }
      final res = await q.order('created_at', ascending: false).limit(10);
      return (res as List).map((row) {
        final pipeline = row['sales_pipelines'] as Map<String, dynamic>? ?? {};
        final customer = pipeline['customers'] as Map<String, dynamic>? ?? {};
        final product = pipeline['products'] as Map<String, dynamic>? ?? {};
        return DocSearchResult(
          docType: 'boq',
          docNumber: row['boq_number']?.toString() ?? 'BOQ',
          title: 'BOQ • ${row['boq_number']}',
          customerName: customer['customer_name']?.toString() ?? customer['company_name']?.toString() ?? 'Customer',
          productName: product['name']?.toString(),
          date: DateTime.tryParse(row['created_at']?.toString() ?? ''),
          status: row['status']?.toString(),
          rawData: row as Map<String, dynamic>,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<DocSearchResult>> _queryAmcContracts(dynamic supabase, String query, {bool matchTrailingInteger = false}) async {
    try {
      final padded = query.padLeft(4, '0');
      var q = supabase.from('amc_contracts').select('*, customers(*)');
      if (matchTrailingInteger) {
        q = q.or('contract_number.ilike.%$padded,contract_number.ilike.%/$query');
      } else {
        q = q.ilike('contract_number', '%$query%');
      }
      final res = await q.order('created_at', ascending: false).limit(10);
      return (res as List).map((row) {
        final customer = row['customers'] as Map<String, dynamic>? ?? {};
        final cNum = row['contract_number']?.toString() ?? 'AMC';
        return DocSearchResult(
          docType: 'amc_contract',
          docNumber: cNum,
          title: 'AMC Agreement • $cNum',
          customerName: customer['customer_name']?.toString() ?? customer['company_name']?.toString() ?? 'Customer',
          date: DateTime.tryParse(row['created_at']?.toString() ?? ''),
          amount: (row['contract_amount'] as num?)?.toDouble(),
          status: row['status']?.toString(),
          rawData: row as Map<String, dynamic>,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<DocSearchResult>> _queryWarrantyCards(dynamic supabase, String query, {bool matchTrailingInteger = false}) async {
    try {
      final padded = query.padLeft(4, '0');
      var q = supabase.from('warranty_cards').select('*, sales_pipelines(*, customers(*), products(*))');
      if (matchTrailingInteger) {
        q = q.or('invoice_number.ilike.%$padded,invoice_number.ilike.%/$query');
      } else {
        q = q.or('invoice_number.ilike.%$query%');
      }
      final res = await q.order('created_at', ascending: false).limit(10);
      return (res as List).map((row) {
        final pipeline = row['sales_pipelines'] as Map<String, dynamic>? ?? {};
        final customer = pipeline['customers'] as Map<String, dynamic>? ?? {};
        final product = pipeline['products'] as Map<String, dynamic>? ?? {};
        return DocSearchResult(
          docType: 'warranty_card',
          docNumber: row['invoice_number']?.toString() ?? 'WC',
          title: 'Warranty Card • ${row['invoice_number']}',
          customerName: customer['customer_name']?.toString() ?? customer['company_name']?.toString() ?? 'Customer',
          productName: product['name']?.toString(),
          date: DateTime.tryParse(row['created_at']?.toString() ?? ''),
          status: row['status']?.toString(),
          rawData: row as Map<String, dynamic>,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // --- PDF GENERATION & PREVIEW ---

  Future<void> _openPdf(DocSearchResult item) async {
    setState(() => _generatingDocId = item.docNumber);

    try {
      Uint8List? pdfBytes;
      String fileName = '${item.docNumber.replaceAll('/', '_')}.pdf';

      final templateConfig = await _fetchTemplateConfig(item.docType);

      if (item.docType == 'quotation') {
        final quotation = Quotation.fromJson(item.rawData);
        final pipelineData = item.rawData['sales_pipelines'] as Map<String, dynamic>? ?? {};
        final customer = Customer.fromJson(pipelineData['customers'] as Map<String, dynamic>? ?? {'id': '', 'company_name': item.customerName});
        final product = Product.fromJson(pipelineData['products'] as Map<String, dynamic>? ?? {'id': '', 'name': item.productName ?? 'Product'});
        pdfBytes = await PdfService.generateQuotationPdf(
          quotation: quotation,
          customer: customer,
          product: product,
          templateConfig: templateConfig,
        );
      } else if (item.docType == 'sales_order') {
        final so = SalesOrder.fromJson(item.rawData);
        final pipelineData = item.rawData['sales_pipelines'] as Map<String, dynamic>? ?? {};
        final customer = Customer.fromJson(pipelineData['customers'] as Map<String, dynamic>? ?? {'id': '', 'company_name': item.customerName});
        final product = Product.fromJson(pipelineData['products'] as Map<String, dynamic>? ?? {'id': '', 'name': item.productName ?? 'Product'});
        pdfBytes = await PdfService.generateSalesOrderPdf(
          salesOrder: so,
          customer: customer,
          product: product,
          variant: 'commercial',
          templateConfig: templateConfig,
        );
      } else if (item.docType == 'factory_order') {
        final fo = FactoryOrder.fromJson(item.rawData);
        final pipelineData = item.rawData['sales_pipelines'] as Map<String, dynamic>? ?? {};
        final customer = Customer.fromJson(pipelineData['customers'] as Map<String, dynamic>? ?? {'id': '', 'company_name': item.customerName});
        final product = Product.fromJson(pipelineData['products'] as Map<String, dynamic>? ?? {'id': '', 'name': item.productName ?? 'Product'});
        pdfBytes = await PdfService.generateFactoryOrderPdf(
          factoryOrder: fo,
          customer: customer,
          product: product,
          templateConfig: templateConfig,
        );
      } else if (item.docType == 'purchase_order') {
        final po = PurchaseOrder.fromJson(item.rawData);
        final pipelineData = item.rawData['sales_pipelines'] as Map<String, dynamic>? ?? {};
        final customer = Customer.fromJson(pipelineData['customers'] as Map<String, dynamic>? ?? {'id': '', 'company_name': item.customerName});
        final product = Product.fromJson(pipelineData['products'] as Map<String, dynamic>? ?? {'id': '', 'name': item.productName ?? 'Product'});
        pdfBytes = await PdfService.generatePurchaseOrderPdf(
          purchaseOrder: po,
          customer: customer,
          product: product,
          templateConfig: templateConfig,
        );
      } else if (item.docType == 'boq') {
        final boq = Boq.fromJson(item.rawData);
        final pipelineData = item.rawData['sales_pipelines'] as Map<String, dynamic>? ?? {};
        final customer = Customer.fromJson(pipelineData['customers'] as Map<String, dynamic>? ?? {'id': '', 'company_name': item.customerName});
        final product = Product.fromJson(pipelineData['products'] as Map<String, dynamic>? ?? {'id': '', 'name': item.productName ?? 'Product'});
        final quotData = pipelineData['quotations'] != null && (pipelineData['quotations'] as List).isNotEmpty
            ? (pipelineData['quotations'] as List).first as Map<String, dynamic>
            : <String, dynamic>{'id': '', 'pipeline_id': boq.pipelineId, 'quotation_number': 'REF', 'product_id': boq.id, 'status': 'draft'};
        final quotation = Quotation.fromJson(quotData);
        pdfBytes = await PdfService.generateBoqPdf(
          boq: boq,
          customer: customer,
          product: product,
          quotation: quotation,
          templateConfig: templateConfig,
        );
      } else if (item.docType == 'amc_contract') {
        final contract = AmcContract.fromJson(item.rawData);
        pdfBytes = await PdfService.generateAmcContractPdf(
          contract: contract,
          templateConfig: templateConfig,
        );
      } else if (item.docType == 'warranty_card') {
        final card = WarrantyCard.fromJson(item.rawData);
        pdfBytes = await PdfService.generateWarrantyCardPdf(
          card: card,
          templateConfig: templateConfig,
        );
      }

      if (pdfBytes != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PdfPreviewScreen(
              pdfBytes: pdfBytes!,
              fileName: fileName,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingDocId = null);
    }
  }

  Future<Map<String, dynamic>> _fetchTemplateConfig(String docType) async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      final res = await supabase
          .from('pdf_templates')
          .select()
          .eq('document_type', docType)
          .maybeSingle();
      if (res != null && res['template_config'] != null) {
        return res['template_config'] as Map<String, dynamic>;
      }
    } catch (_) {}
    return {
      'company_name': 'IZYHEAT (Insiya Solar Industry)',
      'company_address': 'Corporate Office, India',
      'company_phone': '+91 99999 99999',
      'company_email': 'info@izyheat.com',
      'company_gst': '27AAAAA1111A1Z1',
      'footer_text': 'Thank you for your business.',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Search PDF Documents'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mode Selector Segmented Tabs
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _mode = SearchMode.directNumber),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _mode == SearchMode.directNumber ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.tag,
                              size: 16,
                              color: _mode == SearchMode.directNumber ? Colors.white : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Direct Number',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: _mode == SearchMode.directNumber ? Colors.white : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _mode = SearchMode.typeAndInteger),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _mode == SearchMode.typeAndInteger ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.category_outlined,
                              size: 16,
                              color: _mode == SearchMode.typeAndInteger ? Colors.white : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Type + Integer',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: _mode == SearchMode.typeAndInteger ? Colors.white : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Search Input Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_mode == SearchMode.directNumber) ...[
                    const Text(
                      'Search Directly by Document Reference',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Enter full or partial reference number from any document (e.g. IZY/QT/2026/0030, IZY/SO/2026/0012, etc.)',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _directNumberCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        hintText: 'e.g. IZY/QT/2026/0030',
                        prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                        suffixIcon: _directNumberCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _directNumberCtrl.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                      ),
                      onSubmitted: (_) => _performSearch(),
                      onChanged: (_) => setState(() {}),
                    ),
                  ] else ...[
                    const Text(
                      'Search by Document Type & Trailing Number',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Select the document type and just enter the last digits (e.g. enter 30 for IZY/QT/2026/0030).',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedDocType,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Document Type',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: _docTypes.map((t) {
                        return DropdownMenuItem(
                          value: t['key'],
                          child: Text(t['label']!, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedDocType = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _integerCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Last Number / Trailing Integer',
                        hintText: 'e.g. 30 (matches ...0030)',
                        prefixIcon: const Icon(Icons.numbers, color: AppColors.primary),
                        suffixIcon: _integerCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _integerCtrl.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                      ),
                      onSubmitted: (_) => _performSearch(),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isSearching ? null : _performSearch,
                      icon: _isSearching
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.search),
                      label: Text(
                        _isSearching ? 'Searching Database...' : 'Search & Find PDF',
                        style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Search Results Section
            if (_hasSearched) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Search Results (${_results.length})',
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  if (_results.isNotEmpty)
                    Text(
                      'Tap to preview PDF',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.primary.withOpacity(0.8)),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              if (_results.isEmpty && !_isSearching)
                Container(
                  padding: const EdgeInsets.all(24),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.search_off_outlined, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text(
                        'No matching document found',
                        style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _mode == SearchMode.directNumber
                            ? 'Double check the reference number or try searching by document type.'
                            : 'No document in $_selectedDocType matches the integer entered.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                )
              else
                ..._results.map((item) {
                  final isGeneratingThis = _generatingDocId == item.docNumber;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(item.icon, color: AppColors.primary, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0F2744),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          item.docTypeDisplayName.toUpperCase(),
                                          style: const TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (item.status != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.primarySurface,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            item.status!.toUpperCase(),
                                            style: const TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.docNumber,
                                    style: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 10),

                        Row(
                          children: [
                            const Icon(Icons.person_outline, size: 15, color: AppColors.textSecondary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Customer: ${item.customerName}',
                                style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                              ),
                            ),
                          ],
                        ),
                        if (item.productName != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.inventory_2_outlined, size: 15, color: AppColors.textSecondary),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Product: ${item.productName}',
                                  style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (item.date != null || item.amount != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (item.date != null)
                                Text(
                                  'Date: ${DateFormat('dd MMM yyyy').format(item.date!)}',
                                  style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textSecondary),
                                )
                              else
                                const SizedBox.shrink(),
                              if (item.amount != null)
                                Text(
                                  '₹${item.amount!.toStringAsFixed(2)}',
                                  style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 14),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: isGeneratingThis
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.picture_as_pdf, size: 18),
                            label: Text(
                              isGeneratingThis ? 'Generating PDF Preview...' : 'Open PDF Preview',
                              style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold),
                            ),
                            onPressed: isGeneratingThis ? null : () => _openPdf(item),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ],
        ),
      ),
    );
  }
}
