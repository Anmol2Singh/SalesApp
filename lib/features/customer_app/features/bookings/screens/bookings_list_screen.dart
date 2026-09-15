import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:salesapp/features/customer_app/core/theme/app_theme.dart';
import 'package:salesapp/features/customer_app/data/models/data_models.dart';
import 'package:salesapp/features/customer_app/data/providers/app_providers.dart';
import 'package:salesapp/features/customer_app/shared/widgets/glass_card.dart';
import 'package:salesapp/features/customer_app/shared/widgets/status_chip.dart';
import 'package:salesapp/features/customer_app/shared/widgets/toast_service.dart';
import 'package:salesapp/features/customer_app/features/service_request/screens/service_booking_flow.dart';
import 'package:salesapp/features/complaints/data/models/complaint_part_order.dart';
import 'package:salesapp/features/complaints/data/models/complaint_model.dart';
import 'package:salesapp/features/complaints/providers/part_orders_provider.dart';
import 'package:salesapp/features/complaints/services/complaint_pdf_service.dart';
import 'package:salesapp/core/widgets/pdf_preview_screen.dart';

class BookingsListScreen extends ConsumerWidget {
  const BookingsListScreen({super.key});

  void _openBookingFlow(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ServiceBookingFlow(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(serviceRequestsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? AppColors.bgPrimary : AppColors.bgPrimaryLight;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subtitleColor = isDark ? AppColors.textSecondary : AppColors.textSecondaryLight;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: Text(
          'My Complaints',
          style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
        ),
        backgroundColor: scaffoldBg,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openBookingFlow(context),
        backgroundColor: AppColors.primary,
        elevation: 6,
        icon: const Icon(Icons.add, color: Colors.white, size: 22),
        label: const Text(
          'Book Complaint',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.accent,
        onRefresh: () async {
          ref.invalidate(serviceRequestsProvider);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: requestsAsync.when(
            data: (requests) {
              if (requests.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 120),
                    Center(
                      child: Column(
                        children: [
                          Icon(Icons.assignment_outlined, size: 64, color: subtitleColor),
                          const SizedBox(height: 16),
                          Text(
                            'No complaints yet',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap + Book Complaint to register a service request',
                            style: TextStyle(color: subtitleColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }

              // Closed / resolved complaints move to Service History
              final upcoming = requests.where((r) {
                final s = r.status.toLowerCase();
                return s != 'completed' && s != 'cancelled' && s != 'closed' && s != 'resolved';
              }).toList();

              final past = requests.where((r) {
                final s = r.status.toLowerCase();
                return s == 'completed' || s == 'cancelled' || s == 'closed' || s == 'resolved';
              }).toList();

              return DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.bgSecondary : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? AppColors.borderColor : AppColors.borderColorLight,
                        ),
                      ),
                      child: TabBar(
                        indicatorColor: isDark ? AppColors.accent : AppColors.primary,
                        labelColor: isDark ? AppColors.accent : AppColors.primary,
                        unselectedLabelColor: subtitleColor,
                        tabs: [
                          Tab(text: 'Active Visits (${upcoming.length})'),
                          Tab(text: 'Service History (${past.length})'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildRequestList(context, ref, upcoming, isUpcoming: true),
                          _buildRequestList(context, ref, past, isUpcoming: false),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
            error: (err, _) => Center(child: Text('Error: $err', style: TextStyle(color: textColor))),
          ),
        ),
      ),
    );
  }

  Widget _buildRequestList(
    BuildContext context,
    WidgetRef ref,
    List<ServiceRequest> list, {
    required bool isUpcoming,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subtitleColor = isDark ? AppColors.textSecondary : AppColors.textSecondaryLight;

    if (list.isEmpty) {
      return Center(
        child: Text(
          isUpcoming
              ? 'No active service appointments.'
              : 'No completed service requests in history.',
          style: TextStyle(color: subtitleColor),
        ),
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      itemCount: list.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final req = list[index];
        final isClosed = !isUpcoming;

        IconData icon = Icons.handyman_outlined;
        Color color = AppColors.accent;

        if (req.issueCategory.toLowerCase().contains('leak')) {
          icon = Icons.opacity;
          color = AppColors.danger;
        } else if (req.issueCategory.toLowerCase().contains('heating')) {
          icon = Icons.thermostat;
          color = AppColors.warning;
        }

        return InkWell(
          onTap: () => _showComplaintDetailSheet(context, ref, req),
          borderRadius: BorderRadius.circular(18),
          child: GlassCard(
            padding: const EdgeInsets.all(16),
            borderRadius: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(icon, color: color, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              req.productId.isNotEmpty ? req.productId : req.issueCategory,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: textColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusChip(
                      label: req.status.toUpperCase(),
                      status: _getStatusType(req.status),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Problem Code and Registered By Chip (Flexible with NO OVERFLOW)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        req.problemCode,
                        style: TextStyle(
                          fontSize: 12,
                          color: subtitleColor,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (req.registeredBy != null && req.registeredBy!.isNotEmpty)
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.25)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.person_pin_outlined, size: 12, color: Color(0xFF6366F1)),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  req.registeredBy == 'Customer App' ? 'Self Registered' : 'Company Staff Registered',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF6366F1),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Scheduled Date & Time
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 14, color: subtitleColor),
                        const SizedBox(width: 6),
                        Text(
                          DateFormat('dd MMM yyyy').format(req.scheduledDate),
                          style: TextStyle(fontSize: 13, color: textColor),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 14, color: subtitleColor),
                        const SizedBox(width: 6),
                        Text(
                          req.timeSlot,
                          style: TextStyle(fontSize: 13, color: textColor),
                        ),
                      ],
                    ),
                  ],
                ),
                Divider(
                  color: isDark ? AppColors.borderColor : AppColors.borderColorLight,
                  height: 24,
                ),

                // Address Row
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 14, color: subtitleColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        (req.customerAddress['street'] != null && req.customerAddress['street'].toString().isNotEmpty)
                            ? req.customerAddress['street'].toString()
                            : ((req.customerAddress['flat'] != null && req.customerAddress['flat'].toString().isNotEmpty)
                                ? '${req.customerAddress['flat']}, ${req.customerAddress['street'] ?? ""}'
                                : (req.customerAddress['address'] ?? 'Installation Site')),
                        style: TextStyle(fontSize: 12, color: subtitleColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                // Technician contact actions
                if (req.technicianName != null && req.technicianName!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Divider(color: isDark ? AppColors.borderColor : AppColors.borderColorLight, height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.primary.withOpacity(0.15),
                        child: const Icon(Icons.person, size: 18, color: AppColors.primary),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Technician', style: TextStyle(fontSize: 10, color: subtitleColor)),
                            Text(
                              req.technicianName!,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
                            ),
                            if (req.technicianPhone != null && req.technicianPhone!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  req.technicianPhone!,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: subtitleColor,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (req.technicianPhone != null && req.technicianPhone!.isNotEmpty)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          icon: const Icon(Icons.phone, size: 14),
                          label: const Text('Call', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: () => _launchCaller(req.technicianPhone!),
                        ),
                    ],
                  ),
                ] else if (isUpcoming && req.status != 'cancelled') ...[
                  const SizedBox(height: 12),
                  Divider(color: isDark ? AppColors.borderColor : AppColors.borderColorLight, height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.schedule, color: AppColors.warning, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Technician will be allotted shortly',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                // If closed/completed: prominent completion report button
                if (isClosed) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF6D28D9),
                        side: const BorderSide(color: Color(0xFF6D28D9), width: 1.2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                      label: const Text(
                        'View Completion Report PDF',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      onPressed: () => _viewCompletionReportPdf(context, req),
                    ),
                  ),
                ],

                // Customer Defected Parts & Payment Card
                _buildCustomerPartOrdersCard(context, ref, req, isDark, textColor, subtitleColor),
              ],
            ),
          ),
        );
      },
    );
  }

  void _launchCaller(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _viewCompletionReportPdf(BuildContext context, ServiceRequest req) async {
    bool isDialogShowing = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    ).then((_) => isDialogShowing = false);

    try {
      final res = await Supabase.instance.client
          .from('complaints')
          .select()
          .eq('id', req.requestId)
          .maybeSingle();

      Complaint complaint;
      if (res != null) {
        complaint = Complaint.fromJson(res);
      } else {
        complaint = Complaint(
          id: req.requestId,
          ticketNumber: req.problemCode,
          customerId: req.customerId,
          customerName: 'Customer',
          customerPhone: '',
          customerAddress: req.customerAddress['street']?.toString() ?? 'Site Address',
          productName: req.productId,
          hasActiveAmc: req.amcStatus.contains('Active'),
          priority: 'Standard',
          title: req.issueCategory,
          description: req.issueDescription,
          status: req.status,
          tatRemaining: '0h',
          technicianName: req.technicianName,
          createdAt: req.createdAt,
        );
      }

      final pdfBytes = await ComplaintPdfService.generateCompletionReportPdf(complaint);

      if (isDialogShowing && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        isDialogShowing = false;
      }

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PdfPreviewScreen(
              pdfBytes: pdfBytes,
              fileName: 'CompletionReport_${complaint.ticketNumber.replaceAll(RegExp(r'[/\\?%*:|<>]'), "_")}.pdf',
            ),
          ),
        );
      }
    } catch (e) {
      if (isDialogShowing && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        isDialogShowing = false;
      }
      if (context.mounted) {
        ToastService.show(context, 'Failed to generate PDF: $e', type: ToastType.error);
      }
    }
  }

  void _showComplaintDetailSheet(BuildContext context, WidgetRef ref, ServiceRequest req) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subtitleColor = isDark ? AppColors.textSecondary : AppColors.textSecondaryLight;
    final isClosed = req.status == 'completed' || req.status == 'closed' || req.status == 'resolved' || req.status == 'cancelled';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.bgSecondary : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              req.problemCode,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Booked on ${DateFormat('dd MMM yyyy, hh:mm a').format(req.createdAt)}',
                              style: TextStyle(fontSize: 12, color: subtitleColor),
                            ),
                          ],
                        ),
                      ),
                      StatusChip(label: req.status.toUpperCase(), status: _getStatusType(req.status)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(color: isDark ? AppColors.borderColor : AppColors.borderColorLight),
                  const SizedBox(height: 12),

                  // Equipment & Error details
                  _detailSection(
                    title: 'PRODUCT & ISSUE DETAILS',
                    children: [
                      _detailRow('Product Name', req.productId, textColor, subtitleColor),
                      _detailRow('Issue Category', req.issueCategory, textColor, subtitleColor),
                      _detailRow('AMC / Warranty', req.amcStatus, textColor, subtitleColor),
                      _detailRow('Scheduled Slot', '${DateFormat('dd MMM yyyy').format(req.scheduledDate)} • ${req.timeSlot}', textColor, subtitleColor),
                      const SizedBox(height: 8),
                      Text('Issue Description:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: subtitleColor)),
                      const SizedBox(height: 4),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          req.issueDescription.isNotEmpty ? req.issueDescription : 'No description provided.',
                          style: TextStyle(fontSize: 13, color: textColor),
                        ),
                      ),
                    ],
                  ),

                  // Photos Section
                  if (req.photoUrls.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Text('ATTACHED PHOTOS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: subtitleColor, letterSpacing: 0.5)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: req.photoUrls.length,
                        itemBuilder: (context, idx) {
                          final pUrl = req.photoUrls[idx];
                          return GestureDetector(
                            onTap: () => _zoomImage(context, pUrl),
                            child: Container(
                              width: 100,
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: pUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                  errorWidget: (_, __, ___) => const Icon(Icons.broken_image, size: 32),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  // Technician Section
                  const SizedBox(height: 18),
                  Text('ASSIGNED TECHNICIAN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: subtitleColor, letterSpacing: 0.5)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? AppColors.borderColor : AppColors.borderColorLight),
                    ),
                    child: req.technicianName != null && req.technicianName!.isNotEmpty
                        ? Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: AppColors.primary.withOpacity(0.2),
                                child: const Icon(Icons.engineering, color: AppColors.primary),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      req.technicianName!,
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor),
                                    ),
                                    Text(
                                      (req.technicianPhone != null && req.technicianPhone!.isNotEmpty)
                                          ? req.technicianPhone!
                                          : 'Field Engineer',
                                      style: TextStyle(fontSize: 12, color: subtitleColor),
                                    ),
                                  ],
                                ),
                              ),
                              if (req.technicianPhone != null && req.technicianPhone!.isNotEmpty)
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: const Icon(Icons.phone, size: 16),
                                  label: const Text('Call'),
                                  onPressed: () => _launchCaller(req.technicianPhone!),
                                ),
                            ],
                          )
                        : Row(
                            children: [
                              const Icon(Icons.schedule, color: AppColors.warning, size: 20),
                              const SizedBox(width: 10),
                              Text(
                                'Technician will be assigned by company coordinator shortly.',
                                style: TextStyle(fontSize: 12, color: subtitleColor),
                              ),
                            ],
                          ),
                  ),

                  // Service Completion Report button
                  if (isClosed) ...[
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6D28D9),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: const Text(
                          'Download Service Completion Report PDF',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _viewCompletionReportPdf(context, req);
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 30),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _zoomImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black.withOpacity(0.9),
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailSection({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _detailRow(String label, String value, Color textColor, Color subtitleColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12.5, color: subtitleColor)),
          Flexible(
            child: Text(
              value,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textColor),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusType(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'closed':
      case 'resolved':
        return 'success';
      case 'in_progress':
      case 'assigned':
      case 'confirmed':
        return 'warning';
      case 'cancelled':
        return 'danger';
      case 'pending':
      default:
        return 'info';
    }
  }

  Widget _buildCustomerPartOrdersCard(
    BuildContext context,
    WidgetRef ref,
    ServiceRequest req,
    bool isDark,
    Color textColor,
    Color subtitleColor,
  ) {
    final partOrdersAsync = ref.watch(partOrdersForComplaintProvider(req.requestId));

    return partOrdersAsync.when(
      data: (orders) {
        if (orders.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Divider(color: isDark ? AppColors.borderColor : AppColors.borderColorLight, height: 1),
            const SizedBox(height: 12),
            ...orders.map((ord) {
              final isPending = ord.paymentStatus == 'pending' && ord.totalAmount > 0;
              final isPaid = ord.paymentStatus == 'paid';
              final isFree = ord.paymentStatus == 'not_required' || ord.isWarranty;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isPending
                        ? Colors.orange.shade400
                        : (isPaid || isFree ? Colors.green.shade400 : Colors.grey.shade300),
                    width: isPending ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.handyman_outlined,
                              size: 16,
                              color: isDark ? AppColors.accent : AppColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Replacement Parts',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (isPaid || isFree
                                    ? Colors.green
                                    : (isPending ? Colors.orange : Colors.grey))
                                .withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isPaid
                                ? 'Paid ✓'
                                : (isFree ? 'Under Warranty' : 'Payment Due'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isPaid || isFree
                                  ? Colors.green
                                  : (isPending ? Colors.orange.shade800 : Colors.grey),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...ord.items.map((item) {
                      final inWar = (item['is_warranty'] as bool?) ?? false;
                      final price = (item['total_price'] as num?)?.toDouble() ?? 0.0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${item['item_name']} (Qty: ${item['quantity']})',
                                style: TextStyle(fontSize: 12, color: textColor),
                              ),
                            ),
                            Text(
                              inWar ? '₹0 (Warranty)' : '₹${price.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: inWar ? Colors.green : textColor,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    Divider(color: isDark ? AppColors.borderColor : Colors.grey.shade300, height: 1),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Amount:', style: TextStyle(fontSize: 12, color: subtitleColor)),
                        Text(
                          ord.totalAmount <= 0 ? '₹0.00' : '₹${ord.totalAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                    if (isPending) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          icon: const Icon(Icons.payment, size: 16),
                          label: Text(
                            'Pay Now (₹${ord.totalAmount.toStringAsFixed(2)})',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          onPressed: () => _showCustomerPaymentSheet(context, ref, ord, req),
                        ),
                      ),
                    ],
                    if (isPaid) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            'Parts approved & recorded for replacement',
                            style: TextStyle(fontSize: 11, color: Colors.green.shade700, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  void _showCustomerPaymentSheet(
    BuildContext context,
    WidgetRef ref,
    ComplaintPartOrder order,
    ServiceRequest req,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        bool isPaying = false;
        String selectedMethod = 'UPI';

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Pay for Replacement Parts',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        ...order.items.map((item) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('${item['item_name']} (x${item['quantity']})', style: const TextStyle(fontSize: 13)),
                                  Text('₹${(item['total_price'] as num?)?.toStringAsFixed(2) ?? "0.00"}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                ],
                              ),
                            )),
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Grand Total to Pay', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            Text('₹${order.totalAmount.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF10B981))),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Select Payment Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  RadioListTile<String>(
                    value: 'UPI',
                    groupValue: selectedMethod,
                    title: const Text('UPI (Google Pay, PhonePe, Paytm)'),
                    secondary: const Icon(Icons.qr_code, color: Colors.purple),
                    onChanged: (v) => setModalState(() => selectedMethod = v!),
                  ),
                  RadioListTile<String>(
                    value: 'CARD',
                    groupValue: selectedMethod,
                    title: const Text('Debit / Credit Card'),
                    secondary: const Icon(Icons.credit_card, color: Colors.blue),
                    onChanged: (v) => setModalState(() => selectedMethod = v!),
                  ),
                  RadioListTile<String>(
                    value: 'NETBANKING',
                    groupValue: selectedMethod,
                    title: const Text('Net Banking'),
                    secondary: const Icon(Icons.account_balance, color: Colors.indigo),
                    onChanged: (v) => setModalState(() => selectedMethod = v!),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: isPaying
                          ? null
                          : () async {
                              setModalState(() => isPaying = true);
                              try {
                                final paymentRef = 'PAY_${DateTime.now().millisecondsSinceEpoch}';
                                await ref.read(partOrdersServiceProvider).markOrderPaid(
                                  orderId: order.id,
                                  complaintId: req.requestId,
                                  paymentRef: paymentRef,
                                  items: order.items,
                                );
                                if (ctx.mounted) {
                                  Navigator.pop(ctx);
                                  ToastService.show(
                                    context,
                                    'Payment of ₹${order.totalAmount.toStringAsFixed(2)} Successful! Replacement recorded.',
                                    type: ToastType.success,
                                  );
                                }
                              } catch (e) {
                                if (ctx.mounted) {
                                  ToastService.show(context, 'Payment failed: $e', type: ToastType.error);
                                }
                              } finally {
                                if (ctx.mounted) setModalState(() => isPaying = false);
                              }
                            },
                      child: isPaying
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text('Confirm & Pay ₹${order.totalAmount.toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
