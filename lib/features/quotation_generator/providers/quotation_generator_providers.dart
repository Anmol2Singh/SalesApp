// lib/features/quotation_generator/providers/quotation_generator_providers.dart

import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/providers/supabase_provider.dart';
import '../data/quotation_supabase_repository.dart';
import '../data/deal_quotations_repository.dart';
import '../data/qg_proposals_repository.dart';
import '../data/qg_settings_repository.dart';
import '../models/deal_quotation_item.dart';
import '../models/generator_company_settings.dart';
import '../models/generator_quotation.dart';
import '../models/heat_pump_model.dart';
import '../services/quote_number_service.dart';

final quotationRepositoryProvider = Provider<QuotationSupabaseRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return QuotationSupabaseRepository(supabase);
});

final dealQuotationsRepositoryProvider = Provider<DealQuotationsRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return DealQuotationsRepository(supabase);
});

final qgProposalsRepositoryProvider = Provider<QgProposalsRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return QgProposalsRepository(supabase);
});

final qgSettingsRepositoryProvider = Provider<QgSettingsRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return QgSettingsRepository(supabase);
});

final dealQuotationsProvider = FutureProvider.autoDispose<List<DealQuotationItem>>((ref) async {
  final repo = ref.watch(dealQuotationsRepositoryProvider);
  return repo.getDealQuotations();
});

// Backward compatibility alias
final quotationLocalRepositoryProvider = quotationRepositoryProvider;

// ─── SETTINGS PROVIDER ────────────────────────────────────────────────────────

class SettingsNotifier extends StateNotifier<AsyncValue<GeneratorCompanySettings>> {
  final QuotationSupabaseRepository _repo;

  SettingsNotifier(this._repo) : super(const AsyncValue.loading()) {
    loadSettings();
  }

  Future<void> loadSettings() async {
    try {
      final s = await _repo.getSettings();
      state = AsyncValue.data(s);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateSettings(GeneratorCompanySettings newSettings) async {
    await _repo.saveSettings(newSettings);
    state = AsyncValue.data(newSettings);
  }

  Future<void> saveModel(HeatPumpModel model) async {
    final current = state.valueOrNull ?? await _repo.getSettings();
    final updatedModels = List<HeatPumpModel>.from(current.models);
    final idx = updatedModels.indexWhere((m) => m.id == model.id);
    if (idx >= 0) {
      updatedModels[idx] = model;
    } else {
      updatedModels.add(model);
    }
    final updatedSettings = current.copyWith(models: updatedModels);
    await updateSettings(updatedSettings);
  }

  Future<void> deleteModel(String id) async {
    final current = state.valueOrNull ?? await _repo.getSettings();
    final updatedModels = current.models.where((m) => m.id != id).toList();
    final updatedSettings = current.copyWith(models: updatedModels);
    await updateSettings(updatedSettings);
  }

  Future<void> setCoverImage(String? path) async {
    final current = state.valueOrNull ?? await _repo.getSettings();
    final updated = current.copyWith(defaultCoverImagePath: path);
    await updateSettings(updated);
  }

  Future<void> setBannerImage(String? path) async {
    final current = state.valueOrNull ?? await _repo.getSettings();
    final updated = current.copyWith(defaultBannerImagePath: path);
    await updateSettings(updated);
  }

  Future<void> setStampImage(String? path) async {
    final current = state.valueOrNull ?? await _repo.getSettings();
    final updated = current.copyWith(stampImagePath: path);
    await updateSettings(updated);
  }
}

final quotationSettingsProvider =
    StateNotifierProvider<SettingsNotifier, AsyncValue<GeneratorCompanySettings>>((ref) {
  final repo = ref.watch(quotationRepositoryProvider);
  return SettingsNotifier(repo);
});

// ─── QUOTATIONS HISTORY PROVIDER ──────────────────────────────────────────────

class QuotationsHistoryNotifier extends StateNotifier<AsyncValue<List<GeneratorQuotation>>> {
  final QuotationSupabaseRepository _repo;

  QuotationsHistoryNotifier(this._repo) : super(const AsyncValue.loading()) {
    loadQuotations();
  }

  Future<void> loadQuotations() async {
    try {
      final list = await _repo.getAllQuotations();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> saveQuotation(GeneratorQuotation quotation, {Uint8List? pdfBytes}) async {
    await _repo.saveQuotation(quotation, pdfBytes: pdfBytes);
    await loadQuotations();
  }

  Future<void> deleteQuotation(String id) async {
    await _repo.deleteQuotation(id);
    await loadQuotations();
  }

  Future<GeneratorQuotation> duplicateQuotation(GeneratorQuotation q) async {
    final settings = await _repo.getSettings();
    final nextNum = await _repo.getAndIncrementNextRunningNumber();
    final now = DateTime.now();
    final newRef = QuoteNumberService.formatQuoteRef(
      prefix: settings.quotePrefix,
      date: now,
      runningNumber: nextNum,
    );

    final duplicated = q.copyWith(
      id: const Uuid().v4(),
      quoteRefNo: newRef,
      date: now,
      status: 'Draft',
      createdAt: now,
      updatedAt: now,
    );

    await _repo.saveQuotation(duplicated);
    await loadQuotations();
    return duplicated;
  }
}

final quotationsHistoryProvider =
    StateNotifierProvider<QuotationsHistoryNotifier, AsyncValue<List<GeneratorQuotation>>>((ref) {
  final repo = ref.watch(quotationRepositoryProvider);
  return QuotationsHistoryNotifier(repo);
});
