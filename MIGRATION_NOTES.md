# Project Manager Port & Migration Notes

## 1. Overview
The **Project Manager** module from the Next.js/React web system (`Project Manager`) has been ported into the Flutter **SalesApp** under `lib/features/project_manager/`.

### Core Architectural Decisions & Invariants
1. **Single Source of Truth for Customers**:
   - There is **no isolated customer entity** inside Project Manager.
   - All projects require a valid customer foreign key:
     `pm_projects.customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT`.
   - Customer attributes (party print name, mobile number, firm name, address) are dynamically joined (`customers!inner (...)`) and never duplicated.
2. **Seamless Dual Mode**:
   - **Sales Mode**: Customer site projects with order values, extra work, payments, financial ledger, payment terms, calling remarks, SWH checklists, and technical remarks.
   - **Purchase Mode**: Vendor purchase tracking with quotation values, payments paid, balance, vendor ledger, and calling logs.
3. **Multi-Company Support**:
   - Multi-tenant company filtering (`insiya-solar`, `isi-water-heater`, etc.) with quick company selector.
4. **Day-Book Cashflow Register**:
   - `pm_daily_transactions` table provides day-book tracking across Sales, Purchases, and Project Expenses with Credit (+) / Debit (-) flows.

---

## 2. Database Schema (`028_project_manager.sql`)

Run migration `supabase/migrations/028_project_manager.sql` in your Supabase project:

```bash
# Example using Supabase CLI
supabase db push
# Or execute 028_project_manager.sql in Supabase SQL Editor
```

### Tables Created:
| Table Name | Description | Key Foreign Keys |
|---|---|---|
| `pm_projects` | Project directory | `customer_id -> customers(id)`, `pipeline_id -> sales_pipelines(id)` |
| `pm_purchases` | Vendor directory | `created_by -> profiles(id)` |
| `pm_payment_terms` | Payment milestone terms | `project_id -> pm_projects(id) ON DELETE CASCADE` |
| `pm_ledger_entries` | Project financial ledger | `project_id -> pm_projects(id) ON DELETE CASCADE` |
| `pm_purchase_ledger_entries` | Vendor purchase ledger | `purchase_id -> pm_purchases(id) ON DELETE CASCADE` |
| `pm_expenses` | Direct project expenses | `project_id -> pm_projects(id) ON DELETE CASCADE` |
| `pm_calling_records` | Follow-up call logs | `project_id` or `purchase_id` |
| `pm_swh_checklist` | Solar Water Heater technical checklist | `project_id -> pm_projects(id) ON DELETE CASCADE` |
| `pm_work_remarks` | Timeline / work remarks | `project_id -> pm_projects(id) ON DELETE CASCADE` |
| `pm_daily_transactions` | Day-book cashflow register | `company_id` |
| `pm_project_attachments` | Project documents & photos | `project_id -> pm_projects(id) ON DELETE CASCADE` |

### Triggers & Functions:
- `trg_pm_ledger_update_project`: Auto-recalculates project `order_value`, `extra_work_value`, and `payment_received` whenever ledger entries change.
- `trg_pm_purchase_ledger_update`: Auto-recalculates vendor `quotation_value` and `payment_paid`.
- `update_pm_*_modtime`: Auto-updates `updated_at` timestamps.

### Row Level Security (RLS) Policies:
- **Admin & Manager**: Full SELECT, INSERT, UPDATE, DELETE across all `pm_*` tables.
- **Sales Head & Sales Executives**:
  - Full read access to projects and linked entries.
  - Write access to projects created by user or assigned via customer.
- **Purchase Staff**: Full read/write on `pm_purchases` and `pm_purchase_ledger_entries`.
- **Factory & Service Staff**: Read-only access to checklists and technical parameters.

---

## 3. Data Migration (`tools/migrate_pm_data.py`)

To migrate legacy data from the Next.js SQLite/JSON/CSV backups (`supabase_data_backup.json` / `Trading Upload.csv`) into the Supabase database:

```bash
python tools/migrate_pm_data.py --backup-json "D:/Files/Html Codes/Project Manager/supabase_data_backup.json"
```

### Safety & Duplicate Prevention Rules:
1. Every legacy project row searches the existing `customers` table for an exact or phone number match (ignoring country code prefixes and formatting).
2. If matched: Assigns existing `customer_id`.
3. If unmatched: Logs the project to `unmatched_customers_report.json` for human review. It **never creates duplicate customer records**.

---

## 4. Flutter Code Architecture

```
lib/features/project_manager/
├── data/
│   ├── models/
│   │   ├── pm_project.dart             # Project model with linked Customer
│   │   ├── pm_purchase.dart            # Vendor purchase model
│   │   ├── pm_payment_term.dart        # Payment milestone terms
│   │   ├── pm_ledger_entry.dart        # Financial / purchase ledger entries
│   │   ├── pm_expense.dart             # Project expenses
│   │   ├── pm_calling_record.dart      # Calling logs
│   │   ├── pm_checklist_item.dart      # SWH technical checklist
│   │   ├── pm_work_remark.dart         # Timeline work remarks
│   │   ├── pm_daily_transaction.dart   # Day-book cashflow register
│   │   └── pm_company.dart             # Multi-company metadata
│   ├── repositories/
│   │   ├── pm_projects_repository.dart
│   │   ├── pm_purchases_repository.dart
│   │   ├── pm_ledger_repository.dart
│   │   └── pm_daily_transactions_repository.dart
│   └── services/
│       ├── pm_pdf_service.dart         # Directory & ledger PDF generator
│       └── pm_excel_service.dart       # Directory & ledger Excel exporter
├── presentation/
│   ├── screens/
│   │   ├── pm_dashboard_screen.dart    # Main Directory with KPI summary cards & table
│   │   ├── pm_project_detail_screen.dart # Detail screen with 6 tabs
│   │   ├── pm_project_form_screen.dart # Create / Edit modal with customer picker
│   │   ├── pm_daily_transactions_screen.dart # Day-Book cash register
│   │   ├── pm_filter_screen.dart       # Advanced filters & export hub
│   │   └── pm_quick_call_remark_screen.dart # Rapid follow-up call remark
│   ├── tabs/
│   │   ├── pm_ledger_tab.dart          # Running ledger table with additions
│   │   ├── pm_payment_terms_tab.dart   # Payment milestones & progress
│   │   ├── pm_expenses_tab.dart        # Direct project expenses
│   │   ├── pm_calling_records_tab.dart # Follow-up call logs
│   │   ├── pm_swh_checklist_tab.dart   # Solar Water Heater scope & checklist
│   │   └── pm_work_remarks_tab.dart    # Installation progress remarks
│   ├── theme/
│   │   └── pm_tokens.dart              # Scoped tokens converting shadcn variables
│   └── widgets/
│       ├── customer_search_picker.dart # Unified customer picker with direct create link
│       ├── pm_directory_table.dart     # Responsive table with column toggles
│       ├── pm_header_bar.dart          # Header with company & mode switchers
│       ├── pm_card.dart
│       ├── pm_badge.dart
│       ├── pm_button.dart
│       └── pm_stat_card.dart
└── providers/
    ├── pm_mode_provider.dart           # Sales vs Purchase mode state
    ├── pm_company_provider.dart        # Active company state
    └── pm_providers.dart               # Riverpod data streams & customerLinkedProjectsProvider
```

---

## 5. Routes & Navigation

| Route | Screen | Access Roles |
|---|---|---|
| `/pm` | `PmDashboardScreen` | Admin, Manager, Sales, SalesHead, Purchase, Factory, BOQ |
| `/pm/daily-transactions` | `PmDailyTransactionsScreen` | Admin, Manager, Sales, Purchase |
| `/pm/filter` | `PmFilterScreen` | All PM roles |
| `/pm/projects/new` | `PmProjectFormScreen` | Admin, Manager, Sales |
| `/pm/projects/:id` | `PmProjectDetailScreen` | All PM roles |
| `/pm/projects/:id/edit` | `PmProjectFormScreen(editId: id)` | Admin, Manager, Sales, Purchase |
| `/pm/projects/:id/call-remark` | `PmQuickCallRemarkScreen` | All PM roles |

### Customer Integration
On `CustomerDetailScreen` (`/customers/:id`), a dedicated **Projects & Sites** section renders all projects linked to the customer via `customerLinkedProjectsProvider(customerId)`. Tapping any site opens its full Project Manager details directly.
