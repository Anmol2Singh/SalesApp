# IZYHEAT Sales Workflow App

A production-ready Flutter + Supabase mobile application designed for internal sales operations at IZYHEAT. It guides staff through the complete sales workflow lifecycle: 
**Quotation → Bill of Quantities (BOQ) → Factory Order → Purchase Order**.

---

## Key Features

1. **Role-Based Access Control (RBAC):**
   - **Admin:** Full company-wide data access, analytics dashboard, user management, and templates.
   - **Sales Executive:** Create/view own customers and pipelines.
   - **Factory/Production Staff:** Manage Step 3 (Factory Order) details.
   - **Purchase Staff:** Manage Step 4 (Purchase Order) vendor/material pricing.
   
2. **Customer Deduplication & Merge:**
   - Search-as-you-type fuzzy matching on company/phone/email before creating new customer records to enforce data normalization.
   - Single customer record has one-to-many relationship with pipelines.

3. **Client-Side PDF Generation & Upload:**
   - Custom dynamic PDFs generated locally using the `pdf` and `printing` packages.
   - Automatically uploaded to private Supabase Storage buckets.
   - View/print/share completed step documents directly from the step tracker or action cards.

4. **Realtime Notifications:**
   - real-time updates for step progression/unlock events.
   - Push notification placeholders wired through Supabase Edge Functions.

5. **Reporting & Dashboards:**
   - **Admin Dashboard:** leaderboards, pipeline funnel charts, time-based analytics.
   - **Excel Export:** Paginated reports generated locally using the `excel` package and shared natively using `share_plus`.

---

## Project Structure

```
lib/
  main.dart                           # Entry point with Riverpod & Supabase init
  app.dart                            # Routing and application-wide theme configuration
  core/
    theme/                            # AppTheme, colors, and typography tokens
    router/                           # GoRouter navigation paths and role-based guards
    providers/                        # Shared Riverpod providers (Supabase client, profile, etc.)
    models/                           # Domain entities (Customer, Product, Pipeline, etc.)
    services/
      pdf_service.dart                # PDF layout engine (invoices, receipts, specs)
      excel_service.dart              # Excel sheet compiler (.xlsx formatter)
      storage_service.dart            # Supabase Storage client wrappers
    widgets/
      step_tracker.dart               # Visual step tracker indicator (Quotation -> BOQ -> FO -> PO)
  features/
    auth/                             # Authentication state and login interface
    customers/                        # Customer records, dedupe check, detail hierarchy
    pipelines/                        # Workflow trackers and lifecycle pipelines
    quotation/                        # Step 1 Quotation form
    boq/                              # Step 2 BOQ builder
    factory_order/                    # Step 3 Factory production queue
    purchase_order/                   # Step 4 Purchase order placement
    notifications/                    # In-app notifications feed
    dashboard/                        # Admin analytics & Salesperson metrics
    admin/                            # Product catalog, user registry, PDF template settings
supabase/
  migrations/                         # SQL Schema, RLS policies, and Seed data
  functions/                          # Deno Edge Functions (Quotation confirmation, user creation)
```

---

## Setup Instructions

### 1. Database Setup
1. Create a project in [Supabase](https://supabase.com/).
2. Run the SQL migrations under `supabase/migrations/` in sequence:
   - `001_initial_schema.sql` (Creates profiles, products, pipelines, etc.)
   - `002_rls_policies.sql` (Enables row-level security per role)
   - `003_seed.sql` (Inserts initial products like Boom Barrier and Heat Pump)

### 2. Environment Configurations
1. Copy `.env.example` to `.env` in the project root:
   ```env
   SUPABASE_URL=https://your-project-ref.supabase.co
   SUPABASE_ANON_KEY=your-anon-key-here
   ```
2. Replace values with your actual Supabase URL and Anon Key.

### 3. Edge Functions Deployment
To deploy the Deno Edge Functions (required for Admin User Creation & Server-side Quotation Totals validation):
```bash
supabase functions deploy confirm_quotation
supabase functions deploy create_user
supabase functions deploy send_fcm
```

### 4. Running the Flutter App
1. Install Flutter (minimum version `3.5.0` or later).
2. Fetch dependencies:
   ```bash
   flutter pub get
   ```
3. Run the project:
   ```bash
   flutter run
   ```

---

## Testing & Quality Control

### Running Unit & Widget Tests
```bash
flutter test
```

### Static Analysis
Ensure code remains clean and standard-compliant:
```bash
flutter analyze
```
