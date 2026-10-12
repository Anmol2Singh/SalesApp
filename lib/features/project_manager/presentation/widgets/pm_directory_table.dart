import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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
  final Set<String> _selectedIds = {};
  String _sortField = 'id_no';
  bool _sortAsc = false;
  final _currencyFormat = NumberFormat('#,##,##0', 'en_IN');
  final _dateFormat = DateFormat('dd-MM-yyyy');

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
    return PmCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // Table Actions Toolbar
          if (_selectedIds.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: pm.destructive.withOpacity(0.08),
              child: Row(
                children: [
                  Text(
                    '${_selectedIds.length} selected',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: pm.destructive),
                  ),
                  const Spacer(),
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
              ),
            ),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              headingRowHeight: 46,
              dataRowMinHeight: 52,
              dataRowMaxHeight: 56,
              dividerThickness: 1,
              dataRowColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const Color(0xFFEFF6FF);
                }
                return Colors.white;
              }),
              horizontalMargin: 20,
              columnSpacing: 24,
              columns: [
                DataColumn(
                  label: Checkbox(
                    shape: const CircleBorder(),
                    value: _selectedIds.length == sorted.length && sorted.isNotEmpty,
                    activeColor: const Color(0xFF005CE6),
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
                const DataColumn(label: Text('TYPE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
                DataColumn(
                  label: _SortHeader(
                    title: widget.isPurchase ? 'VENDOR NAME' : 'CUSTOMER / SITE NAME',
                    isActive: _sortField == 'site_name',
                    isAsc: _sortAsc,
                    onTap: () => _setSort('site_name'),
                  ),
                ),
                const DataColumn(label: Text('PARTY PRINT NAME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
                const DataColumn(label: Text('MOBILE NO.', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
                const DataColumn(label: Text('ADDRESS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
                DataColumn(
                  numeric: true,
                  label: _SortHeader(
                    title: widget.isPurchase ? 'QUOTATION' : 'ORDER VALUE',
                    isActive: _sortField == 'order_value',
                    isAsc: _sortAsc,
                    onTap: () => _setSort('order_value'),
                  ),
                ),
                if (!widget.isPurchase)
                  const DataColumn(numeric: true, label: Text('EXTRA WORK', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
                const DataColumn(
                  numeric: true,
                  label: Text('PAYMENT RECD', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569))),
                ),
                DataColumn(
                  numeric: true,
                  label: _SortHeader(
                    title: 'BALANCE',
                    isActive: _sortField == 'balance',
                    isAsc: _sortAsc,
                    onTap: () => _setSort('balance'),
                  ),
                ),
                const DataColumn(label: Text('REMINDER DATE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
                const DataColumn(label: Text('ACTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
              ],
              rows: sorted.map((rec) {
                final isSelected = _selectedIds.contains(rec.id);
                final bal = rec.balance as double;
                final orderType = (rec.orderType ?? '').toString().toUpperCase();
                final isSwh = orderType.contains('SWH') || orderType.contains('SOLAR');

                return DataRow(
                  selected: isSelected,
                  onSelectChanged: (val) => _toggleSelect(rec.id),
                  cells: [
                    DataCell(
                      Checkbox(
                        shape: const CircleBorder(),
                        value: isSelected,
                        activeColor: const Color(0xFF005CE6),
                        onChanged: (val) => _toggleSelect(rec.id),
                      ),
                    ),
                    DataCell(
                      Text(
                        '${rec.idNo}',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
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
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                            color: isSwh ? const Color(0xFF0284C7) : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 220),
                        child: Text(
                          rec.siteName.toString().toUpperCase(),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 160),
                        child: Text(
                          rec.partyPrintName ?? '-',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF475569)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        rec.mobileNumber != null && rec.mobileNumber!.isNotEmpty ? rec.mobileNumber! : '-',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF475569)),
                      ),
                    ),
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 200),
                        child: Text(
                          rec.address ?? '-',
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        '₹${_currencyFormat.format(rec.orderValue)}',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                      ),
                    ),
                    if (!widget.isPurchase)
                      DataCell(
                        Text(
                          rec.extraWorkValue > 0 ? '₹${_currencyFormat.format(rec.extraWorkValue)}' : '-',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ),
                    // Light green column background for PAYMENT RECD (Screenshot 1)
                    DataCell(
                      Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '₹${_currencyFormat.format(rec.paymentReceived)}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        '₹${_currencyFormat.format(bal)}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF16A34A),
                        ),
                      ),
                    ),
                    DataCell(
                      rec.reminderDate != null
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(9999),
                                border: Border.all(color: const Color(0xFFBFDBFE)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(LucideIcons.calendar, size: 12, color: Color(0xFF005CE6)),
                                  const SizedBox(width: 5),
                                  Text(
                                    _dateFormat.format(rec.reminderDate!),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF005CE6),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : const Text('-', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                    ),
                    DataCell(
                      InkWell(
                        onTap: () {
                          context.push('/pm/projects/${rec.id}${widget.isPurchase ? "?mode=purchase" : ""}');
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.externalLink, size: 14, color: Color(0xFF005CE6)),
                              SizedBox(width: 5),
                              Text(
                                'Ledger',
                                style: TextStyle(
                                  fontSize: 12.5,
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
        ],
      ),
    );
  }

  Widget _buildMobileCards(PmTokens pm, List<dynamic> sorted) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sorted.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final rec = sorted[i];
        final bal = rec.balance as double;

        return PmCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text('#${rec.idNo}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: pm.mutedForeground)),
                      const SizedBox(width: 8),
                      PmBadge(label: rec.orderType, variant: PmBadgeVariant.secondary),
                    ],
                  ),
                  IconButton(
                    icon: Icon(LucideIcons.externalLink, size: 18, color: pm.primary),
                    onPressed: () {
                      context.push('/pm/projects/${rec.id}${widget.isPurchase ? "?mode=purchase" : ""}');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                rec.siteName,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: pm.foreground),
              ),
              if (rec.mobileNumber != null && rec.mobileNumber!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(LucideIcons.phone, size: 12, color: pm.primary),
                    const SizedBox(width: 6),
                    Text(rec.mobileNumber!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: pm.primary)),
                  ],
                ),
              ],
              if (rec.address != null && rec.address!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(LucideIcons.mapPin, size: 12, color: pm.mutedForeground),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        rec.address!,
                        style: TextStyle(fontSize: 11, color: pm.mutedForeground),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              // Stats Grid
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: pm.secondary.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(pm.radiusMd),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _MobileStatCol(title: 'Order', value: '₹${_currencyFormat.format(rec.orderValue)}'),
                    _MobileStatCol(title: 'Recd', value: '₹${_currencyFormat.format(rec.paymentReceived)}', color: pm.success),
                    _MobileStatCol(
                      title: 'Balance',
                      value: '₹${_currencyFormat.format(bal)}',
                      color: bal > 0 ? pm.success : (bal < 0 ? pm.destructive : null),
                    ),
                  ],
                ),
              ),
            ],
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
      children: [
        Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}
