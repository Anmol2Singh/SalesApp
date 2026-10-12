import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/pm_company.dart';

class PmCompaniesNotifier extends StateNotifier<List<PmCompany>> {
  PmCompaniesNotifier() : super(PmCompany.defaultCompanies);

  void addCompany(PmCompany company) {
    state = [...state, company];
  }

  void removeCompany(String id) {
    if (state.length <= 1) return;
    state = state.where((c) => c.id != id).toList();
  }
}

final pmCompaniesListProvider = StateNotifierProvider<PmCompaniesNotifier, List<PmCompany>>((ref) {
  return PmCompaniesNotifier();
});

class PmActiveCompanyNotifier extends StateNotifier<PmCompany> {
  PmActiveCompanyNotifier() : super(PmCompany.defaultCompanies.first);

  void setCompany(PmCompany company) {
    state = company;
  }
}

final pmActiveCompanyProvider = StateNotifierProvider<PmActiveCompanyNotifier, PmCompany>((ref) {
  return PmActiveCompanyNotifier();
});
