import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/models/user_role.dart';
import '../../../core/models/customer.dart';
import '../../../core/models/product.dart';
import '../../../core/models/quotation.dart';
import '../../../core/models/sales_order.dart';
import '../../../core/models/factory_order.dart';
import '../../../core/models/purchase_order.dart';
import '../../../core/models/boq.dart';
import '../../../core/models/amc_contract.dart';
import '../../../core/models/warranty_card.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/services/pdf_service.dart';
import '../../../core/widgets/pdf_preview_screen.dart';
import '../../../core/utils/financial_year_helper.dart';
import '../../auth/providers/auth_provider.dart';
import '../../complaints/data/models/complaint_model.dart';
import '../../complaints/services/complaint_pdf_service.dart';
import '../../installations/data/models/installation_model.dart';
import '../../installations/services/installation_pdf_service.dart';

enum PdfCategoryType {
  quotation,
  salesOrder,
  boq,
  factoryOrder,
  materialRequisition,
  complaints,
  installation,
  amcWarranty,
}

class PdfCategoryInfo {
  final PdfCategoryType type;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String docPrefix;

  const PdfCategoryInfo({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.docPrefix,
  });
}

const List<PdfCategoryInfo> _kPdfCategories = [
  PdfCategoryInfo(
    type: PdfCategoryType.quotation,
    title: 'Quotation',
    subtitle: 'Active quotes, pricing proposals & estimates',
    icon: Icons.request_quote_outlined,
    color: Color(0xFF3B82F6), // Blue
    docPrefix: 'IZY/QT',
  ),
  PdfCategoryInfo(
    type: PdfCategoryType.salesOrder,
    title: 'Sales Order',
    subtitle: 'Confirmed buyer sales orders & payment milestones',
    icon: Icons.receipt_long_outlined,
    color: Color(0xFF0D9488), // Teal
    docPrefix: 'IZY/SO',
  ),
  PdfCategoryInfo(
    type: PdfCategoryType.boq,
    title: 'BOQ',
    subtitle: 'Bill of quantities, technical specs & line items',
    icon: Icons.format_list_numbered_outlined,
    color: Color(0xFFF59E0B), // Amber
    docPrefix: 'IZY/BOQ',
  ),
  PdfCategoryInfo(
    type: PdfCategoryType.factoryOrder,
    title: 'Factory Order',
    subtitle: 'Production & manufacturing work orders',
    icon: Icons.precision_manufacturing_outlined,
    color: Color(0xFF8B5CF6), // Purple
    docPrefix: 'IZY/FO',
  ),
  PdfCategoryInfo(
    type: PdfCategoryType.materialRequisition,
    title: 'Material Requisition',
    subtitle: 'Purchase orders, indent requests & vendor POs',
    icon: Icons.shopping_cart_outlined,
    color: Color(0xFF10B981), // Emerald
    docPrefix: 'IZY/PO',
  ),
  PdfCategoryInfo(
    type: PdfCategoryType.complaints,
    title: 'Complaints',
    subtitle: 'Service tickets & technician resolution reports',
    icon: Icons.build_outlined,
    color: Color(0xFFEF4444), // Red
    docPrefix: 'CMP',
  ),
  PdfCategoryInfo(
    type: PdfCategoryType.installation,
    title: 'Installation',
    subtitle: 'Site commissioning & handover reports',
    icon: Icons.build_circle_outlined,
    color: Color(0xFF0284C7), // Sky
    docPrefix: 'INS',
  ),
  PdfCategoryInfo(
    type: PdfCategoryType.amcWarranty,
    title: 'AMC & Warranty',
    subtitle: 'Annual maintenance contracts & warranty cards',
    icon: Icons.verified_user_outlined,
    color: Color(0xFF6366F1), // Indigo
    docPrefix: 'AMC/WC',
  ),
];

/// The main hub screen asking the user to choose a PDF document name.
class PdfListHubScreen extends ConsumerWidget {
  const PdfListHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final isAdmin = profile?.primaryRole == UserRole.admin ||
        profile?.primaryRole == UserRole.manager ||
        (profile?.roles.contains(UserRole.admin) ?? false) ||
        (profile?.roles.contains(UserRole.manager) ?? false);

    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('List of PDFs')),
        body: const Center(
          child: Text(
            'Access Restricted: Only Admins can view the PDF registry.',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'List of PDFs',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF334155)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.picture_as_pdf_outlined,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'PDF Document Registry',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Select a document type below to view all generated active PDFs with preview, download, print, and share options.',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: Color(0xFFCBD5E1),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                'Choose Document Type',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 12),

              // Document Category Buttons Grid
              LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth >= 720 ? 3 : 2;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: constraints.maxWidth >= 720 ? 1.65 : 1.35,
                    ),
                    itemCount: _kPdfCategories.length,
                    itemBuilder: (context, index) {
                      final cat = _kPdfCategories[index];
                      return _PdfCategoryCard(
                        category: cat,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PdfCategoryListScreen(category: cat),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PdfCategoryCard extends StatelessWidget {
  final PdfCategoryInfo category;
  final VoidCallback onTap;

  const _PdfCategoryCard({
    required this.category,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        hoverColor: category.color.withValues(alpha: 0.05),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: category.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      category.icon,
                      color: category.color,
                      size: 24,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      category.docPrefix,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    category.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: Color(0xFF64748B),
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Generic record item representing any document in the list.
class _PdfDocItem {
  final String id;
  final String docType;
  final String docNumber;
  final String customerName;
  final String? customerPhone;
  final String? productName;
  final DateTime? date;
  final double? amount;
  final String? status;
  final Map<String, dynamic> rawData;

  _PdfDocItem({
    required this.id,
    required this.docType,
    required this.docNumber,
    required this.customerName,
    this.customerPhone,
    this.productName,
    this.date,
    this.amount,
    this.status,
    required this.rawData,
  });
}

/// The list screen that fetches, displays, filters, and generates PDFs for the selected category.
class PdfCategoryListScreen extends ConsumerStatefulWidget {
  final PdfCategoryInfo category;

  const PdfCategoryListScreen({
    super.key,
    required this.category,
  });

  @override
  ConsumerState<PdfCategoryListScreen> createState() => _PdfCategoryListScreenState();
}

class _PdfCategoryListScreenState extends ConsumerState<PdfCategoryListScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  String? _errorMessage;
  List<_PdfDocItem> _allItems = [];
  List<_PdfDocItem> _filteredItems = [];
  String? _activeGeneratingId;

  @override
  void initState() {
    super.initState();
    _fetchCategoryDocuments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredItems = List.from(_allItems);
      } else {
        _filteredItems = _allItems.where((item) {
          final numMatch = item.docNumber.toLowerCase().contains(q);
          final custMatch = item.customerName.toLowerCase().contains(q);
          final prodMatch = (item.productName ?? '').toLowerCase().contains(q);
          final phoneMatch = (item.customerPhone ?? '').contains(q);
          return numMatch || custMatch || prodMatch || phoneMatch;
        }).toList();
      }
    });
  }

  Future<void> _fetchCategoryDocuments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final supabase = ref.read(supabaseClientProvider);
      final List<_PdfDocItem> list = [];

      switch (widget.category.type) {
        case PdfCategoryType.quotation:
          final res = await supabase
              .from('quotations')
              .select('*, sales_pipelines(*, customers(*), products(*))')
              .order('created_at', ascending: false)
              .limit(100);

          for (final row in (res as List? ?? [])) {
            final st = row['status']?.toString().toLowerCase() ?? '';
            if (st == 'cancelled' || st == 'deleted') continue;

            final pipe = row['sales_pipelines'] as Map<String, dynamic>? ?? {};
            final cust = pipe['customers'] as Map<String, dynamic>? ?? {};
            final prod = pipe['products'] as Map<String, dynamic>? ?? {};
            list.add(
              _PdfDocItem(
                id: row['id']?.toString() ?? '',
                docType: 'quotation',
                docNumber: FinancialYearHelper.formatDocumentNumber(
                  row['quotation_number']?.toString() ?? 'Quotation',
                  DateTime.tryParse(row['created_at']?.toString() ?? ''),
                ),
                customerName: cust['customer_name']?.toString() ?? cust['company_name']?.toString() ?? 'Customer',
                customerPhone: cust['phone']?.toString(),
                productName: prod['name']?.toString() ?? row['product_name']?.toString(),
                date: DateTime.tryParse(row['created_at']?.toString() ?? ''),
                amount: (row['final_total'] ?? row['total_amount'] as num?)?.toDouble(),
                status: row['status']?.toString(),
                rawData: row as Map<String, dynamic>,
              ),
            );
          }
          break;

        case PdfCategoryType.salesOrder:
          final res = await supabase
              .from('sales_orders')
              .select('*, sales_pipelines(*, customers(*), products(*))')
              .order('created_at', ascending: false)
              .limit(100);

          for (final row in (res as List? ?? [])) {
            final st = row['status']?.toString().toLowerCase() ?? '';
            if (st == 'cancelled' || st == 'deleted') continue;

            final pipe = row['sales_pipelines'] as Map<String, dynamic>? ?? {};
            final cust = pipe['customers'] as Map<String, dynamic>? ?? {};
            final prod = pipe['products'] as Map<String, dynamic>? ?? {};
            list.add(
              _PdfDocItem(
                id: row['id']?.toString() ?? '',
                docType: 'sales_order',
                docNumber: PdfService.formatSalesOrderNumber(
                  row['sales_order_number']?.toString() ?? row['so_number']?.toString() ?? 'Sales Order',
                  DateTime.tryParse(row['created_at']?.toString() ?? ''),
                ),
                customerName: cust['customer_name']?.toString() ?? cust['company_name']?.toString() ?? 'Customer',
                customerPhone: cust['phone']?.toString(),
                productName: prod['name']?.toString(),
                date: DateTime.tryParse(row['created_at']?.toString() ?? ''),
                amount: (row['total_amount'] as num?)?.toDouble(),
                status: row['status']?.toString(),
                rawData: row as Map<String, dynamic>,
              ),
            );
          }
          break;

        case PdfCategoryType.boq:
          final res = await supabase
              .from('boqs')
              .select('*, sales_pipelines(*, customers(*), products(*), quotations(*))')
              .order('created_at', ascending: false)
              .limit(100);

          for (final row in (res as List? ?? [])) {
            final st = row['status']?.toString().toLowerCase() ?? '';
            if (st == 'cancelled' || st == 'deleted') continue;

            final pipe = row['sales_pipelines'] as Map<String, dynamic>? ?? {};
            final cust = pipe['customers'] as Map<String, dynamic>? ?? {};
            final prod = pipe['products'] as Map<String, dynamic>? ?? {};
            list.add(
              _PdfDocItem(
                id: row['id']?.toString() ?? '',
                docType: 'boq',
                docNumber: FinancialYearHelper.formatDocumentNumber(
                  row['boq_number']?.toString() ?? 'BOQ',
                  DateTime.tryParse(row['created_at']?.toString() ?? ''),
                ),
                customerName: cust['customer_name']?.toString() ?? cust['company_name']?.toString() ?? 'Customer',
                customerPhone: cust['phone']?.toString(),
                productName: prod['name']?.toString(),
                date: DateTime.tryParse(row['created_at']?.toString() ?? ''),
                status: row['status']?.toString(),
                rawData: row as Map<String, dynamic>,
              ),
            );
          }
          break;

        case PdfCategoryType.factoryOrder:
          final res = await supabase
              .from('factory_orders')
              .select('*, sales_pipelines(*, customers(*), products(*))')
              .order('created_at', ascending: false)
              .limit(100);

          for (final row in (res as List? ?? [])) {
            final st = row['status']?.toString().toLowerCase() ?? '';
            if (st == 'cancelled' || st == 'deleted') continue;

            final pipe = row['sales_pipelines'] as Map<String, dynamic>? ?? {};
            final cust = pipe['customers'] as Map<String, dynamic>? ?? {};
            final prod = pipe['products'] as Map<String, dynamic>? ?? {};
            list.add(
              _PdfDocItem(
                id: row['id']?.toString() ?? '',
                docType: 'factory_order',
                docNumber: FinancialYearHelper.formatDocumentNumber(
                  row['fo_number']?.toString() ?? row['order_number']?.toString() ?? 'Factory Order',
                  DateTime.tryParse(row['created_at']?.toString() ?? ''),
                ),
                customerName: cust['customer_name']?.toString() ?? cust['company_name']?.toString() ?? 'Customer',
                customerPhone: cust['phone']?.toString(),
                productName: prod['name']?.toString(),
                date: DateTime.tryParse(row['created_at']?.toString() ?? ''),
                status: row['status']?.toString(),
                rawData: row as Map<String, dynamic>,
              ),
            );
          }
          break;

        case PdfCategoryType.materialRequisition:
          final res = await supabase
              .from('purchase_orders')
              .select('*, sales_pipelines(*, customers(*), products(*))')
              .order('created_at', ascending: false)
              .limit(100);

          for (final row in (res as List? ?? [])) {
            final st = row['status']?.toString().toLowerCase() ?? '';
            if (st == 'cancelled' || st == 'deleted') continue;

            final pipe = row['sales_pipelines'] as Map<String, dynamic>? ?? {};
            final cust = pipe['customers'] as Map<String, dynamic>? ?? {};
            final prod = pipe['products'] as Map<String, dynamic>? ?? {};
            list.add(
              _PdfDocItem(
                id: row['id']?.toString() ?? '',
                docType: 'purchase_order',
                docNumber: FinancialYearHelper.formatDocumentNumber(
                  row['po_number']?.toString() ?? 'Purchase Order',
                  DateTime.tryParse(row['created_at']?.toString() ?? ''),
                ),
                customerName: cust['customer_name']?.toString() ?? cust['company_name']?.toString() ?? 'Customer',
                customerPhone: cust['phone']?.toString(),
                productName: prod['name']?.toString(),
                date: DateTime.tryParse(row['created_at']?.toString() ?? ''),
                amount: (row['total_amount'] as num?)?.toDouble(),
                status: row['status']?.toString(),
                rawData: row as Map<String, dynamic>,
              ),
            );
          }
          break;

        case PdfCategoryType.complaints:
          final res = await supabase
              .from('complaints')
              .select('*')
              .order('created_at', ascending: false)
              .limit(100);

          for (final row in (res as List? ?? [])) {
            final st = row['status']?.toString().toLowerCase() ?? '';
            if (st == 'cancelled' || st == 'deleted') continue;

            final ticketNum = row['ticket_number']?.toString() ?? 'CMP';
            list.add(
              _PdfDocItem(
                id: row['id']?.toString() ?? '',
                docType: 'complaints',
                docNumber: ticketNum,
                customerName: row['customer_name']?.toString() ?? 'Customer',
                customerPhone: row['customer_phone']?.toString(),
                productName: row['product_name']?.toString(),
                date: DateTime.tryParse(row['created_at']?.toString() ?? ''),
                status: row['status']?.toString(),
                rawData: row as Map<String, dynamic>,
              ),
            );
          }
          break;

        case PdfCategoryType.installation:
          final res = await supabase
              .from('installations')
              .select('*')
              .order('created_at', ascending: false)
              .limit(100);

          for (final row in (res as List? ?? [])) {
            final st = row['status']?.toString().toLowerCase() ?? '';
            if (st == 'cancelled' || st == 'deleted') continue;

            final ticketNum = row['ticket_number']?.toString() ?? 'INS';
            list.add(
              _PdfDocItem(
                id: row['id']?.toString() ?? '',
                docType: 'installation',
                docNumber: ticketNum,
                customerName: row['customer_name']?.toString() ?? 'Customer',
                customerPhone: row['customer_phone']?.toString(),
                productName: row['product_name']?.toString(),
                date: DateTime.tryParse(row['created_at']?.toString() ?? ''),
                status: row['status']?.toString(),
                rawData: row as Map<String, dynamic>,
              ),
            );
          }
          break;

        case PdfCategoryType.amcWarranty:
          // Combine AMC contracts and Warranty cards
          try {
            final amcRes = await supabase
                .from('amc_contracts')
                .select('*, customers(*)')
                .order('created_at', ascending: false)
                .limit(50);

            for (final row in (amcRes as List? ?? [])) {
              final st = row['status']?.toString().toLowerCase() ?? '';
              if (st == 'cancelled' || st == 'deleted') continue;

              final cust = row['customers'] as Map<String, dynamic>? ?? {};
              list.add(
                _PdfDocItem(
                  id: row['id']?.toString() ?? '',
                  docType: 'amc_contract',
                  docNumber: row['contract_number']?.toString() ?? 'AMC',
                  customerName: cust['customer_name']?.toString() ?? cust['company_name']?.toString() ?? 'Customer',
                  customerPhone: cust['phone']?.toString(),
                  date: DateTime.tryParse(row['created_at']?.toString() ?? ''),
                  amount: (row['contract_amount'] as num?)?.toDouble(),
                  status: row['status']?.toString(),
                  rawData: row as Map<String, dynamic>,
                ),
              );
            }
          } catch (_) {}

          try {
            final wcRes = await supabase
                .from('warranty_cards')
                .select('*, sales_pipelines(*, customers(*), products(*))')
                .order('created_at', ascending: false)
                .limit(50);

            for (final row in (wcRes as List? ?? [])) {
              final st = row['status']?.toString().toLowerCase() ?? '';
              if (st == 'cancelled' || st == 'deleted') continue;

              final pipe = row['sales_pipelines'] as Map<String, dynamic>? ?? {};
              final cust = pipe['customers'] as Map<String, dynamic>? ?? {};
              final prod = pipe['products'] as Map<String, dynamic>? ?? {};
              list.add(
                _PdfDocItem(
                  id: row['id']?.toString() ?? '',
                  docType: 'warranty_card',
                  docNumber: row['invoice_number']?.toString() ?? 'WC',
                  customerName: cust['customer_name']?.toString() ?? cust['company_name']?.toString() ?? 'Customer',
                  customerPhone: cust['phone']?.toString(),
                  productName: prod['name']?.toString(),
                  date: DateTime.tryParse(row['created_at']?.toString() ?? ''),
                  status: row['status']?.toString(),
                  rawData: row as Map<String, dynamic>,
                ),
              );
            }
          } catch (_) {}
          break;
      }

      if (mounted) {
        setState(() {
          _allItems = list;
          _filteredItems = List.from(list);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>?> _fetchTemplateConfig(String docType) async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      final res = await supabase
          .from('pdf_templates')
          .select('config')
          .eq('doc_type', docType)
          .maybeSingle();
      if (res != null && res['config'] is Map) {
        return res['config'] as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<Uint8List?> _generatePdfBytes(_PdfDocItem item) async {
    final templateConfig = (await _fetchTemplateConfig(item.docType)) ?? <String, dynamic>{};

    switch (item.docType) {
      case 'quotation':
        final quotation = Quotation.fromJson(item.rawData);
        final pipe = item.rawData['sales_pipelines'] as Map<String, dynamic>? ?? {};
        final customer = Customer.fromJson(pipe['customers'] as Map<String, dynamic>? ?? {'id': '', 'company_name': item.customerName});
        final product = Product.fromJson(pipe['products'] as Map<String, dynamic>? ?? {'id': '', 'name': item.productName ?? 'Product'});
        return PdfService.generateQuotationPdf(
          quotation: quotation,
          customer: customer,
          product: product,
          templateConfig: templateConfig,
        );

      case 'sales_order':
        final so = SalesOrder.fromJson(item.rawData);
        final pipe = item.rawData['sales_pipelines'] as Map<String, dynamic>? ?? {};
        final customer = Customer.fromJson(pipe['customers'] as Map<String, dynamic>? ?? {'id': '', 'company_name': item.customerName});
        final product = Product.fromJson(pipe['products'] as Map<String, dynamic>? ?? {'id': '', 'name': item.productName ?? 'Product'});
        return PdfService.generateSalesOrderPdf(
          salesOrder: so,
          customer: customer,
          product: product,
          variant: 'commercial',
          templateConfig: templateConfig,
        );

      case 'boq':
        final boq = Boq.fromJson(item.rawData);
        final pipe = item.rawData['sales_pipelines'] as Map<String, dynamic>? ?? {};
        final customer = Customer.fromJson(pipe['customers'] as Map<String, dynamic>? ?? {'id': '', 'company_name': item.customerName});
        final product = Product.fromJson(pipe['products'] as Map<String, dynamic>? ?? {'id': '', 'name': item.productName ?? 'Product'});
        Map<String, dynamic> quotData;
        final rawQuot = pipe['quotations'];
        if (rawQuot is Map<String, dynamic>) {
          quotData = rawQuot;
        } else if (rawQuot is List && rawQuot.isNotEmpty) {
          quotData = rawQuot.first as Map<String, dynamic>;
        } else {
          quotData = <String, dynamic>{'id': '', 'pipeline_id': boq.pipelineId, 'quotation_number': 'REF', 'product_id': boq.id, 'status': 'draft'};
        }
        final quotation = Quotation.fromJson(quotData);
        return PdfService.generateBoqPdf(
          boq: boq,
          customer: customer,
          product: product,
          quotation: quotation,
          templateConfig: templateConfig,
        );

      case 'factory_order':
        final fo = FactoryOrder.fromJson(item.rawData);
        final pipe = item.rawData['sales_pipelines'] as Map<String, dynamic>? ?? {};
        final customer = Customer.fromJson(pipe['customers'] as Map<String, dynamic>? ?? {'id': '', 'company_name': item.customerName});
        final product = Product.fromJson(pipe['products'] as Map<String, dynamic>? ?? {'id': '', 'name': item.productName ?? 'Product'});
        return PdfService.generateFactoryOrderPdf(
          factoryOrder: fo,
          customer: customer,
          product: product,
          templateConfig: templateConfig,
        );

      case 'purchase_order':
        final po = PurchaseOrder.fromJson(item.rawData);
        final pipe = item.rawData['sales_pipelines'] as Map<String, dynamic>? ?? {};
        final customer = Customer.fromJson(pipe['customers'] as Map<String, dynamic>? ?? {'id': '', 'company_name': item.customerName});
        final product = Product.fromJson(pipe['products'] as Map<String, dynamic>? ?? {'id': '', 'name': item.productName ?? 'Product'});
        return PdfService.generatePurchaseOrderPdf(
          purchaseOrder: po,
          customer: customer,
          product: product,
          templateConfig: templateConfig,
        );

      case 'complaints':
        final complaint = Complaint.fromJson(item.rawData);
        return ComplaintPdfService.generateCompletionReportPdf(complaint);

      case 'installation':
        final installation = Installation.fromJson(item.rawData);
        return InstallationPdfService.generateCompletionReportPdf(installation);

      case 'amc_contract':
        final contract = AmcContract.fromJson(item.rawData);
        return PdfService.generateAmcContractPdf(
          contract: contract,
          templateConfig: templateConfig,
        );

      case 'warranty_card':
        final card = WarrantyCard.fromJson(item.rawData);
        return PdfService.generateWarrantyCardPdf(
          card: card,
          templateConfig: templateConfig,
        );

      default:
        return null;
    }
  }

  Future<void> _handlePreview(_PdfDocItem item) async {
    setState(() => _activeGeneratingId = item.id);
    try {
      final pdfBytes = await _generatePdfBytes(item);
      if (pdfBytes != null && mounted) {
        final safeName = '${item.docNumber.replaceAll(RegExp(r'[/\\?%*:|"<>]'), '_')}.pdf';
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PdfPreviewScreen(
              pdfBytes: pdfBytes,
              fileName: safeName,
            ),
          ),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not generate PDF.'), backgroundColor: AppColors.error),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _activeGeneratingId = null);
    }
  }

  Future<void> _handleDownload(_PdfDocItem item) async {
    setState(() => _activeGeneratingId = item.id);
    try {
      final pdfBytes = await _generatePdfBytes(item);
      if (pdfBytes == null) throw Exception('PDF generation returned empty');

      final safeName = '${item.docNumber.replaceAll(RegExp(r'[/\\?%*:|"<>]'), '_')}.pdf';

      if (kIsWeb) {
        await Printing.sharePdf(bytes: pdfBytes, filename: safeName);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✓ Downloaded: $safeName'), backgroundColor: AppColors.success),
          );
        }
        return;
      }

      if (Platform.isWindows) {
        final userProfile = Platform.environment['USERPROFILE'];
        Directory? winDownloads;
        if (userProfile != null) {
          final candidate = Directory('$userProfile\\Downloads');
          if (candidate.existsSync()) winDownloads = candidate;
        }
        winDownloads ??= await getDownloadsDirectory();
        if (winDownloads != null) {
          final file = File('${winDownloads.path}/$safeName');
          await file.writeAsBytes(pdfBytes, flush: true);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✓ Saved to Downloads: $safeName'),
                backgroundColor: AppColors.success,
              ),
            );
          }
          return;
        }
      }

      // Android or fallback
      await Printing.sharePdf(bytes: pdfBytes, filename: safeName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✓ PDF ready: $safeName'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error downloading PDF: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _activeGeneratingId = null);
    }
  }

  Future<void> _handlePrint(_PdfDocItem item) async {
    setState(() => _activeGeneratingId = item.id);
    try {
      final pdfBytes = await _generatePdfBytes(item);
      if (pdfBytes != null) {
        await Printing.layoutPdf(
          onLayout: (_) async => pdfBytes,
          name: '${item.docNumber}.pdf',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error printing PDF: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _activeGeneratingId = null);
    }
  }

  Future<void> _handleShare(_PdfDocItem item) async {
    setState(() => _activeGeneratingId = item.id);
    try {
      final pdfBytes = await _generatePdfBytes(item);
      if (pdfBytes != null) {
        final safeName = '${item.docNumber.replaceAll(RegExp(r'[/\\?%*:|"<>]'), '_')}.pdf';
        try {
          await Share.shareXFiles(
            [XFile.fromData(pdfBytes, name: safeName, mimeType: 'application/pdf')],
            subject: '${widget.category.title} - ${item.docNumber}',
          );
        } catch (_) {
          await Printing.sharePdf(bytes: pdfBytes, filename: safeName);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing PDF: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _activeGeneratingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat('#,##,##0', 'en_IN');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          '${widget.category.title} PDFs',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh',
            onPressed: _fetchCategoryDocuments,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar Header
            Container(
              color: const Color(0xFF1E293B),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search by ${widget.category.title} #, customer, product...',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
                  prefixIcon: const Icon(Icons.search, color: Colors.white70, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white70, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.12),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // Count & Active Info Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFFF1F5F9),
              child: Row(
                children: [
                  Icon(widget.category.icon, size: 16, color: widget.category.color),
                  const SizedBox(width: 6),
                  Text(
                    'Active Generated ${widget.category.title}s',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: widget.category.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_filteredItems.length} Records',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: widget.category.color,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Main Content
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    )
                  : _errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline, color: AppColors.error, size: 40),
                                const SizedBox(height: 10),
                                Text(
                                  'Error: $_errorMessage',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: AppColors.error),
                                ),
                                const SizedBox(height: 14),
                                ElevatedButton(
                                  onPressed: _fetchCategoryDocuments,
                                  child: const Text('Try Again'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _filteredItems.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.description_outlined,
                                      size: 52,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      _searchController.text.isNotEmpty
                                          ? 'No matching ${widget.category.title} documents found'
                                          : 'No active ${widget.category.title} PDFs available yet',
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _searchController.text.isNotEmpty
                                          ? 'Try adjusting your search keywords.'
                                          : 'Generated active documents will be listed here automatically.',
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _fetchCategoryDocuments,
                              child: ListView.separated(
                                padding: const EdgeInsets.all(16),
                                itemCount: _filteredItems.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final item = _filteredItems[index];
                                  final isThisGenerating = _activeGeneratingId == item.id;

                                  return Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.03),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Top Row: Doc # and Status / Date
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: widget.category.color.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Icon(
                                                  widget.category.icon,
                                                  color: widget.category.color,
                                                  size: 20,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      item.docNumber,
                                                      style: const TextStyle(
                                                        fontFamily: 'Inter',
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 14,
                                                        color: Color(0xFF0F172A),
                                                      ),
                                                    ),
                                                    if (item.date != null) ...[
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        DateFormat('dd MMM yyyy, hh:mm a').format(item.date!),
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          color: Color(0xFF64748B),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                              if (item.amount != null) ...[
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.end,
                                                  children: [
                                                    Text(
                                                      '₹${currencyFormat.format(item.amount)}',
                                                      style: TextStyle(
                                                        fontFamily: 'Inter',
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 14,
                                                        color: widget.category.color,
                                                      ),
                                                    ),
                                                    if (item.status != null && item.status!.isNotEmpty) ...[
                                                      const SizedBox(height: 2),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFFDCFCE7),
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: Text(
                                                          item.status!.toUpperCase(),
                                                          style: const TextStyle(
                                                            fontSize: 9,
                                                            fontWeight: FontWeight.bold,
                                                            color: Color(0xFF166534),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ] else if (item.status != null && item.status!.isNotEmpty) ...[
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFEFF6FF),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    item.status!.toUpperCase(),
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: Color(0xFF1D4ED8),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                          const SizedBox(height: 10),

                                          // Middle Row: Customer and Product
                                          Row(
                                            children: [
                                              const Icon(Icons.person_outline, size: 15, color: Color(0xFF64748B)),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  item.customerName,
                                                  style: const TextStyle(
                                                    fontFamily: 'Inter',
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF334155),
                                                  ),
                                                ),
                                              ),
                                              if (item.customerPhone != null && item.customerPhone!.isNotEmpty) ...[
                                                Text(
                                                  item.customerPhone!,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Color(0xFF64748B),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          if (item.productName != null && item.productName!.isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                const Icon(Icons.inventory_2_outlined, size: 15, color: Color(0xFF64748B)),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    item.productName!,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Color(0xFF64748B),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                          const SizedBox(height: 12),

                                          // Bottom Row: Action Buttons
                                          if (isThisGenerating) ...[
                                            const Center(
                                              child: Padding(
                                                padding: EdgeInsets.symmetric(vertical: 6),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    SizedBox(
                                                      width: 16,
                                                      height: 16,
                                                      child: CircularProgressIndicator(strokeWidth: 2),
                                                    ),
                                                    SizedBox(width: 10),
                                                    Text(
                                                      'Generating PDF...',
                                                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ] else ...[
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: ElevatedButton.icon(
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: const Color(0xFF1E293B),
                                                      foregroundColor: Colors.white,
                                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      elevation: 0,
                                                    ),
                                                    icon: const Icon(Icons.visibility_outlined, size: 16),
                                                    label: const Text(
                                                      'Preview PDF',
                                                      style: TextStyle(
                                                        fontFamily: 'Inter',
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                    onPressed: () => _handlePreview(item),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                IconButton(
                                                  style: IconButton.styleFrom(
                                                    backgroundColor: const Color(0xFFF1F5F9),
                                                    padding: const EdgeInsets.all(8),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  ),
                                                  icon: const Icon(Icons.file_download_outlined, size: 18, color: Color(0xFF0F172A)),
                                                  tooltip: 'Download PDF',
                                                  onPressed: () => _handleDownload(item),
                                                ),
                                                const SizedBox(width: 6),
                                                IconButton(
                                                  style: IconButton.styleFrom(
                                                    backgroundColor: const Color(0xFFF1F5F9),
                                                    padding: const EdgeInsets.all(8),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  ),
                                                  icon: const Icon(Icons.print_outlined, size: 18, color: Color(0xFF0F172A)),
                                                  tooltip: 'Print PDF',
                                                  onPressed: () => _handlePrint(item),
                                                ),
                                                const SizedBox(width: 6),
                                                IconButton(
                                                  style: IconButton.styleFrom(
                                                    backgroundColor: const Color(0xFFF1F5F9),
                                                    padding: const EdgeInsets.all(8),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  ),
                                                  icon: const Icon(Icons.share_outlined, size: 18, color: Color(0xFF0F172A)),
                                                  tooltip: 'Share PDF',
                                                  onPressed: () => _handleShare(item),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
