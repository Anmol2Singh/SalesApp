import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/pm_tokens.dart';
import 'pm_badge.dart';
import 'pm_button.dart';
import 'pm_card.dart';

class PmDirectoryTable extends StatefulWidget {
  final List<dynamic> records;
  final bool isPurchase;
  final Function(List<String> ids)? onBulkDelete;
  final VoidCallback? onRefresh;

  const PmDirectoryTable({
    super.key,
    required this.records,
    required this.isPurchase,
    this.onBulkDelete,
    this.onRefresh,
  });

  @override
  State<PmDirectoryTable> createState() => _PmDirectoryTableState();
}

class _PmDirectoryTableState extends State<PmDirectoryTable> {
  static const String _columnsPrefsKey = 'pm_directory_visible_columns_v2';
  final Set<String> _selectedIds = {};
  String _sortField = 'id_no';
  bool _sortAsc = false;
  final _currencyFormat = NumberFormat('#,##,##0', 'en_IN');
  final _dateFormat = DateFormat('dd-MM-yyyy');

  final Set<String> _visibleColumns = {
    'type',
    'party_name',
    'mobile',
    'address',
    'order_value',
    'extra_work',
    'payment_recd',
    'balance',
    'reminder_date',
  };

  @override
  void initState() {
    super.initState();
    _loadSavedColumns();
  }

  Future<void> _loadSavedColumns() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${_columnsPrefsKey}_${widget.isPurchase ? "purchase" : "sales"}';
      final saved = prefs.getStringList(key);
      if (saved != null && saved.isNotEmpty) {
        if (mounted) {
          setState(() {
            _visibleColumns.clear();
            _visibleColumns.addAll(saved);
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _saveSavedColumns() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${_columnsPrefsKey}_${widget.isPurchase ? "purchase" : "sales"}';
      await prefs.setStringList(key, _visibleColumns.toList());
    } catch (_) {}
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedIds.length == widget.records.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.clear();
        for (final r in widget.records) {
          _selectedIds.add(r.id);
        }
      }
    });
  }

  void _setSort(String field) {
    setState(() {
      if (_sortField == field) {
        _sortAsc = !_sortAsc;
      } else {
        _sortField = field;
        _sortAsc = true;
      }
    });
  }

  List<dynamic> get _sortedRecords {
    final list = List<dynamic>.from(widget.records);
    list.sort((a, b) {
      int cmp = 0;
      if (_sortField == 'id_no') {
        cmp = a.idNo.compareTo(b.idNo);
      } else if (_sortField == 'site_name') {
        cmp = a.siteName.toLowerCase().compareTo(b.siteName.toLowerCase());
      } else if (_sortField == 'order_value') {
        cmp = a.orderValue.compareTo(b.orderValue);
      } else if (_sortField == 'balance') {
        cmp = a.balance.compareTo(b.balance);
      }
      return _sortAsc ? cmp : -cmp;
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final pm = context.pm;
    final sorted = _sortedRecords;

    if (sorted.isEmpty) {
      return PmCard(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.inbox, size: 48, color: pm.mutedForeground.withOpacity(0.5)),
              const SizedBox(height: 12),
              Text(
                'No records match your criteria.',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: pm.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 800) {
          return _buildDesktopTable(pm, sorted);
        }
        return _buildMobileCards(pm, sorted);
      },
    );
  }

  Widget _buildDesktopTable(PmTokens pm, List<dynamic> sorted) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate dynamic column spacing based on visible columns and available width
        int colCount = 4; // Checkbox, ID, SiteName, Action
        double estimatedContentWidth = 360.0; // base for 4 mandatory columns

        if (_visibleColumns.contains('type')) { colCount++; estimatedContentWidth += 90.0; }
        if (_visibleColumns.contains('party_name')) { colCount++; estimatedContentWidth += 140.0; }
        if (_visibleColumns.contains('mobile')) { colCount++; estimatedContentWidth += 100.0; }
        if (_visibleColumns.contains('address')) { colCount++; estimatedContentWidth += 140.0; }
        if (_visibleColumns.contains('order_value')) { colCount++; estimatedContentWidth += 100.0; }
        if (!widget.isPurchase && _visibleColumns.contains('extra_work')) { colCount++; estimatedContentWidth += 90.0; }
        if (_visibleColumns.contains('payment_recd')) { colCount++; estimatedContentWidth += 100.0; }
        if (_visibleColumns.contains('balance')) { colCount++; estimatedContentWidth += 100.0; }
        if (_visibleColumns.contains('reminder_date')) { colCount++; estimatedContentWidth += 100.0; }

        final gaps = colCount > 1 ? colCount - 1 : 1;
        const baseSpacing = 16.0;
        double dynamicSpacing = baseSpacing;

        // If card width is larger than content width, distribute extra space across gaps to fit screen
        if (constraints.maxWidth > estimatedContentWidth) {
          final extraSpace = constraints.maxWidth - estimatedContentWidth;
          dynamicSpacing = math.max(baseSpacing, (extraSpace / gaps) + 12.0);
        }

        return PmCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Table Actions & Column Visibility Toolbar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                ),
                child: Row(
                  children: [
                    if (_selectedIds.isNotEmpty) ...[
                      Text(
                        '${_selectedIds.length} selected',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: pm.destructive),
                      ),
                      const SizedBox(width: 12),
                      PmButton(
                        variant: PmButtonVariant.destructive,
                        size: PmButtonSize.sm,
                        onPressed: () {
                          widget.onBulkDelete?.call(_selectedIds.toList());
                          setState(() => _selectedIds.clear());
                        },
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.trash2, size: 14),
                            SizedBox(width: 6),
                            Text('Delete Selected'),
                          ],
                        ),
                      ),
                    ],
                    const Spacer(),
                    PopupMenuButton<String>(
                      tooltip: 'Show / Hide Columns',
                      offset: const Offset(0, 36),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      itemBuilder: (ctx) {
                        final cols = <String, String>{
                          'type': 'Type',
                          'party_name': 'Party Print Name',
                          'mobile': 'Mobile No.',
                          'address': 'Address',
                          'order_value': widget.isPurchase ? 'Quotation Value' : 'Order Value',
                          if (!widget.isPurchase) 'extra_work': 'Extra Work',
                          'payment_recd': 'Payment Received',
                          'balance': 'Balance',
                          'reminder_date': 'Reminder Date',
                        };
                        return cols.entries.map((entry) {
                          final isVisible = _visibleColumns.contains(entry.key);
                          return PopupMenuItem<String>(
                            value: entry.key,
                            child: Row(
                              children: [
                                Icon(
                                  isVisible ? LucideIcons.checkSquare : LucideIcons.square,
                                  size: 16,
                                  color: isVisible ? const Color(0xFF005CE6) : const Color(0xFF94A3B8),
                                ),
                                const SizedBox(width: 10),
                                Text(entry.value, style: const TextStyle(fontSize: 13)),
                              ],
                            ),
                          );
                        }).toList();
                      },
                      onSelected: (colKey) {
                        setState(() {
                          if (_visibleColumns.contains(colKey)) {
                            if (_visibleColumns.length > 1) {
                              _visibleColumns.remove(colKey);
                            }
                          } else {
                            _visibleColumns.add(colKey);
                          }
                        });
                        _saveSavedColumns();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.slidersHorizontal, size: 14, color: Color(0xFF475569)),
                            SizedBox(width: 6),
                            Text(
                              'Columns',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    showCheckboxColumn: false,
                    headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                    headingRowHeight: 44,
                    dataRowMinHeight: 48,
                    dataRowMaxHeight: 52,
                    dividerThickness: 1,
                    dataRowColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return const Color(0xFFEFF6FF);
                      }
                      return Colors.white;
                    }),
                    horizontalMargin: 12,
                    columnSpacing: dynamicSpacing,
              columns: [
                DataColumn(
                  label: Checkbox(
                    value: _selectedIds.length == sorted.length && sorted.isNotEmpty,
                    activeColor: const Color(0xFF005CE6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    side: BorderSide(
                      color: _selectedIds.isNotEmpty ? const Color(0xFF005CE6) : const Color(0xFF94A3B8),
                      width: 1.5,
                    ),
                    onChanged: (val) => _toggleSelectAll(),
                  ),
                ),
                DataColumn(
                  label: _SortHeader(
                    title: widget.isPurchase ? 'VENDOR ID' : 'ID',
                    isActive: _sortField == 'id_no',
                    isAsc: _sortAsc,
                    onTap: () => _setSort('id_no'),
                  ),
                ),
                if (_visibleColumns.contains('type'))
                  const DataColumn(label: Text('TYPE', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
                DataColumn(
                  label: _SortHeader(
                    title: widget.isPurchase ? 'VENDOR NAME' : 'CUSTOMER / SITE NAME',
                    isActive: _sortField == 'site_name',
                    isAsc: _sortAsc,
                    onTap: () => _setSort('site_name'),
                  ),
                ),
                if (_visibleColumns.contains('party_name'))
                  const DataColumn(label: Text('PARTY PRINT NAME', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
                if (_visibleColumns.contains('mobile'))
                  const DataColumn(label: Text('MOBILE NO.', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
                if (_visibleColumns.contains('address'))
                  const DataColumn(label: Text('ADDRESS', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
                if (_visibleColumns.contains('order_value'))
                  DataColumn(
                    numeric: true,
                    label: _SortHeader(
                      title: widget.isPurchase ? 'QUOTATION' : 'ORDER VALUE',
                      isActive: _sortField == 'order_value',
                      isAsc: _sortAsc,
                      onTap: () => _setSort('order_value'),
                    ),
                  ),
                if (!widget.isPurchase && _visibleColumns.contains('extra_work'))
                  const DataColumn(numeric: true, label: Text('EXTRA WORK', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
                if (_visibleColumns.contains('payment_recd'))
                  const DataColumn(
                    numeric: true,
                    label: Text('PAYMENT RECD', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF475569))),
                  ),
                if (_visibleColumns.contains('balance'))
                  DataColumn(
                    numeric: true,
                    label: _SortHeader(
                      title: 'BALANCE',
                      isActive: _sortField == 'balance',
                      isAsc: _sortAsc,
                      onTap: () => _setSort('balance'),
                    ),
                  ),
                if (_visibleColumns.contains('reminder_date'))
                  const DataColumn(label: Text('REMINDER DATE', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
                const DataColumn(label: Text('ACTION', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
              ],
              rows: sorted.map((rec) {
                final isSelected = _selectedIds.contains(rec.id);
                final bal = rec.balance as double;
                final orderType = (rec.orderType ?? '').toString().toUpperCase();
                final isSwh = orderType.contains('SWH') || orderType.contains('SOLAR');

                void openLedger() {
                  context.push('/pm/projects/${rec.id}${widget.isPurchase ? "?mode=purchase" : ""}');
                }

                Widget wrapCell(Widget child) {
                  return InkWell(
                    onTap: openLedger,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: child,
                    ),
                  );
                }

                return DataRow(
                  selected: isSelected,
                  cells: [
                    // Single square checkbox (not highlighted until selected)
                    DataCell(
                      Checkbox(
                        value: isSelected,
                        activeColor: const Color(0xFF005CE6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        side: BorderSide(
                          color: isSelected ? const Color(0xFF005CE6) : const Color(0xFF94A3B8),
                          width: 1.5,
                        ),
                        onChanged: (val) => _toggleSelect(rec.id),
                      ),
                    ),
                    DataCell(
                      wrapCell(
                        Text(
                          '${rec.idNo}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                      ),
                    ),
                    if (_visibleColumns.contains('type'))
                      DataCell(
                        wrapCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isSwh ? const Color(0xFFE0F2FE) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(9999),
                              border: Border.all(
                                color: isSwh ? const Color(0xFFBAE6FD) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Text(
                              rec.orderType.toString().toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                                color: isSwh ? const Color(0xFF0284C7) : const Color(0xFF475569),
                              ),
                            ),
                          ),
                        ),
                      ),
                    DataCell(
                      wrapCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 180),
                          child: Text(
                            rec.siteName.toString().toUpperCase(),
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                    if (_visibleColumns.contains('party_name'))
                      DataCell(
                        wrapCell(
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 130),
                            child: Text(
                              rec.partyPrintName ?? '-',
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: Color(0xFF475569)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    if (_visibleColumns.contains('mobile'))
                      DataCell(
                        wrapCell(
                          Text(
                            rec.mobileNumber != null && rec.mobileNumber!.isNotEmpty ? rec.mobileNumber! : '-',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: Color(0xFF475569)),
                          ),
                        ),
                      ),
                    if (_visibleColumns.contains('address'))
                      DataCell(
                        wrapCell(
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 140),
                            child: Text(
                              rec.address ?? '-',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    if (_visibleColumns.contains('order_value'))
                      DataCell(
                        wrapCell(
                          Text(
                            '₹${_currencyFormat.format(rec.orderValue)}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                          ),
                        ),
                      ),
                    if (!widget.isPurchase && _visibleColumns.contains('extra_work'))
                      DataCell(
                        wrapCell(
                          Text(
                            rec.extraWorkValue > 0 ? '₹${_currencyFormat.format(rec.extraWorkValue)}' : '-',
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                          ),
                        ),
                      ),
                    // Light green column background for PAYMENT RECD
                    if (_visibleColumns.contains('payment_recd'))
                      DataCell(
                        wrapCell(
                          Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '₹${_currencyFormat.format(rec.paymentReceived)}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF16A34A),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (_visibleColumns.contains('balance'))
                      DataCell(
                        wrapCell(
                          Text(
                            '₹${_currencyFormat.format(bal)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                        ),
                      ),
                    if (_visibleColumns.contains('reminder_date'))
                      DataCell(
                        wrapCell(
                          rec.reminderDate != null
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(9999),
                                    border: Border.all(color: const Color(0xFFBFDBFE)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(LucideIcons.calendar, size: 11, color: Color(0xFF005CE6)),
                                      const SizedBox(width: 4),
                                      Text(
                                        _dateFormat.format(rec.reminderDate!),
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF005CE6),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : const Text('-', style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8))),
                        ),
                      ),
                    DataCell(
                      InkWell(
                        onTap: openLedger,
                        borderRadius: BorderRadius.circular(6),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.externalLink, size: 13, color: Color(0xFF005CE6)),
                              SizedBox(width: 4),
                              Text(
                                'Ledger',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF005CE6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    ),
  );
},
);
}

  Widget _buildMobileCards(PmTokens pm, List<dynamic> sorted) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sorted.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (ctx, i) {
        final rec = sorted[i];
        final orderVal = (rec.orderValue as num).toDouble();
        final paidVal = (rec.paymentReceived as num).toDouble();
        final bal = (rec.balance as num).toDouble();
        final percentCollected = orderVal > 0 ? (paidVal / orderVal).clamp(0.0, 1.0) : 0.0;
        final percentInt = (percentCollected * 100).round();

        final hasPhone = rec.mobileNumber != null && rec.mobileNumber!.toString().trim().isNotEmpty;
        final hasAddress = rec.address != null && rec.address!.toString().trim().isNotEmpty;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                context.push('/pm/projects/${rec.id}${widget.isPurchase ? "?mode=purchase" : ""}');
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Bar: #ID + Product Badge + Arrow
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFCBD5E1), width: 0.8),
                              ),
                              child: Text(
                                '#${rec.idNo}',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(9999),
                                border: Border.all(color: const Color(0xFFBFDBFE), width: 0.8),
                              ),
                              child: Text(
                                rec.orderType.toString().isNotEmpty ? rec.orderType.toString() : 'Project',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Center(
                            child: Icon(
                              LucideIcons.arrowUpRight,
                              size: 16,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Site / Project Name
                    Text(
                      rec.siteName,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),

                    if (rec.partyPrintName != null &&
                        rec.partyPrintName!.toString().trim().isNotEmpty &&
                        rec.partyPrintName != rec.siteName) ...[
                      const SizedBox(height: 2),
                      Text(
                        rec.partyPrintName!,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],

                    if (hasPhone || hasAddress) const SizedBox(height: 8),

                    // Contact & Location Rows
                    if (hasPhone)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.phone, size: 13, color: Color(0xFF2563EB)),
                            const SizedBox(width: 6),
                            Text(
                              rec.mobileNumber!,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (hasAddress)
                      Row(
                        children: [
                          const Icon(LucideIcons.mapPin, size: 13, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              rec.address!,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                    const SizedBox(height: 12),

                    // Progress Bar for Payment Collection
                    if (orderVal > 0) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Collection Progress',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            '$percentInt% collected',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: percentInt >= 100
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFF2563EB),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: percentCollected,
                          minHeight: 5,
                          backgroundColor: const Color(0xFFE2E8F0),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            percentInt >= 100 ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Financial Stats Box (3 Columns)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _MobileStatCol(
                              title: widget.isPurchase ? 'QUOTATION' : 'ORDER VALUE',
                              value: '₹${_currencyFormat.format(orderVal)}',
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          Container(width: 1, height: 28, color: const Color(0xFFE2E8F0)),
                          Expanded(
                            child: _MobileStatCol(
                              title: widget.isPurchase ? 'PAID' : 'RECEIVED',
                              value: '₹${_currencyFormat.format(paidVal)}',
                              color: const Color(0xFF16A34A),
                            ),
                          ),
                          Container(width: 1, height: 28, color: const Color(0xFFE2E8F0)),
                          Expanded(
                            child: _MobileStatCol(
                              title: 'BALANCE',
                              value: '₹${_currencyFormat.format(bal)}',
                              color: bal > 0
                                  ? const Color(0xFFEA580C)
                                  : (bal < 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SortHeader extends StatelessWidget {
  final String title;
  final bool isActive;
  final bool isAsc;
  final VoidCallback onTap;

  const _SortHeader({
    required this.title,
    required this.isActive,
    required this.isAsc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          Icon(
            isActive
                ? (isAsc ? LucideIcons.chevronUp : LucideIcons.chevronDown)
                : LucideIcons.chevronsUpDown,
            size: 13,
          ),
        ],
      ),
    );
  }
}

class _MobileStatCol extends StatelessWidget {
  final String title;
  final String value;
  final Color? color;

  const _MobileStatCol({required this.title, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
            letterSpacing: 0.4,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color ?? const Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }
}
