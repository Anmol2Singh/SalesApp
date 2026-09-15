import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:salesapp/core/providers/supabase_provider.dart';
import 'package:salesapp/features/customer_app/core/theme/app_theme.dart';
import 'package:salesapp/features/customer_app/shared/widgets/glass_card.dart';
import 'package:salesapp/features/customer_app/data/providers/app_providers.dart';
import 'package:salesapp/features/customer_app/data/models/data_models.dart';

class AmcAvailScreen extends ConsumerStatefulWidget {
  const AmcAvailScreen({super.key});

  @override
  ConsumerState<AmcAvailScreen> createState() => _AmcAvailScreenState();
}

class _AmcAvailScreenState extends ConsumerState<AmcAvailScreen> {
  String? _selectedProductId;
  String? _selectedProductName;
  int _durationYears = 1;
  int _visitsPerYear = 2; // 2 or 4
  DateTime _startDate = DateTime.now();
  late DateTime _endDate;
  final TextEditingController _notesController = TextEditingController();
  bool _isProcessingPayment = false;
  bool _isSubmitting = false;

  final List<Map<String, dynamic>> _standardCatalog = [
    {'id': 'prod_solar_200l', 'name': 'IZYHEAT Solar Water Heater 200L', 'model': 'IZY-SWH-200'},
    {'id': 'prod_heatpump_300l', 'name': 'IZYHEAT Commercial Heat Pump 300L', 'model': 'IZY-HP-300'},
    {'id': 'prod_hybrid_500l', 'name': 'IZYHEAT Hybrid Solar Boiler 500L', 'model': 'IZY-BOIL-500'},
    {'id': 'prod_solar_inverter', 'name': 'IZYHEAT Smart Solar Inverter 5kVA', 'model': 'IZY-INV-5K'},
  ];

  @override
  void initState() {
    super.initState();
    _recalculateEndDate();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _recalculateEndDate() {
    _endDate = DateTime(
      _startDate.year + _durationYears,
      _startDate.month,
      _startDate.day,
    );
  }

  int get _ratePerYear => _visitsPerYear == 2 ? 4999 : 8999;
  int get _totalAmount => _ratePerYear * _durationYears;
  int get _totalVisits => _visitsPerYear * _durationYears;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? AppColors.bgPrimary : AppColors.bgPrimaryLight;
    final cardBg = isDark ? AppColors.bgSecondary : Colors.white;
    final borderCol = isDark ? AppColors.borderColor : AppColors.borderColorLight;
    final textPrimary = isDark ? Colors.white : AppColors.textPrimaryLight;
    final textSecondary = isDark ? AppColors.textSecondary : AppColors.textSecondaryLight;
    final dateFormat = DateFormat('dd MMM yyyy');

    final productsAsync = ref.watch(productsProvider);
    final userPurchasedProducts = productsAsync.value ?? [];

    // Pre-select first product if not yet selected
    if (_selectedProductId == null) {
      if (userPurchasedProducts.isNotEmpty) {
        _selectedProductId = userPurchasedProducts.first.productId;
        _selectedProductName = userPurchasedProducts.first.productName;
      } else {
        _selectedProductId = _standardCatalog.first['id'];
        _selectedProductName = _standardCatalog.first['name'];
      }
    }

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0.5,
        foregroundColor: textPrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Avail Annual Maintenance (AMC)',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Hero Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.85),
                    const Color(0xFF6D28D9),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.25),
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
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.verified_user, color: Colors.white, size: 32),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'IZYHEAT Care Protection',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Enjoy worry-free performance with certified preventative visits and free complaint servicing.',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 1. Product Selection
            Text(
              '1. Select Covered Product',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderCol),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedProductId,
                  isExpanded: true,
                  dropdownColor: cardBg,
                  icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                  items: [
                    if (userPurchasedProducts.isNotEmpty)
                      ...userPurchasedProducts.map((p) => DropdownMenuItem(
                            value: p.productId,
                            child: Text(
                              '${p.productName} (${p.modelNumber.isNotEmpty ? p.modelNumber : 'Registered System'})',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                color: textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ))
                    else
                      ..._standardCatalog.map((c) => DropdownMenuItem(
                            value: c['id'] as String,
                            child: Text(
                              '${c['name']} (${c['model']})',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                color: textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          )),
                  ],
                  onChanged: (val) {
                    if (val == null) return;
                    setState(() {
                      _selectedProductId = val;
                      if (userPurchasedProducts.isNotEmpty) {
                        final match = userPurchasedProducts.where((p) => p.productId == val).firstOrNull;
                        _selectedProductName = match?.productName ?? val;
                      } else {
                        final match = _standardCatalog.where((c) => c['id'] == val).firstOrNull;
                        _selectedProductName = match?['name'] as String? ?? val;
                      }
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 2. Contract Duration
            Text(
              '2. AMC Duration (Years)',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [1, 2, 3, 5].map((years) {
                final isSelected = _durationYears == years;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _durationYears = years;
                          _recalculateEndDate();
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : cardBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : borderCol,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$years ${years == 1 ? 'Year' : 'Years'}',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected ? Colors.white : textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // 3. Maintenance Visits per Year
            Text(
              '3. Preventive Visits Frequency',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildFrequencyCard(
                    title: 'Standard',
                    visits: 2,
                    pricePerYr: 4999,
                    isSelected: _visitsPerYear == 2,
                    onTap: () => setState(() => _visitsPerYear = 2),
                    cardBg: cardBg,
                    borderCol: borderCol,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildFrequencyCard(
                    title: 'Comprehensive',
                    visits: 4,
                    pricePerYr: 8999,
                    isPopular: true,
                    isSelected: _visitsPerYear == 4,
                    onTap: () => setState(() => _visitsPerYear = 4),
                    cardBg: cardBg,
                    borderCol: borderCol,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 4. Contract Schedule Dates
            Text(
              '4. Contract Coverage Dates',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _startDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 30)),
                        lastDate: DateTime.now().add(const Duration(days: 90)),
                      );
                      if (picked != null) {
                        setState(() {
                          _startDate = picked;
                          _recalculateEndDate();
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderCol),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Start Date', style: TextStyle(fontSize: 11, color: textSecondary)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 14, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Text(
                                dateFormat.format(_startDate),
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textPrimary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderCol),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('End Date (Auto)', style: TextStyle(fontSize: 11, color: textSecondary)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.event_available, size: 14, color: Colors.green),
                            const SizedBox(width: 6),
                            Text(
                              dateFormat.format(_endDate),
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textPrimary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 5. Pricing Summary Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Computed Plan',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$_totalVisits Visits Included',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            color: Colors.green,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  _buildSummaryRow('Base Plan Rate', '₹$_ratePerYear / year', textSecondary, textPrimary),
                  const SizedBox(height: 6),
                  _buildSummaryRow('Contract Term', '$_durationYears ${_durationYears == 1 ? 'Year' : 'Years'}', textSecondary, textPrimary),
                  const SizedBox(height: 6),
                  _buildSummaryRow('Preventive Visits', '$_totalVisits Free Service Visits', textSecondary, textPrimary),
                  const SizedBox(height: 6),
                  _buildSummaryRow('Spare Parts Discount', '15% Off all replacement parts', textSecondary, Colors.green),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Payable',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      Text(
                        '₹${NumberFormat('#,##,###').format(_totalAmount)}',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Submit / Pay Button
            ElevatedButton(
              onPressed: _isSubmitting ? null : _handleAvailAmcSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      'Pay & Avail AMC (₹${NumberFormat('#,##,###').format(_totalAmount)})',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                '🔒 256-bit Encrypted Mock Payment Gateway • Instant Activation Request',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildFrequencyCard({
    required String title,
    required int visits,
    required int pricePerYr,
    bool isPopular = false,
    required bool isSelected,
    required VoidCallback onTap,
    required Color cardBg,
    required Color borderCol,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : borderCol,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? AppColors.primary : textPrimary,
                  ),
                ),
                if (isPopular)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'POPULAR',
                      style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '$visits Visits / Yr',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '₹$pricePerYr/yr',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, Color labelColor, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: labelColor)),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: valueColor)),
      ],
    );
  }

  Future<void> _handleAvailAmcSubmit() async {
    // Show Payment Simulation Modal
    final didPay = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PaymentSimulationSheet(
        amount: _totalAmount,
        productName: _selectedProductName ?? 'IZYHEAT System',
      ),
    );

    if (didPay != true) return;

    // Proceed to create AMC contract in Supabase
    setState(() => _isSubmitting = true);
    try {
      final supabase = ref.read(supabaseClientProvider);
      final currentUserId = supabase.auth.currentUser?.id ?? 'mock-customer';

      // 1. Resolve customer ID
      String customerId = currentUserId;
      try {
        final custMatch = await supabase
            .from('customers')
            .select('id, customer_name, company_name')
            .or('created_by.eq.$currentUserId,id.eq.$currentUserId')
            .limit(1)
            .maybeSingle();
        if (custMatch != null && custMatch['id'] != null) {
          customerId = custMatch['id'] as String;
        }
      } catch (_) {}

      final txnId = 'TXN_${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
      final amcNumber = 'AMC/${DateTime.now().year}/${Random().nextInt(9000) + 1000}';

      // 2. Insert into amc_contracts table with status: pending_setup
      final contractData = {
        'customer_id': customerId,
        'product_id': _selectedProductId ?? '',
        'amc_number': amcNumber,
        'status': 'pending_setup',
        'start_date': _startDate.toIso8601String().split('T').first,
        'end_date': _endDate.toIso8601String().split('T').first,
        'contract_amount': _totalAmount.toDouble(),
        'number_of_visits_included': _totalVisits,
        'terms_text': 'Avail AMC submitted online by customer. Transaction: $txnId. Duration: $_durationYears yr ($_totalVisits visits).',
        'created_by': currentUserId,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      try {
        await supabase.from('amc_contracts').insert(contractData);
      } catch (e) {
        debugPrint('Direct amc_contracts insert error, trying fallback: $e');
        // Fallback without generated amc_number if trigger exists
        contractData.remove('amc_number');
        await supabase.from('amc_contracts').insert(contractData);
      }

      // 3. Notify Admin & Service Staff
      try {
        final staffResponse = await supabase
            .from('profiles')
            .select('id, roles, role');
        final staffToNotify = <String>{};
        for (final s in (staffResponse as List? ?? [])) {
          final role = (s['role'] as String? ?? '').toLowerCase();
          final rolesList = (s['roles'] is List) ? (s['roles'] as List).map((e) => e.toString().toLowerCase()).toList() : [];
          if (role == 'admin' || role == 'manager' || role == 'sales_head' || role == 'service_head' ||
              rolesList.contains('admin') || rolesList.contains('manager') || rolesList.contains('service_head')) {
            if (s['id'] != null) staffToNotify.add(s['id'] as String);
          }
        }
        for (final sid in staffToNotify) {
          await supabase.from('notifications').insert({
            'user_id': sid,
            'title': 'New AMC Contract Booking 🛡️',
            'body': 'Customer booked $_durationYears-Year AMC for $_selectedProductName ($amcNumber) - ₹$_totalAmount. Please review and activate.',
            'type': 'amc_contract_booking',
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      } catch (_) {}

      // 4. Log to customer activity
      try {
        await supabase.from('activity_log').insert({
          'customer_id': customerId,
          'event_type': 'amc_contract_created',
          'title': 'AMC Contract Booked: $amcNumber',
          'body': 'You have successfully booked AMC for $_durationYears year(s). Pending admin setup & activation.',
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {}

      ref.invalidate(activityLogsProvider);

      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'AMC Booked Successfully!',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your AMC contract request has been created with number:'),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    amcNumber,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ),
                const SizedBox(height: 12),
                Text('• Duration: $_durationYears Year(s) ($_totalVisits visits)'),
                Text('• Amount Paid: ₹${NumberFormat('#,##,###').format(_totalAmount)}'),
                Text('• Status: Pending Admin Setup (Will be active shortly)'),
              ],
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  context.pop();
                },
                child: const Text('Back to Home'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to book AMC: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

class _PaymentSimulationSheet extends StatefulWidget {
  final int amount;
  final String productName;

  const _PaymentSimulationSheet({
    required this.amount,
    required this.productName,
  });

  @override
  State<_PaymentSimulationSheet> createState() => _PaymentSimulationSheetState();
}

class _PaymentSimulationSheetState extends State<_PaymentSimulationSheet> {
  String _selectedPaymentMethod = 'UPI';
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final formattedAmount = NumberFormat('#,##,###').format(widget.amount);

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.payment, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Checkout & Payment',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimaryLight,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: () => Navigator.pop(context, false),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.productName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 2),
                      const Text('Annual Maintenance Contract', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
                Text(
                  '₹$formattedAmount',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('Select Payment Method', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          _buildMethodOption('UPI', 'Google Pay, PhonePe, Paytm, UPI ID', Icons.qr_code_scanner),
          const SizedBox(height: 6),
          _buildMethodOption('Card', 'Credit or Debit Card', Icons.credit_card),
          const SizedBox(height: 6),
          _buildMethodOption('NetBanking', 'HDFC, SBI, ICICI, Axis & more', Icons.account_balance),
          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: _isProcessing
                ? null
                : () async {
                    setState(() => _isProcessing = true);
                    await Future.delayed(const Duration(milliseconds: 1400));
                    if (mounted) {
                      Navigator.pop(context, true);
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isProcessing
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                      SizedBox(width: 12),
                      Text('Authorizing Payment...', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  )
                : Text(
                    'Simulate Successful Payment (₹$formattedAmount)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodOption(String id, String subtitle, IconData icon) {
    final isSelected = _selectedPaymentMethod == id;
    return InkWell(
      onTap: () => setState(() => _selectedPaymentMethod = id),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.06) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppColors.primary : Colors.grey, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(id, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isSelected ? AppColors.primary : Colors.black87)),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
            Radio<String>(
              value: id,
              groupValue: _selectedPaymentMethod,
              activeColor: AppColors.primary,
              onChanged: (val) => setState(() => _selectedPaymentMethod = val!),
            ),
          ],
        ),
      ),
    );
  }
}
