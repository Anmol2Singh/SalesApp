import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/pm_tokens.dart';
import '../../data/models/pm_project.dart';
import '../../data/models/pm_purchase.dart';
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
              headingRowColor: WidgetStateProperty.all(pm.secondary.withOpacity(0.6)),
              dataRowColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return pm.primary.withOpacity(0.05);
                }
                return null;
              }),
              horizontalMargin: 16,
              columnSpacing: 20,
              columns: [
                DataColumn(
                  label: Checkbox(
                    value: _selectedIds.length == sorted.length && sorted.isNotEmpty,
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
                const DataColumn(label: Text('TYPE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                DataColumn(
                  label: _SortHeader(
                    title: widget.isPurchase ? 'VENDOR NAME' : 'SITE / CUSTOMER NAME',
                    isActive: _sortField == 'site_name',
                    isAsc: _sortAsc,
                    onTap: () => _setSort('site_name'),
                  ),
                ),
                const DataColumn(label: Text('PARTY NAME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                const DataColumn(label: Text('MOBILE NO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                const DataColumn(label: Text('ADDRESS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
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
                  const DataColumn(numeric: true, label: Text('EXTRA WORK', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                DataColumn(
                  numeric: true,
                  label: Text(widget.isPurchase ? 'PAID' : 'PAYMENT RECD', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
                const DataColumn(label: Text('REMINDER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                const DataColumn(label: Text('ACTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
              ],
              rows: sorted.map((rec) {
                final isSelected = _selectedIds.contains(rec.id);
                final bal = rec.balance as double;

                return DataRow(
                  selected: isSelected,
                  onSelectChanged: (val) => _toggleSelect(rec.id),
                  cells: [
                    DataCell(
                      Checkbox(
                        value: isSelected,
                        onChanged: (val) => _toggleSelect(rec.id),
                      ),
                    ),
                    DataCell(Text('#${rec.idNo}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: pm.mutedForeground))),
                    DataCell(PmBadge(label: rec.orderType, variant: PmBadgeVariant.secondary)),
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 180),
                        child: Text(
                          rec.siteName,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: pm.foreground),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(Text(rec.partyPrintName ?? '-', style: TextStyle(fontSize: 12, color: pm.mutedForeground))),
                    DataCell(Text(rec.mobileNumber ?? '-', style: TextStyle(fontSize: 12, color: pm.mutedForeground))),
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 160),
                        child: Text(rec.address ?? '-', style: TextStyle(fontSize: 12, color: pm.mutedForeground), overflow: TextOverflow.ellipsis),
                      ),
                    ),
                    DataCell(Text('₹${_currencyFormat.format(rec.orderValue)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                    if (!widget.isPurchase)
                      DataCell(Text('₹${_currencyFormat.format(rec.extraWorkValue)}', style: const TextStyle(fontSize: 12))),
                    DataCell(Text('₹${_currencyFormat.format(rec.paymentReceived)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: pm.success))),
                    DataCell(
                      Text(
                        '₹${_currencyFormat.format(bal)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: bal > 0 ? pm.success : (bal < 0 ? pm.destructive : pm.foreground),
                        ),
                      ),
                    ),
                    DataCell(
                      rec.reminderDate != null
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: pm.secondary,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: pm.border),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(LucideIcons.calendar, size: 12, color: pm.primary),
                                  const SizedBox(width: 4),
                                  Text(_dateFormat.format(rec.reminderDate!), style: const TextStyle(fontSize: 11)),
                                ],
                              ),
                            )
                          : const Text('-', style: TextStyle(fontSize: 12)),
                    ),
                    DataCell(
                      PmButton(
                        variant: PmButtonVariant.ghost,
                        size: PmButtonSize.sm,
                        onPressed: () {
                          context.push('/pm/projects/${rec.id}${widget.isPurchase ? "?mode=purchase" : ""}');
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.externalLink, size: 12, color: pm.primary),
                            const SizedBox(width: 4),
                            Text('Ledger', style: TextStyle(fontSize: 11, color: pm.primary)),
                          ],
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
