// lib/features/quotation_generator/ui/screens/quotation_history_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../models/generator_quotation.dart';
import '../../models/generator_company_settings.dart';
import '../../providers/quotation_generator_providers.dart';
import '../../services/price_calculator.dart';
import '../../config/quotation_generator_flags.dart';
import 'quotation_form_screen.dart';
import 'quotation_preview_screen.dart';
import 'quotation_settings_screen.dart';

class QuotationHistoryScreen extends ConsumerStatefulWidget {
const QuotationHistoryScreen({super.key});

@override
ConsumerState<QuotationHistoryScreen> createState() =>
_QuotationHistoryScreenState();
}

class _QuotationHistoryScreenState extends ConsumerState<QuotationHistoryScreen>
with SingleTickerProviderStateMixin {
late TabController _tabController;
final _searchCtrl = TextEditingController();
String _selectedFilter = 'All'; // 'All', 'Draft', 'Sent', 'Accepted'

@override
void initState() {
super.initState();
_tabController = TabController(length: 2, vsync: this);
_tabController.addListener(() {
if (mounted) setState(() {});
});
}

@override
void dispose() {
_tabController.dispose();
_searchCtrl.dispose();
super.dispose();
}

void _navigateBack() {
if (Navigator.of(context).canPop()) {
Navigator.of(context).pop();
return;
}
if (context.canPop()) {
context.pop();
return;
}
final profile = ref.read(currentProfileProvider);
final home = profile != null ? getRoleHome(profile.primaryRole) : AppRoutes.adminDashboard;
context.go(home);
}

@override
Widget build(BuildContext context) {
return PopScope(
canPop: false,
onPopInvokedWithResult: (didPop, result) {
if (didPop) return;
_navigateBack();
},
child: Scaffold(
appBar: AppBar(
leading: IconButton(
icon: const Icon(Icons.arrow_back),
tooltip: 'Back',
onPressed: _navigateBack,
),
title: const Text(
'Quotation Hub',
style: TextStyle(fontWeight: FontWeight.bold),
),
backgroundColor: AppColors.primary,
foregroundColor: Colors.white,
elevation: 0,
bottom: TabBar(
controller: _tabController,
indicatorColor: AppColors.accent,
indicatorWeight: 3,
labelColor: Colors.white,
unselectedLabelColor: Colors.white70,
tabs: const [
Tab(icon: Icon(Icons.history_edu_outlined), text: 'Quotations'),
Tab(icon: Icon(Icons.settings_outlined), text: 'Quotation Settings'),
],
),
),
body: TabBarView(
controller: _tabController,
children: [
_buildQuotationsTab(),
const QuotationSettingsScreen(),
],
),
floatingActionButton: _tabController.index == 0 && kQgStandaloneCreateEnabled
? FloatingActionButton.extended(
onPressed: () {
Navigator.push(
context,
MaterialPageRoute(
builder: (_) => const QuotationGeneratorFormScreen(),
),
);
},
backgroundColor: AppColors.primary,
foregroundColor: Colors.white,
icon: const Icon(Icons.add),
label: const Text('New Quotation'),
)
: null,
),
);
}

Widget _buildQuotationsTab() {
final listAsync = ref.watch(quotationsHistoryProvider);
final isDark = Theme.of(context).brightness == Brightness.dark;

return listAsync.when(
loading: () => const Center(child: CircularProgressIndicator()),
error: (e, _) => Center(child: Text('Error loading quotations: $e')),
data: (allQuotes) {
final query = _searchCtrl.text.trim().toLowerCase();
final filtered = allQuotes.where((q) {
final matchSearch = q.customerName.toLowerCase().contains(query) ||
q.quoteRefNo.toLowerCase().contains(query);
final matchFilter = _selectedFilter == 'All' || q.status == _selectedFilter;
return matchSearch && matchFilter;
}).toList();

// Calculate KPI metrics
final totalCount = allQuotes.length;
final draftCount = allQuotes.where((q) => q.status.toLowerCase() == 'draft').length;
final sentCount = allQuotes.where((q) => q.status.toLowerCase() == 'sent').length;
final acceptedCount = allQuotes.where((q) => q.status.toLowerCase() == 'accepted').length;
final totalPipeline = allQuotes.fold<int>(0, (sum, q) => sum + q.grandTotal);

return Column(
children: [
// ─── 1. EXECUTIVE KPI OVERVIEW BAR ──────────────────────────
if (allQuotes.isNotEmpty)
Container(
padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
color: isDark ? const Color(0xFF1E293B) : Colors.white,
child: Row(
children: [
Expanded(
child: _buildKpiCard(
title: 'Total Quotes',
value: '$totalCount',
icon: Icons.description_outlined,
color: AppColors.primary,
isDark: isDark,
),
),
const SizedBox(width: 8),
Expanded(
child: _buildKpiCard(
title: 'Drafts',
value: '$draftCount',
icon: Icons.edit_note_outlined,
color: AppColors.warning,
isDark: isDark,
),
),
const SizedBox(width: 8),
Expanded(
child: _buildKpiCard(
title: 'Pipeline',
value: PriceCalculator.formatIndianCurrency(totalPipeline),
icon: Icons.account_balance_wallet_outlined,
color: AppColors.success,
isDark: isDark,
),
),
],
),
),

// ─── 2. SEARCH & FILTER SECTION ─────────────────────────────
Container(
padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
color: isDark ? const Color(0xFF1E293B) : Colors.white,
child: Column(
children: [
TextField(
controller: _searchCtrl,
style: TextStyle(
fontSize: 14,
color: isDark ? Colors.white : const Color(0xFF1E293B),
),
decoration: InputDecoration(
hintText: 'Search by customer or quote ref no...',
hintStyle: TextStyle(
fontSize: 13,
color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
),
prefixIcon: Icon(
Icons.search,
size: 20,
color: isDark ? Colors.white70 : const Color(0xFF64748B),
),
suffixIcon: _searchCtrl.text.isNotEmpty
? IconButton(
icon: Icon(
Icons.clear,
size: 18,
color: isDark ? Colors.white70 : const Color(0xFF64748B),
),
onPressed: () => setState(() => _searchCtrl.clear()),
)
: null,
isDense: true,
filled: true,
fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
border: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
borderSide: BorderSide(
color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
),
),
enabledBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
borderSide: BorderSide(
color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
),
),
focusedBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
borderSide: const BorderSide(
color: AppColors.primary,
width: 1.5,
),
),
),
onChanged: (_) => setState(() {}),
),
const SizedBox(height: 10),
SingleChildScrollView(
scrollDirection: Axis.horizontal,
child: Row(
children: [
_buildFilterBadge('All', totalCount, isDark),
_buildFilterBadge('Draft', draftCount, isDark),
_buildFilterBadge('Sent', sentCount, isDark),
_buildFilterBadge('Accepted', acceptedCount, isDark),
],
),
),
],
),
),

const Divider(height: 1, thickness: 1),

// ─── 3. QUOTATIONS LIST ─────────────────────────────────────
Expanded(
child: RefreshIndicator(
onRefresh: () => ref.read(quotationsHistoryProvider.notifier).loadQuotations(),
color: AppColors.primary,
child: filtered.isEmpty
? ListView(
children: [
Padding(
padding: const EdgeInsets.all(32),
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [
Container(
padding: const EdgeInsets.all(20),
decoration: BoxDecoration(
color: AppColors.primary.withOpacity(0.08),
shape: BoxShape.circle,
),
child: const Icon(Icons.cloud_sync_outlined,
size: 48, color: AppColors.primary),
),
const SizedBox(height: 16),
Text(
allQuotes.isEmpty
? 'No quotations in Supabase yet'
: 'No matching quotations found',
style: const TextStyle(
fontSize: 17,
fontWeight: FontWeight.bold,
),
),
const SizedBox(height: 6),
Text(
allQuotes.isEmpty
? 'Tap "New Quotation" below to craft your first proposal synced to Supabase.'
: 'Try adjusting your search query or active filter.',
textAlign: TextAlign.center,
style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
),
if (allQuotes.isNotEmpty) ...[
const SizedBox(height: 16),
OutlinedButton.icon(
onPressed: () {
setState(() {
_searchCtrl.clear();
_selectedFilter = 'All';
});
},
icon: const Icon(Icons.refresh, size: 16),
label: const Text('Reset Filters'),
),
],
],
),
),
],
)
: ListView.separated(
physics: const AlwaysScrollableScrollPhysics(),
padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
itemCount: filtered.length,
separatorBuilder: (_, __) => const SizedBox(height: 12),
itemBuilder: (context, index) {
final item = filtered[index];
return _buildQuotationCard(item);
},
),
),
),
],
);
},
);
}

Widget _buildKpiCard({
required String title,
required String value,
required IconData icon,
required Color color,
required bool isDark,
}) {
return Container(
padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
decoration: BoxDecoration(
color: isDark ? Colors.black26 : color.withOpacity(0.06),
borderRadius: BorderRadius.circular(10),
border: Border.all(color: color.withOpacity(0.2)),
),
child: Row(
children: [
Icon(icon, size: 20, color: color),
const SizedBox(width: 8),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
mainAxisSize: MainAxisSize.min,
children: [
Text(
title,
style: TextStyle(
fontSize: 10.5,
fontWeight: FontWeight.w600,
color: isDark ? Colors.white70 : AppColors.textSecondary,
),
maxLines: 1,
overflow: TextOverflow.ellipsis,
),
Text(
value,
style: TextStyle(
fontSize: 13,
fontWeight: FontWeight.w900,
color: isDark ? Colors.white : AppColors.textPrimary,
),
maxLines: 1,
overflow: TextOverflow.ellipsis,
),
],
),
),
],
),
);
}

Widget _buildFilterBadge(String label, int count, bool isDark) {
final isSelected = _selectedFilter == label;
final activeBg = isDark ? const Color(0xFF38BDF8) : AppColors.primary;

return Padding(
padding: const EdgeInsets.only(right: 8),
child: Material(
color: Colors.transparent,
child: InkWell(
borderRadius: BorderRadius.circular(20),
onTap: () => setState(() => _selectedFilter = label),
child: AnimatedContainer(
duration: const Duration(milliseconds: 180),
padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
decoration: BoxDecoration(
color: isSelected
? activeBg
: (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
borderRadius: BorderRadius.circular(20),
border: Border.all(
color: isSelected
? activeBg
: (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
),
boxShadow: isSelected
? [
BoxShadow(
color: activeBg.withOpacity(0.25),
blurRadius: 4,
offset: const Offset(0, 2),
),
]
: null,
),
child: Row(
mainAxisSize: MainAxisSize.min,
children: [
Text(
label,
style: TextStyle(
fontSize: 12.5,
fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
color: isSelected
? Colors.white
: (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
),
),
const SizedBox(width: 6),
Container(
padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
decoration: BoxDecoration(
color: isSelected
? Colors.white.withOpacity(0.22)
: (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
borderRadius: BorderRadius.circular(10),
),
child: Text(
'$count',
style: TextStyle(
fontSize: 11,
fontWeight: FontWeight.bold,
color: isSelected
? Colors.white
: (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
),
),
),
],
),
),
),
),
);
}

Widget _buildQuotationCard(GeneratorQuotation q) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  Color statusColor;
  IconData statusIcon;
  switch (q.status.toLowerCase()) {
    case 'accepted':
      statusColor = AppColors.success;
      statusIcon = Icons.check_circle_outline;
      break;
    case 'sent':
      statusColor = AppColors.info;
      statusIcon = Icons.send_outlined;
      break;
    default:
      statusColor = AppColors.warning;
      statusIcon = Icons.hourglass_empty;
  }

// Customer initials
final words = q.customerName.trim().split(RegExp(r'\s+'));
final initials = words.length >= 2
? '${words[0][0]}${words[1][0]}'.toUpperCase()
: (words.isNotEmpty && words[0].isNotEmpty
? words[0].substring(0, words[0].length.clamp(1, 2)).toUpperCase()
: 'QT');

return Dismissible(
key: Key(q.id),
direction: DismissDirection.endToStart,
background: Container(
alignment: Alignment.centerRight,
padding: const EdgeInsets.only(right: 20),
decoration: BoxDecoration(
color: AppColors.error,
borderRadius: BorderRadius.circular(16),
),
child: const Row(
mainAxisAlignment: MainAxisAlignment.end,
children: [
Icon(Icons.delete_outline, color: Colors.white, size: 22),
SizedBox(width: 6),
Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
],
),
),
confirmDismiss: (direction) async {
return await showDialog<bool>(
context: context,
builder: (ctx) => AlertDialog(
title: const Text('Delete Quotation?'),
content: Text('Are you sure you want to delete quotation for "${q.customerName}"?'),
actions: [
TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
ElevatedButton(
onPressed: () => Navigator.pop(ctx, true),
style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
child: const Text('Delete'),
),
],
),
);
},
onDismissed: (_) {
ref.read(quotationsHistoryProvider.notifier).deleteQuotation(q.id);
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(content: Text('Deleted quote for ${q.customerName}')),
);
},
child: Card(
elevation: 1.5,
shadowColor: Colors.black.withOpacity(0.08),
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(16),
side: BorderSide(
color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
),
),
child: InkWell(
borderRadius: BorderRadius.circular(16),
onTap: () {
final settings = ref.read(quotationSettingsProvider).valueOrNull ??
const GeneratorCompanySettings();
Navigator.push(
context,
MaterialPageRoute(
builder: (_) => QuotationPreviewScreen(
quotation: q,
settings: settings,
),
),
);
},
child: Padding(
padding: const EdgeInsets.all(14),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
// Top Customer Row with Avatar & Status
Row(
crossAxisAlignment: CrossAxisAlignment.center,
children: [
Container(
width: 40,
height: 40,
decoration: BoxDecoration(
gradient: const LinearGradient(
colors: [Color(0xFF1C5D97), Color(0xFF0F3B66)],
begin: Alignment.topLeft,
end: Alignment.bottomRight,
),
borderRadius: BorderRadius.circular(10),
),
alignment: Alignment.center,
child: Text(
initials,
style: const TextStyle(
color: Colors.white,
fontWeight: FontWeight.bold,
fontSize: 14,
),
),
),
const SizedBox(width: 12),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
q.customerName.isNotEmpty ? q.customerName : 'Unnamed Customer',
style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
maxLines: 1,
overflow: TextOverflow.ellipsis,
),
const SizedBox(height: 2),
Row(
children: [
Text(
q.quoteRefNo,
style: const TextStyle(
fontSize: 11.5,
fontWeight: FontWeight.w600,
color: AppColors.primary,
),
),
const SizedBox(width: 6),
Text(
'• ${DateFormat('dd MMM yyyy').format(q.date)}',
style: TextStyle(
fontSize: 11,
color: isDark ? Colors.white60 : AppColors.textSecondary,
),
),
],
),
],
),
),
// Status Badge
Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  decoration: BoxDecoration(
    color: statusColor.withOpacity(0.12),
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: statusColor.withOpacity(0.3)),
  ),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(statusIcon, size: 12, color: statusColor),
      const SizedBox(width: 4),
      Text(
        q.status.isNotEmpty ? q.status : 'Draft',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: statusColor,
        ),
      ),
    ],
  ),
),
],
),

const SizedBox(height: 12),

// Equipment Configuration Tag
Container(
width: double.infinity,
padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
decoration: BoxDecoration(
color: isDark ? Colors.black26 : const Color(0xFFF8FAFC),
borderRadius: BorderRadius.circular(8),
border: Border.all(
color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
),
),
child: Row(
children: [
const Icon(Icons.bolt, size: 15, color: AppColors.primary),
const SizedBox(width: 4),
Text(
'${q.model.modelName} (${q.model.displayCapacityKw} KW)',
style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
),
const Text('  •  ', style: TextStyle(color: Colors.grey)),
const Icon(Icons.water_drop_outlined, size: 14, color: Color(0xFF0284C7)),
const SizedBox(width: 4),
Expanded(
child: Text(
'${q.tankCapacityLitres}L ${q.isTankPressurized ? "Pressurized" : "Non-Pressurized"}',
style: TextStyle(
fontSize: 12,
color: isDark ? Colors.white70 : AppColors.textSecondary,
),
maxLines: 1,
overflow: TextOverflow.ellipsis,
),
),
],
),
),

const SizedBox(height: 12),

// Price and Actions Row
Row(
mainAxisAlignment: MainAxisAlignment.spaceBetween,
crossAxisAlignment: CrossAxisAlignment.center,
children: [
Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
PriceCalculator.formatIndianCurrency(q.grandTotal),
style: TextStyle(
fontSize: 17,
fontWeight: FontWeight.w900,
color: isDark ? const Color(0xFF60A5FA) : AppColors.primary,
),
),
Text(
'Incl. ${q.gstPercent.toInt()}% GST',
style: TextStyle(
fontSize: 10,
color: isDark ? Colors.white54 : AppColors.textSecondary,
),
),
],
),
Row(
children: [
// Quick 1-tap PDF Preview button
FilledButton.tonalIcon(
onPressed: () {
final settings = ref.read(quotationSettingsProvider).valueOrNull ??
const GeneratorCompanySettings();
Navigator.push(
context,
MaterialPageRoute(
builder: (_) => QuotationPreviewScreen(
quotation: q,
settings: settings,
),
),
);
},
icon: const Icon(Icons.picture_as_pdf_outlined, size: 15),
label: const Text('PDF'),
style: FilledButton.styleFrom(
visualDensity: VisualDensity.compact,
padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
),
),
const SizedBox(width: 4),
IconButton(
icon: const Icon(Icons.copy_outlined, size: 18),
tooltip: 'Duplicate',
visualDensity: VisualDensity.compact,
onPressed: () async {
final dup = await ref
.read(quotationsHistoryProvider.notifier)
.duplicateQuotation(q);
if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text('✓ Duplicated quote: ${dup.quoteRefNo}'),
backgroundColor: AppColors.success,
),
);
}
},
),
IconButton(
icon: const Icon(Icons.edit_outlined, size: 18),
tooltip: 'Edit',
visualDensity: VisualDensity.compact,
onPressed: () {
Navigator.push(
context,
MaterialPageRoute(
builder: (_) => QuotationGeneratorFormScreen(
existingQuotation: q,
),
),
);
},
),
],
),
],
),
],
),
),
),
),
);
}
}
