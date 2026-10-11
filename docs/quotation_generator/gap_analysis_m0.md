# Milestone M0: Quotation Generator Gap Analysis & Reuse/Retire Plan

**Date**: 2026-10-11  
**Source Branch**: `feature/quotation-generator` (Commit `3fc49b6`)  
**Target Branch**: `feature/quotation-generator-v2`  

---

## 1. Executive Summary & Audit Verification
An audit of commit `3fc49b6` identified isolation violations where the experimental module wrote directly to existing production tables (`quotations`, `pdf_templates`), uploaded to existing storage buckets (`company-assets`, `product-images`, `pdfs`), and modified non-whitelisted core files.

In **Milestone M0**, all unsafe write paths have been contained and disabled behind hard guards (`kDisableUnsafeExistingWrites`, `kQgStandaloneCreateEnabled`), non-whitelisted files have been restored to match `main` byte-for-byte, read-only diagnostic SQL scripts have been generated, and test baselines on both `main` and `v2` have been documented.

---

## 2. File-by-File Disposition (60 Files)

### 2.1 Reverted Non-Whitelisted Files (Restored to `main` byte-for-byte)
| File | Action | Rationale |
|---|---|---|
| `lib/features/auth/screens/login_screen.dart` | Reverted | Removed stray `ValueKey` additions. |
| `lib/features/customer_app/shared/widgets/gradient_button.dart` | Reverted | Removed `MaterialType.transparency`. |
| `test/widget_test.dart` | Reverted | Restored original smoke test from `main`. |
| `test/app_test.dart` | Reverted | Restored original app test from `main`. |
| `test_output.pdf` | Deleted | Stray artifact removed from root repository. |

### 2.2 Allowed Whitelisted Additive Integrations (Retained)
| File | Disposition | Notes |
|---|---|---|
| `lib/core/router/app_router.dart` | Adapt | Hub route retained (`/heat-pump-quotations`); `/new` route retired behind `kQgStandaloneCreateEnabled = false`. |
| `lib/core/widgets/app_shell.dart` | Keep | Navigation tile retained. |
| `lib/features/dashboard/screens/admin_dashboard_screen.dart` | Keep | Quick action button retained. |
| `lib/features/dashboard/screens/sales_dashboard_screen.dart` | Keep | Quick action button retained. |
| `pubspec.yaml` | Keep | Assets registration entries retained. |

### 2.3 Bundled Assets
| Path / Files | Disposition | Action Plan |
|---|---|---|
| `assets/fonts/NotoSans-Bold.ttf`, `assets/fonts/NotoSans-Regular.ttf` | **Keep & Reuse** | Required for PDF generation and Indian Rupee (₹) glyph rendering without runtime network dependencies. |
| `assets/images/*` (`cover_proposal.png`, `company_stamp.png`, `izyheat_logo.png`, `insiya_banner.png`, `footer_strip.png`, social icons) | **Reuse & Calibrate** | Calibrate against `Final_Quotation_Template.pdf` extracted images (`pdfimages -all`). |
| `assets/data/*.json` (`heat_pump_models.json`, `all_in_one_models.json`, `pool_models.json`, `tank_presets.json`) | **Retire as primary; keep as offline fallback seed** | Primary catalog moves to `qg_catalog` seeded from CSVs via Python import script in M1. |

### 2.4 Models
| File | Disposition | Action Plan |
|---|---|---|
| `heat_pump_model.dart` | **Reuse & Adapt** | Align with `qg_catalog` domestic schema; support whole-number kW auto-derivation (`IZ-{kW}C`). |
| `all_in_one_model.dart` | **Reuse & Adapt** | Align with `Insiya_Data - All in one.csv`. |
| `pool_heat_pump_model.dart` | **Reuse & Adapt** | Align with `Insiya_Data - Swimming Pool.csv`. |
| `tank_spec.dart` | **Reuse & Adapt** | Expand to include SS (Stainless Steel) and PUFF / Rockwool dropdown presets. |
| `deal_quotation_option.dart` | **Reuse & Extend** | Enrich to support parsing deal items, supplementary items, and salesperson details. |
| `generator_company_settings.dart` | **Adapt -> Migrate** | Decouple from `pdf_templates`; migrate backing store to `qg_settings`. |
| `generator_quotation.dart` | **Adapt** | Adapt to reflect proposal payload structure stored in `qg_proposals.payload`. |
| `price_item.dart` | **Keep** | Retain helper models for price rows. |
| `price_row.dart` | **Keep & Reuse** | Clean representation of line items, statuses (priced, included, extra). |
| `sales_person.dart` | **Keep & Adapt** | Retain for salesperson dropdown and name/phone formatting. |
| `tank_line_item.dart` | **Keep** | Retain for tank line item parsing. |

### 2.5 Config
| File | Disposition | Action Plan |
|---|---|---|
| `quotation_generator_flags.dart` | **New / Keep** | Feature flags (`kQuotationGeneratorEnabled`, `kQgStandaloneCreateEnabled = false`, `kDisableUnsafeExistingWrites = true`). |
| `dynamic_annexure_resolver.dart` | **Reuse & Adapt** | Logic for determining Annexure titles and page flows based on active components. |
| `quote_template_config.dart` | **Reuse & Adapt** | Update for template fidelity, payment sentence generator, and category templates. |
| `quote_type.dart` | **Retire from UI** | Document types are now dynamically derived from deal items rather than user selection. Remove `Split` type. |

### 2.6 Data Layer & Repositories
| File | Disposition | Action Plan |
|---|---|---|
| `data/quotation_supabase_repository.dart` | **Contained & Retire** | Contained in M0. In M1, replace with `DealQuotationsRepository` (strictly read-only) and `QgProposalsRepository` (writes to `qg_proposals` via RPC). |
| `data/catalog_repository.dart` | **Adapt** | Switch to load from `qg_catalog` table with local cache fallback. |

### 2.7 Services
| File | Disposition | Action Plan |
|---|---|---|
| `services/pdf_quotation_builder.dart` | **Reuse & Rework** | Redesign layout to match `Final_Quotation_Template.pdf` verbatim (margins, headers, tables, exact text blocks). |
| `services/price_calculator.dart` | **Retire as primary; Keep for consistency check** | Totals now come directly from source `quotations` row. Calculator runs as a reconciliation warning check (> ₹1 mismatch). |
| `services/quote_number_service.dart` | **Retire** | Quote numbers now default to `quotations.quotation_number` (`deal_number` mode). |
| `services/quotation_storage_service.dart` | **Adapt** | Retarget exclusively to private bucket `quotation-generator` under path `proposals/{quotation_id}/...`. |

### 2.8 UI Screens & Widgets
| File | Disposition | Action Plan |
|---|---|---|
| `ui/screens/quotation_history_screen.dart` | **Rewrite** | Transform into the deal-driven Hub displaying Heat Pump deal quotations with status badges, search, filter, and 30s polling. |
| `ui/screens/quotation_form_screen.dart` | **Retire standalone create -> Replace with Proposal Builder** | Replace standalone form with Proposal Builder (collapsible sections: Customer, Items & Resolve, Supplementary, Payment Terms, Specs, Images, Preview). |
| `ui/screens/quotation_preview_screen.dart` | **Adapt** | PDF preview with watermarking ("DRAFT - NOT APPROVED" before approval), gating Finalize/Save until `quotations.status == 'confirmed'`. |
| `ui/screens/quotation_settings_screen.dart` | **Rewire** | Rewire settings from `pdf_templates` to `qg_settings`, `qg_categories`, `qg_spec_templates`, `qg_text_blocks`. |
| `ui/widgets/customer_picker_dialog.dart` | **Retire** | Customer is pre-selected by the deal. |
| `ui/widgets/deal_quotation_picker_sheet.dart` | **Retire** | Hub automatically lists deal quotations. |
| `ui/widgets/image_picker_tile.dart` | **Adapt** | Keep images local until approval; upload to `quotation-generator` bucket upon finalization. |
| `ui/widgets/live_summary_card.dart` | **Keep / Adapt** | Adapt for proposal summary display. |
| `ui/widgets/price_row_editor.dart` | **Keep / Adapt** | Adapt for resolve items editor. |
| `ui/widgets/tank_lines_editor.dart` | **Keep / Adapt** | Adapt for tank specifications editor. |

### 2.9 Tests
| File | Disposition | Action Plan |
|---|---|---|
| `test/quotation_generator/quotation_customer_selection_test.dart` | **Move to `test/quotation_generator/`** | Tests customer model parsing. |
| `test/quotation_generator/quotation_generator_test.dart` | **Move to `test/quotation_generator/` & Clean** | Removed file write to `test_output.pdf`. |
| `test/quotation_generator/quotation_phase2_golden_test.dart` | **Move to `test/quotation_generator/`** | Retained math vectors; rewrite golden visual comparison for new template. |
| `test/quotation_generator/quotation_supabase_repository_test.dart` | **Move to `test/quotation_generator/`** | Serialization tests. |
| `test/quotation_generator/quotation_isolation_source_scan_test.dart` | **New (M1/M2)** | Static source code scanner asserting no writes to non-`qg_` tables or legacy buckets. |

---

## 3. Containment Verification (M0)
1. **Unsafe writes disabled**:
   - `QuotationSupabaseRepository.saveSettings` guarded: no writes to `pdf_templates`.
   - `QuotationSupabaseRepository.saveQuotation` guarded: no writes to `quotations`.
   - `QuotationSupabaseRepository.deleteQuotation` guarded: no updates to `quotations`.
   - `QuotationSupabaseRepository.getAndIncrementNextRunningNumber` guarded: no writes to `pdf_templates`.
   - `QuotationStorageService.uploadImageFile` guarded: no uploads to `company-assets`, `product-images`, or `pdfs`.
   - `QuotationStorageService.uploadQuotationPdf` guarded: no uploads to `pdfs`.
2. **Standalone create flow retired**:
   - `kQgStandaloneCreateEnabled = false` hides the Floating Action Button in `QuotationHistoryScreen` and redirects `/heat-pump-quotations/new` to the Hub.
3. **Database Health Report Script**:
   - `tools/quotation_generator/db_health_report.sql` created for Supabase SQL Editor execution.
   - `tools/quotation_generator/manual_cleanup_template.sql` created for manual review and remediation.
4. **Baseline Reports**:
   - `docs/quotation_generator/baseline_main.txt` and `docs/quotation_generator/baseline_v2.txt` recorded.
