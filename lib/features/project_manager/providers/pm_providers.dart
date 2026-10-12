import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../data/models/pm_project.dart';
import '../data/models/pm_purchase.dart';
import '../data/models/pm_ledger_entry.dart';
import '../data/models/pm_payment_term.dart';
import '../data/models/pm_expense.dart';
import '../data/models/pm_calling_record.dart';
import '../data/models/pm_checklist_item.dart';
import '../data/models/pm_work_remark.dart';
import '../data/models/pm_daily_transaction.dart';
import '../data/repositories/pm_projects_repository.dart';
import '../data/repositories/pm_purchases_repository.dart';
import '../data/repositories/pm_ledger_repository.dart';
import '../data/repositories/pm_daily_transactions_repository.dart';
import 'pm_company_provider.dart';
import 'pm_mode_provider.dart';

// -----------------------------------------------------------------------------
// REPOSITORIES
// -----------------------------------------------------------------------------
final pmProjectsRepositoryProvider = Provider<PmProjectsRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return PmProjectsRepository(supabase);
});

final pmPurchasesRepositoryProvider = Provider<PmPurchasesRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return PmPurchasesRepository(supabase);
});

final pmLedgerRepositoryProvider = Provider<PmLedgerRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return PmLedgerRepository(supabase);
});

final pmDailyTransactionsRepositoryProvider = Provider<PmDailyTransactionsRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return PmDailyTransactionsRepository(supabase);
});

// -----------------------------------------------------------------------------
// PROJECTS (Sales Mode)
// -----------------------------------------------------------------------------
final pmProjectsListProvider = FutureProvider.autoDispose<List<PmProject>>((ref) async {
  final repo = ref.watch(pmProjectsRepositoryProvider);
  final activeCompany = ref.watch(pmActiveCompanyProvider);
  return repo.getProjects(companyId: activeCompany.id);
});

// -----------------------------------------------------------------------------
// PURCHASES / VENDORS (Purchase Mode)
// -----------------------------------------------------------------------------
final pmPurchasesListProvider = FutureProvider.autoDispose<List<PmPurchase>>((ref) async {
  final repo = ref.watch(pmPurchasesRepositoryProvider);
  final activeCompany = ref.watch(pmActiveCompanyProvider);
  return repo.getPurchases(companyId: activeCompany.id);
});

// -----------------------------------------------------------------------------
// CUSTOMER LINKED PROJECTS (Phase 2 Critical Integration)
// Used in existing CustomerDetailScreen to show linked projects without copying data
// -----------------------------------------------------------------------------
final customerLinkedProjectsProvider = FutureProvider.family<List<PmProject>, String>((ref, customerId) async {
  final supabase = ref.watch(supabaseClientProvider);
  final res = await supabase
      .from('pm_projects')
      .select('*')
      .eq('customer_id', customerId)
      .order('created_at', ascending: false);

  return (res as List<dynamic>).map((e) => PmProject.fromJson(Map<String, dynamic>.from(e))).toList();
});

// -----------------------------------------------------------------------------
// SINGLE PROJECT / VENDOR DETAILS
// -----------------------------------------------------------------------------
final pmProjectDetailProvider = FutureProvider.family<PmProject?, String>((ref, id) async {
  final repo = ref.watch(pmProjectsRepositoryProvider);
  return repo.getProjectById(id);
});

final pmPurchaseDetailProvider = FutureProvider.family<PmPurchase?, String>((ref, id) async {
  final repo = ref.watch(pmPurchasesRepositoryProvider);
  return repo.getPurchaseById(id);
});

// -----------------------------------------------------------------------------
// PROJECT / VENDOR SUBCOLLECTIONS
// -----------------------------------------------------------------------------
final pmLedgerEntriesProvider = FutureProvider.family<List<PmLedgerEntry>, ({String id, bool isPurchase})>((ref, arg) async {
  final repo = ref.watch(pmLedgerRepositoryProvider);
  return repo.getLedgerEntries(arg.id, isPurchase: arg.isPurchase);
});

final pmPaymentTermsProvider = FutureProvider.family<List<PmPaymentTerm>, String>((ref, projectId) async {
  final repo = ref.watch(pmLedgerRepositoryProvider);
  return repo.getPaymentTerms(projectId);
});

final pmExpensesProvider = FutureProvider.family<List<PmExpense>, String>((ref, projectId) async {
  final repo = ref.watch(pmLedgerRepositoryProvider);
  return repo.getExpenses(projectId);
});

final pmCallingRecordsProvider = FutureProvider.family<List<PmCallingRecord>, ({String id, bool isPurchase})>((ref, arg) async {
  final repo = ref.watch(pmLedgerRepositoryProvider);
  return repo.getCallingRecords(arg.id, isPurchase: arg.isPurchase);
});

final pmChecklistItemsProvider = FutureProvider.family<List<PmChecklistItem>, String>((ref, projectId) async {
  final repo = ref.watch(pmLedgerRepositoryProvider);
  return repo.getChecklistItems(projectId);
});

final pmWorkRemarksProvider = FutureProvider.family<List<PmWorkRemark>, String>((ref, projectId) async {
  final repo = ref.watch(pmLedgerRepositoryProvider);
  return repo.getWorkRemarks(projectId);
});

// -----------------------------------------------------------------------------
// DAILY TRANSACTIONS FILTER & STATE
// -----------------------------------------------------------------------------
class DailyTransactionsFilterState {
  final String searchQuery;
  final String timeframe; // 'Today', 'Week', 'Month', 'Lifetime', 'Custom'
  final DateTime? startDate;
  final DateTime? endDate;
  final String firmName;
  final String partyName;
  final String paymentMode;
  final String transactionName;
  final String entryNature;
  final String flowType;

  const DailyTransactionsFilterState({
    this.searchQuery = '',
    this.timeframe = 'Month',
    this.startDate,
    this.endDate,
    this.firmName = 'ALL',
    this.partyName = 'ALL',
    this.paymentMode = 'ALL',
    this.transactionName = 'ALL',
    this.entryNature = 'ALL',
    this.flowType = 'ALL',
  });

  DailyTransactionsFilterState copyWith({
    String? searchQuery,
    String? timeframe,
    DateTime? startDate,
    DateTime? endDate,
    String? firmName,
    String? partyName,
    String? paymentMode,
    String? transactionName,
    String? entryNature,
    String? flowType,
  }) {
    return DailyTransactionsFilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      timeframe: timeframe ?? this.timeframe,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      firmName: firmName ?? this.firmName,
      partyName: partyName ?? this.partyName,
      paymentMode: paymentMode ?? this.paymentMode,
      transactionName: transactionName ?? this.transactionName,
      entryNature: entryNature ?? this.entryNature,
      flowType: flowType ?? this.flowType,
    );
  }
}

final dailyTransactionsFilterProvider = StateProvider<DailyTransactionsFilterState>((ref) {
  return const DailyTransactionsFilterState();
});

final pmDailyTransactionsListProvider = FutureProvider.autoDispose<List<PmDailyTransaction>>((ref) async {
  final repo = ref.watch(pmDailyTransactionsRepositoryProvider);
  final activeCompany = ref.watch(pmActiveCompanyProvider);
  final filter = ref.watch(dailyTransactionsFilterProvider);

  DateTime? start = filter.startDate;
  DateTime? end = filter.endDate;
  final now = DateTime.now();

  if (filter.timeframe == 'Today') {
    start = DateTime(now.year, now.month, now.day);
    end = DateTime(now.year, now.month, now.day, 23, 59, 59);
  } else if (filter.timeframe == 'Week') {
    start = now.subtract(Duration(days: now.weekday - 1));
    end = now;
  } else if (filter.timeframe == 'Month') {
    start = DateTime(now.year, now.month, 1);
    end = now;
  } else if (filter.timeframe == 'Lifetime') {
    start = null;
    end = null;
  }

  final list = await repo.getDailyTransactions(
    companyId: activeCompany.id,
    startDate: start,
    endDate: end,
    firmName: filter.firmName,
    partyName: filter.partyName,
    paymentMode: filter.paymentMode,
    transactionName: filter.transactionName,
    entryNature: filter.entryNature,
    flowType: filter.flowType,
  );

  if (filter.searchQuery.isEmpty) return list;
  final q = filter.searchQuery.toLowerCase();
  return list.where((t) {
    return t.partyName.toLowerCase().contains(q) ||
        t.firmName.toLowerCase().contains(q) ||
        t.transactionName.toLowerCase().contains(q) ||
        t.paymentMode.toLowerCase().contains(q) ||
        (t.remark?.toLowerCase().contains(q) ?? false);
  }).toList();
});
