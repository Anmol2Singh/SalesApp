# NOC Generator Isolation & Compliance Report (Milestone N5)

**Feature**: NOC Generator (No Objection Certificate: Satisfactory Installation & Commissioning)  
**Target Reference**: `reference/NOC_Template.pdf` (Boom Barrier sample for "M/s TURQUOISE PUNE")  
**Branch**: `feature/qg-noc`  
**Date**: October 12, 2026  
**Status**: VERIFIED & PASSING (76/76 Tests Passed, 100% Golden Fidelity)  

---

## 1. Executive Summary

The No Objection Certificate (NOC) module provides automated, verifiable generation of installation and commissioning certificates directly within the `quotation_generator` subsystem. It supports two rendering modes:
1. **`template_exact`**: Verbatim visual and typographical reproduction of `reference/NOC_Template.pdf` (achieving **100.00% text fidelity** in golden test comparison).
2. **`enhanced`**: Production-grade layout for multi-equipment proposals with quotation/ticket references, clean numbering, and formal company attestations.

All architecture rules, database constraints, isolation boundaries, and security policies established for the `quotation_generator` module were strictly maintained throughout implementation.

---

## 2. Milestone Execution Log

| Milestone | Deliverables | Verification Status |
|---|---|---|
| **N0: Discovery & Baseline** | • Branch `feature/qg-noc`<br>• Baseline saved to `docs/quotation_generator/baseline_noc.txt`<br>• Extraction of models, terms, and typography from `reference/NOC_Template.pdf` | **Completed** |
| **N1: Schema, RPC, Seeds & Flag** | • `supabase/migrations/026_qg_noc.sql`<br>• `supabase/migrations/rollback/026_qg_noc_rollback.sql`<br>• Tables: `qg_noc_documents`, `qg_noc_counters`, `qg_noc_profiles`<br>• Atomic RPC: `qg_finalize_noc` (SECURITY DEFINER)<br>• Feature flag: `kQgNocEnabled = true` | **Completed** |
| **N2: Services & Extractor** | • Models: `qg_noc_profile.dart`, `qg_noc_document.dart`, `qg_noc_builder_state.dart`<br>• Services: `qg_noc_eligibility_service.dart`, `qg_noc_extractor.dart`<br>• Repository: `qg_noc_repository.dart`<br>• Unit tests: `qg_noc_eligibility_test.dart` (8 tests), `qg_noc_extractor_test.dart` (8 tests) | **Completed** (16/16 tests passed) |
| **N3: PDF Builder & Fidelity** | • `pdf_noc_builder.dart` (Single-page A4 invariant)<br>• Python comparison script: `tools/quotation_generator/compare_noc_fidelity.py`<br>• Smoke tests: `qg_noc_pdf_smoke_test.dart` (3 tests)<br>• Fidelity golden test: `qg_noc_pdf_fidelity_test.dart` | **Completed** (100.00% fidelity match, $\ge 97\%$ required) |
| **N4: UI Integration & Routes** | • Screens: `noc_hub_screen.dart`, `noc_builder_screen.dart`<br>• Pipeline card: `_NocActionCard` in `pipeline_detail_screen.dart`<br>• Settings tab: Tab 4 in `quotation_settings_screen.dart`<br>• Router: `/qg/noc`, `/qg/noc/builder` in `app_router.dart`<br>• UI test: `qg_noc_ui_test.dart` | **Completed** (UI tests passed) |
| **N5: Isolation Audit & Report** | • Full source scan and isolation audit<br>• Zero schema mutations on legacy tables<br>• Report: `docs/quotation_generator/isolation_report_noc.md` | **Completed** |

---

## 3. Strict Isolation Audit

### 3.1 Table Namespace Isolation
- **Rule**: All new tables must be prefixed with `qg_noc_`. Legacy tables (`sales_pipelines`, `quotations`, `customers`, `installations`, `products`, `profiles`) are strictly read-only.
- **Audit Result**: **PASSED**
  - New tables created:
    - `qg_noc_documents`
    - `qg_noc_counters`
    - `qg_noc_profiles`
  - Zero DDL alterations on any existing tables.
  - Zero `UPDATE`, `DELETE`, or `INSERT` queries executed against `sales_pipelines` or `quotations` from the NOC module.

### 3.2 Storage Bucket Isolation
- **Rule**: All file uploads must target the `quotation-generator` bucket under the `noc/` path. No writes to legacy buckets (`company-assets`, `product-images`, `pdfs`).
- **Audit Result**: **PASSED**
  - Storage path pattern: `quotation-generator/noc/<pipeline_id>/noc_<timestamp>.pdf`.
  - Zero access to legacy storage buckets.

### 3.3 Atomic Counter & Sequential Numbering
- **Rule**: Financial year-aware sequential numbering (`NOC-YY-YY-NNN`) generated atomically via database transaction with `FOR UPDATE` row lock.
- **Audit Result**: **PASSED**
  - Implemented in PostgreSQL function `qg_finalize_noc`.
  - Increments `qg_noc_counters` with row locking (`SELECT next_val FROM qg_noc_counters ... FOR UPDATE`).
  - Guarantees zero gaps or duplicate numbers during concurrent issuance.

### 3.4 Feature Flag Isolation
- **Rule**: Entire subsystem can be disabled via `kQgNocEnabled = false` in `qg_noc_flags.dart`.
- **Audit Result**: **PASSED**
  - `_NocActionCard` in `pipeline_detail_screen.dart` is conditionally rendered via `if (kQgNocEnabled)`.
  - NOC tab in `quotation_settings_screen.dart` is conditionally rendered via `if (kQgNocEnabled)`.

### 3.5 Legacy Code Preservation
- **Rule**: Existing lines in `pipeline_detail_screen.dart` must not be deleted or modified. Additions only.
- **Audit Result**: **PASSED**
  - Only additive changes: added `_NocActionCard` widget and conditionally rendered after `_WarrantyCardActionCard`.
  - All existing pipelines, quotation approval workflows, AMC cards, and warranty flows remain 100% intact.

---

## 4. Test Verification Suite

All 76 tests across `test/quotation_generator/` passed:

```
00:08 +76: All tests passed!
```

- **Fidelity Test**: `qg_noc_pdf_fidelity_test.dart` -> **100.00% Similarity** (163/163 words matching `reference/NOC_Template.pdf`).
- **Extractor Tests**: `qg_noc_extractor_test.dart` -> 8/8 tests passed.
- **Eligibility Tests**: `qg_noc_eligibility_test.dart` -> 8/8 tests passed.
- **PDF Smoke Tests**: `qg_noc_pdf_smoke_test.dart` -> 3/3 tests passed.
- **UI Tests**: `qg_noc_ui_test.dart` -> 2/2 tests passed.
- **Legacy Quotation Tests**: `quotation_phase2_golden_test.dart` -> 47/47 tests passed without regression.

---

## 5. Rollback Plan

If rollback is needed:
1. **Disable Flag**: Set `kQgNocEnabled = false` in `lib/features/quotation_generator/config/qg_noc_flags.dart`.
2. **Execute Database Rollback**: Run `supabase/migrations/rollback/026_qg_noc_rollback.sql` in Supabase SQL Editor.
   - Drops function `qg_finalize_noc`.
   - Drops tables `qg_noc_documents`, `qg_noc_counters`, `qg_noc_profiles`.
   - Cleans storage files under `quotation-generator/noc/`.
   - Deletes text blocks prefixed with `noc_`.
