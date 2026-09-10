# IZYHEAT Sales Workflow App

## 0. Project Summary

Build a **production-ready cross-platform mobile app** for **IZYHEAT**, an internal sales-operations tool used by office staff (Sales Executives, Sales Managers, Factory/Production staff, Purchase staff, and Admins) to manage the full sales lifecycle for industrial products (Boom Barriers, Heat Pumps, and other products to be added later) — from **Quotation → BOQ → Factory Order → Purchase Order**, with per-customer grouping, role-based visibility, PDF generation at every stage, notifications, Excel export, and an analytics dashboard for admins.

**Stack (fixed — do not substitute):**
- **Frontend:** Flutter (Dart), targeting iOS + Android from one codebase
- **Backend/DB/Auth/Storage:** Supabase (Postgres + Supabase Auth + Supabase Storage + Row Level Security + Edge Functions)
- **State management:** Riverpod (preferred) or Bloc — pick one and use it consistently throughout
- **PDF generation:** Dart `pdf` + `printing` packages, generated client-side from structured data and uploaded to Supabase Storage
- **Push notifications:** Firebase Cloud Messaging (FCM) integrated alongside Supabase, since Supabase has no native push — use Supabase Edge Functions to trigger FCM sends on DB events
- **Excel export:** `excel` Dart package, files generated and shared/downloaded via `share_plus`

---

## 1. User Roles & Access Control

There is **no public sign-up**. All accounts are created by Admins only, inside an Admin Panel (can be a web view or in-app admin section gated by role).

| Role | Can do |
|---|---|
| **Admin** | Create/deactivate any user; assign roles; view ALL customers, quotations, BOQs, factory orders, purchase orders across ALL salespeople; view dashboard with company-wide analytics and leaderboard; manage product catalog; manage PDF templates; export any data to Excel; receive all critical notifications |
| **Sales Executive** | View/create only their own customers and the full pipeline for those customers; cannot see other salespeople's data; receives notifications relevant to their own records |
| **Sales Manager** *(optional tier, include if natural — otherwise fold into Admin)* | Same as Sales Executive, plus read-only visibility into their team's records |
| **Factory/Production Staff** | View only records that have reached Step 3 (Factory Order); update factory order status/fields; cannot see or edit Quotation/BOQ |
| **Purchase Staff** | View only records that have reached Step 4 (Purchase Order); update purchase order status/fields |

Implement this with **Supabase Row Level Security (RLS) policies**, not just client-side checks — client-side role gating is UX only, RLS is the actual security boundary. Every table must have RLS enabled with policies keyed off a `role` and `created_by` (or `assigned_to`) column tied to `auth.uid()`.

Login is **email/username + password only** (no self-service password reset to start — Admin resets passwords from the admin panel; add self-service "forgot password" via Supabase Auth email flow as a fast-follow, not blocking for v1).

---

## 2. Core Entity Model

Design the Postgres schema around these entities. Use UUID primary keys, `created_at`/`updated_at` timestamps (with trigger-based auto-update), and soft deletes (`deleted_at` nullable) rather than hard deletes everywhere.

### 2.1 `users` (mirrors `auth.users`, extended profile table `profiles`)
- id, full_name, email, phone, role (`admin` / `sales` / `factory` / `purchase`), is_active, created_at

### 2.2 `customers`
- id, company_name, contact_person, phone, email, address, gst_number (optional), created_by (FK → profiles), created_at
- **Important:** Customers must be **de-duplicated and merged**, not re-created per product. Before creating a new customer record, the app must search existing customers (fuzzy match on company name + phone/email) and prompt the salesperson: *"This customer already exists — add a new product to their existing record?"* Each customer has **one record**, and can have **many products/orders** under them — model this as a one-to-many relationship (`customers` → `sales_pipelines`), never duplicate the customer row per product.

### 2.3 `products`
- id, name, category, base_specs (jsonb), is_active
- Seed with **Boom Barrier** and **Heat Pump**; build the catalog as **admin-manageable** (add/edit/archive products and their custom fields) so new product lines can be added later without a code release.

### 2.4 `sales_pipelines` (the core workflow record — one per customer-product combination)
- id, customer_id (FK), product_id (FK), created_by (FK → profiles, the salesperson), current_step (enum: `quotation`, `boq`, `factory_order`, `purchase_order`, `completed`), status (enum: `in_progress`, `completed`, `on_hold`, `cancelled`), created_at, updated_at

### 2.5 `quotations`
- id, pipeline_id (FK, 1:1), quotation_number (auto-generated, e.g. `IZY/QT/2026/0001`), product_id, line_items (jsonb array: description, qty, unit_price, total), subtotal, tax, grand_total, terms_text, pdf_url (Supabase Storage path), confirmed_by, confirmed_at, status (`draft`, `confirmed`)
- **Step 1 unlocks Step 2 only when `status = 'confirmed'`** — this is the explicit gate the user described ("once sales person confirms the quotation... it will unlock ability to fill in [next]").

### 2.6 `boqs` (Bill of Quantities)
- id, pipeline_id (FK, 1:1), boq_number, items (jsonb array: component, spec, qty, unit, remarks), extra_fields (jsonb — dynamic, see §3.3), pdf_url, status (`draft`, `submitted`)

### 2.7 `factory_orders`
- id, pipeline_id (FK, 1:1), order_number, production_specs (jsonb), expected_completion_date, assigned_factory_staff, pdf_url, status (`pending`, `in_production`, `completed`)

### 2.8 `purchase_orders`
- id, pipeline_id (FK, 1:1), po_number, vendor_details (jsonb), items (jsonb), total_amount, pdf_url, status (`pending`, `ordered`, `received`)

### 2.9 `step_audit_log` (tracking — explicitly requested)
- id, pipeline_id, step_name, action (`created`, `updated`, `confirmed`, `pdf_generated`), performed_by, performed_at, notes
- Every transition in every step must write a row here. This powers both the dashboard activity feed and any future compliance/audit need.

### 2.10 `notifications`
- id, user_id (recipient), title, body, type (`step_unlocked`, `assigned`, `reminder`, `admin_alert`), related_pipeline_id, is_read, created_at

### 2.11 `pdf_templates` (Admin-manageable)
- id, document_type (`quotation`, `boq`, `factory_order`, `purchase_order`), template_config (jsonb — logo, header/footer text, color scheme, field layout), is_active
- Admins should be able to update the company letterhead/template details without a code change, store the company logo in Supabase Storage and reference it here.

---

## 3. Functional Requirements by Screen/Flow

### 3.1 Authentication
- Login screen: email/username + password, "Remember me," no public registration.
- Session persistence via Supabase session tokens; auto-refresh; force logout on `is_active = false` (admin-deactivated users get signed out on next token refresh check).
- Splash screen with role-based redirect (Admin → Admin Dashboard, Sales → My Pipelines, Factory → Factory Queue, Purchase → Purchase Queue).

### 3.2 Customer Management
- Search-as-you-type customer lookup (name/phone/email) before allowing "Add New Customer," to enforce the merge/dedupe rule in §2.2.
- Customer detail screen shows **all products/pipelines under that customer** grouped together, each with its own step-progress indicator.

### 3.3 Step 1 — Quotation
- Salesperson selects customer (existing or new) → selects product → fills line items (qty, description, unit price; auto-calc subtotal/tax/total).
- Product-specific fields should be **dynamic per product** (Boom Barrier vs Heat Pump have different spec fields) — drive this from the `products.base_specs` jsonb schema so adding a new product later doesn't require new screens, just new field definitions.
- "Confirm Quotation" button → validates all required fields → sets `status = 'confirmed'`, writes audit log, generates PDF from the IZYHEAT quotation template, uploads to Storage, **unlocks Step 2 button** on the pipeline card.
- All numeric fields must validate (no negative qty/price, required fields enforced before submit, not just on blur).

### 3.4 Step 2 — BOQ
- Pre-fills known data from the confirmed quotation (customer, product, confirmed line items) — never force re-entry of data already captured.
- If a field is missing that BOQ needs (e.g., technical install specs not captured in quotation), **prompt the salesperson with an additional info form** before allowing PDF generation — implement this as a `required_fields` check per product type, not hardcoded per-screen logic, so new products can define their own BOQ requirements.
- Generates BOQ PDF on submit; unlocks Step 3.

### 3.5 Step 3 — Factory Order
- Pulls confirmed BOQ data; salesperson/admin assigns to factory; factory staff can view and update status from their own queue view.
- Generates Factory Order PDF; unlocks Step 4.

### 3.6 Step 4 — Purchase Order
- Vendor/material details entered (by purchase staff or sales, per your preference — default to **purchase role** filling this in, with sales/admin able to view).
- Generates PO PDF; on completion, sets pipeline `status = 'completed'`.

### 3.7 Step Tracking
- Every pipeline shows a 4-step horizontal progress tracker (Quotation ✅ → BOQ ⏳ → Factory ⬜ → Purchase ⬜) visible on every list/detail view.
- Tapping any **completed** step's PDF icon re-opens/downloads that step's generated PDF instantly without regenerating.

### 3.8 Notifications
- In-app notification center (bell icon, unread badge count) + push via FCM for:
  - Step unlocked for a pipeline you own
  - Admin: new customer/quotation created by any salesperson (configurable, don't spam — maybe daily digest option)
  - Reminder: pipeline stuck >X days on same step (configurable threshold, e.g., 5 business days)
- Notification preferences screen so users can mute non-critical types.

### 3.9 Excel Export
- Available to Admin (all data, filterable by salesperson/date range/product/status) and to each Sales person (their own data only).
- Export current filtered list view → `.xlsx` with proper headers, one row per pipeline, including customer, product, current step, status, dates, assigned salesperson.
- Use `excel` package, share via `share_plus` (opens native share sheet — email, WhatsApp, save to Drive, etc.).

### 3.10 Admin Dashboard
- **Time-filtered customer counts**: Today / This Week / This Month / This Year — toggle/segmented control, backed by a Supabase view or RPC function that aggregates by `created_at` of `customers` or `sales_pipelines` (clarify with stakeholders which counts as "new customer met" — likely first pipeline created date).
- **Sales leaderboard**: ranks salespeople by count of confirmed quotations / completed pipelines in the selected time range, visible **only to Admin**.
- **Pipeline funnel chart**: how many records are currently sitting at each of the 4 steps (helps spot bottlenecks).
- **Per-salesperson drill-down**: tap a name on the leaderboard → see everything that person created.
- Use `fl_chart` or `syncfusion_flutter_charts` for visuals — bar chart for leaderboard, funnel/stacked bar for pipeline stage distribution, line chart for trend over time.

### 3.11 Sales (non-admin) Dashboard
- Same time-filters, but scoped to only their own customers/pipelines — "your numbers," no visibility into colleagues.

---

## 4. Validation & Data Integrity Rules
- All forms use Flutter `Form` + `TextFormField` validators — no field saves without passing validation (required fields, numeric ranges, valid email/phone format, GST format if entered).
- Prevent duplicate customer creation as described in §2.2.
- Server-side validation via Postgres `CHECK` constraints and RLS as the source of truth — never trust client-only validation for a record that affects money (quotation totals, PO amounts) — recompute/verify totals server-side in an Edge Function before marking a quotation "confirmed."
- Optimistic UI updates with rollback on Supabase error (don't let the UI silently lie about save success).
- All PDF generation should fail loudly (visible error + retry) rather than silently producing a blank/broken PDF.

## 5. Security Requirements
- Supabase RLS enabled and tested on every table — explicitly write and test policies for: a salesperson cannot read another salesperson's `customers`/`sales_pipelines` rows; factory/purchase roles cannot read `quotations`/`boqs` content; only admin role can `INSERT`/`UPDATE` on `profiles` (user creation/deactivation).
- Store Supabase keys using `flutter_dotenv` or `--dart-define`, never hardcoded in source; do not commit the service-role key into the app at all — service-role-only operations (like admin user creation) must run server-side in a Supabase Edge Function, never in the Flutter client.
- Enforce strong password policy on account creation (min length, complexity) at Admin-creation time.
- Auto-logout after configurable inactivity period (e.g., 30 min) for shared/office devices.
- All file uploads (PDFs, logos) go through Supabase Storage with bucket-level RLS, not public-write buckets.

## 6. Non-Functional Requirements
- **Responsive**: must work cleanly on a range of Android/iOS phone sizes and at least gracefully on tablets (use `LayoutBuilder`/responsive breakpoints, not fixed pixel layouts).
- **Offline tolerance**: forms should not lose user input if connectivity drops mid-fill — cache draft form state locally (e.g., `hive` or `shared_preferences`) and sync on reconnect; show a clear "offline — will sync" indicator rather than failing silently.
- **Performance**: paginate all list views (customers, pipelines) server-side via Supabase `.range()`, never load the whole table client-side.
- **Error handling**: global error boundary/toast system; no raw exception text shown to end users.
- **Theming**: clean, professional look using IZYHEAT brand colors/logo (request brand assets — primary color, logo file — as an input before final styling pass); consistent typography and spacing system, not default Material/iOS look.
- **Testing**: include widget tests for all forms and at least integration-level tests for the Quotation→BOQ unlock flow and RLS-based data isolation between two sales accounts.
- **CI-readiness**: structure the Flutter project so it can build via `flutter build apk`/`flutter build ios` cleanly with no manual fix-up steps; include a `.env.example` and clear `README` setup instructions for Supabase project linking.

## 7. Suggested Build Order (for Antigravity to sequence its own work)
1. Supabase schema + RLS policies + seed data (roles, sample products)
2. Flutter project scaffold + auth flow + role-based routing
3. Customer module (search/dedupe/create/merge view)
4. Step 1 Quotation (form → confirm → PDF → unlock gate)
5. Step 2 BOQ (prefill → dynamic extra fields → PDF → unlock gate)
6. Step 3 Factory Order, Step 4 Purchase Order (same pattern)
7. Step tracker UI component (reusable across all list/detail screens)
8. Notifications (in-app center first, then FCM wiring)
9. Excel export
10. Admin dashboard + leaderboard + charts
11. Security hardening pass (RLS test suite, auto-logout, input validation audit)
12. Polish pass: theming, responsive QA, empty/loading/error states everywhere

---

## 8. Open Items to Confirm Before/During Build
- IZYHEAT logo, brand color palette, and exact PDF template layouts (header/footer text, terms & conditions boilerplate) for each of the 4 document types — provide as image/PDF samples if available.
- Exact numbering format desired for Quotation/BOQ/Factory Order/PO numbers (prefix, year, sequence reset rules).
- Whether Purchase Order should be filled by Sales or by a dedicated Purchase role (defaulted above to Purchase role — confirm).
- Tax rules (single GST rate vs CGST/SGST/IGST split) for India-based invoicing, since totals must be computed correctly.
- List of additional products beyond Boom Barrier/Heat Pump expected in the near term, to confirm the dynamic-field approach covers their spec variability.
