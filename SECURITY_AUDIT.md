# Security & Quality Assurance Audit Report: IZYHEAT Sales App

**Application Name:** salesapp (`com.izyheat.salesapp`)  
**Target Platforms:** Android, Windows Desktop (with Web/iOS stubs)  
**Lead Auditors:** Senior Flutter Security Engineer & Lead QA Engineer  
**Date of Audit:** November 2026  
**Scope:** `lib/features/` (all 22 modules: `admin`, `amc`, `assigned_work`, `auth`, `boq`, `complaints`, `crm`, `customer_app`, `customers`, `daily_tasks`, `dashboard`, `factory_order`, `installations`, `notifications`, `pdf_search`, `pipelines`, `project_manager`, `purchase_order`, `quotation`, `quotation_generator`, `reports`, `sales_order`), `lib/core/`, `pubspec.yaml`, `android/`, `windows/`, and Supabase backend migrations (`supabase/migrations/`).

---

## Executive Summary

A comprehensive, zero-modification security and reliability audit was conducted across the entire codebase of the IZYHEAT sales application. 

The audit revealed severe security flaws, including:
1. **Critical hardcoded credentials** (Razorpay Live Key Secret, Supabase Anon JWT, Google Maps API Key).
2. **Total server-side authorization breakdown** in Supabase PostgreSQL RLS migrations (where `create_new_user` and `edit_existing_user` RPCs are granted to `anon` without authentication, and critical tables such as `sales_pipelines`, `crm_leads`, and `quotations` allow unvetted anonymous or authenticated read/write access).
3. **Plaintext credential storage** in database columns (`profiles.password`, `profiles.plain_password`, `technicians.password`) readable by anonymous or low-privilege users.
4. **Financial logic circumvention** allowing end-users to mark invoices as `paid` directly from client-side code, including a functional "Simulate Test Success" gateway bypass in the client UI.
5. **Insecure local session storage** relying on plaintext `SharedPreferences` instead of encrypted hardware-backed keychains (`flutter_secure_storage`), permitting client-side role elevation.
6. **Platform release issues** on Android (signing release builds with debug keystore, auto-backup enabled, absence of R8/ProGuard obfuscation).

---

## Folders Covered in Audit

All 22 feature folders and platform configurations have been audited:
- [x] `lib/core/config/`
- [x] `lib/core/services/`
- [x] `lib/core/router/`
- [x] `lib/core/models/`, `lib/core/providers/`, `lib/core/widgets/`, `lib/core/utils/`
- [x] `lib/features/admin/`
- [x] `lib/features/amc/`
- [x] `lib/features/assigned_work/`
- [x] `lib/features/auth/`
- [x] `lib/features/boq/`
- [x] `lib/features/complaints/`
- [x] `lib/features/crm/`
- [x] `lib/features/customer_app/`
- [x] `lib/features/customers/`
- [x] `lib/features/daily_tasks/`
- [x] `lib/features/dashboard/`
- [x] `lib/features/factory_order/`
- [x] `lib/features/installations/`
- [x] `lib/features/notifications/`
- [x] `lib/features/pdf_search/`
- [x] `lib/features/pipelines/`
- [x] `lib/features/project_manager/`
- [x] `lib/features/purchase_order/`
- [x] `lib/features/quotation/`
- [x] `lib/features/quotation_generator/`
- [x] `lib/features/reports/`
- [x] `lib/features/sales_order/`
- [x] `android/`
- [x] `windows/`
- [x] `pubspec.yaml`
- [x] `supabase/migrations/`

---

## Top 10 Prioritized Vulnerabilities

| Priority | Severity | Category | Affected Component | Description |
| :--- | :--- | :--- | :--- | :--- |
| **#1** | **CRITICAL** | Authorization / Remote Admin Takeover | `supabase/migrations/034_fix_auth_users_schema_tokens.sql:319-320` | `public.edit_existing_user` and `public.create_new_user` RPCs are granted to `anon` without authentication or authorization checks. Any attacker with the anon key can create new admin accounts or overwrite passwords/roles of existing admins. |
| **#2** | **CRITICAL** | Secrets Exposure | `lib/core/config/app_config.dart:29` | Hardcoded Razorpay Secret Key (`PilWo0tvB7RvaEuzcL4CAJFo`) inside the client binary. Allows arbitrary refund issuance, capture manipulation, and funds exfiltration via Razorpay REST API. |
| **#3** | **CRITICAL** | Business Logic / Payment Bypass | `lib/core/services/payment_service.dart:347,712` & `lib/features/customer_app/data/repositories/app_repositories.dart:2176-2182` | "Simulate Test Success" UI button triggers callback that executes `update({'status': 'paid'})` directly from client device without server-side webhook or signature verification. |
| **#4** | **CRITICAL** | Plaintext Password Exposure | `supabase/migrations/034_fix_auth_users_schema_tokens.sql:263` & `021_fix_supabase_linter_security_warnings.sql:372` | Plaintext passwords are saved in `profiles.password`/`plain_password` and `technicians.password`. Anonymous users can select all technicians (`technicians_select` policy allows `anon`), exposing plaintext passwords. |
| **#5** | **CRITICAL** | Database Authorization Breakdown | `supabase/migrations/021_fix_supabase_linter_security_warnings.sql:331-342` | RLS policies replaced with blanket `auth.role() IN ('anon', 'authenticated')` and `auth.role() = 'authenticated'`. Anonymous users can update quotations; any authenticated user can read and modify all sales pipelines and alter audit logs. |
| **#6** | **HIGH** | Authentication / Privilege Escalation | `lib/features/auth/providers/auth_provider.dart:43-80, 290-312` | User profile and roles are cached in unencrypted `SharedPreferences`. On launch, the app reads `staff_session_roles` from disk and grants role permissions before Supabase auth emits, allowing local role spoofing. |
| **#7** | **HIGH** | Broken Access Control | `lib/core/router/app_router.dart:190-205` | `isCustomerRoute` guard returns `null` unconditionally, allowing unauthenticated users to access `/customer/dashboard`, `/bookings`, `/invoices`, and customer profiles. |
| **#8** | **HIGH** | Android Release Build Flaws | `android/app/build.gradle.kts:49` & `android/app/src/main/AndroidManifest.xml:9` | Release builds use debug keystore signing (`signingConfig = signingConfigs.getByName("debug")`), ProGuard/R8 is disabled, and `android:allowBackup` is omitted (defaulting to true, allowing `adb backup` of tokens/DBs). |
| **#9** | **HIGH** | Data Leakage / Full Table Scraping | `lib/features/customer_app/data/repositories/app_repositories.dart:659-664` | In fallback mock mode, `getUserProfile` executes `_supabase.from('customer_profiles').select()` without server filters, downloading the entire customer database to the client device to filter in Dart memory. |
| **#10** | **HIGH** | Data Loss / Destructive Logic | `lib/features/amc/screens/amc_setup_form_screen.dart:563-570` | Re-saving an existing AMC contract unconditionally executes `.delete().eq('amc_contract_id', amcId)` on `amc_service_visits`, permanently deleting completed service visits, technician notes, and historical audit logs. |

---

## Detailed Findings by Feature Folder

### 1. `core/config/`

| Severity | File:Line | Issue | Why it matters | Suggested fix |
| :--- | :--- | :--- | :--- | :--- |
| **CRITICAL** | `lib/core/config/app_config.dart:29` | Hardcoded Razorpay Key Secret in default compile-time constant | Anyone decompiling the Android APK or inspecting the Windows binary can extract `PilWo0tvB7RvaEuzcL4CAJFo` and access merchant payment APIs, initiate fake captures, or execute unauthorized refunds. | Remove `razorpayKeySecret` completely from Flutter code. Razorpay secret key operations must execute exclusively in a backend environment (e.g., Supabase Edge Functions). |
| **HIGH** | `lib/core/config/app_config.dart:8-14` | Hardcoded Supabase URL & Anon Key JWT | The anon key is permanently embedded in source control and compiled binaries. While anon keys are intended to be public, pairing them with weak RLS grants full DB access. | Maintain strictly hardened RLS policies; inject keys via secure CI/CD `--dart-define-from-file` rather than committing defaults in version control. |
| **MEDIUM** | `lib/core/config/app_config.dart:19` | Hardcoded Google Maps API Key | Client API key has no package name or HTTP referrer restrictions, allowing quota theft and billing abuse. | Restrict the API key in Google Cloud Console to `com.izyheat.salesapp` SHA-1 fingerprint and package name. |

---

### 2. `core/services/`

| Severity | File:Line | Issue | Why it matters | Suggested fix |
| :--- | :--- | :--- | :--- | :--- |
| **CRITICAL** | `lib/core/services/payment_service.dart:347,712` | "Simulate Test Success" dialog button in payment gateway flow | Clicking "Simulate Test Success" executes `_onSuccess?.call(...)`, which updates database records and marks orders or invoices as paid without real money. | Remove test simulation buttons from production code entirely; gate behind `if (kDebugMode)` or compile-time flags. |
| **CRITICAL** | `lib/core/services/payment_service.dart:456-462, 531-536` | Windows Desktop UPI flow sends basic auth with Razorpay Key Secret from desktop client | The client app transmits `Basic base64(key_id:key_secret)` over the wire to `api.razorpay.com`. Network interception or memory dumping exposes merchant credentials. | Delegate QR generation and status polling to a secure backend endpoint or Supabase Edge Function. |
| **HIGH** | `lib/core/services/auth_service.dart:89-135, 235-275` | Client-side OTP generation and verification | The OTP is generated in device memory and validated in device memory (`computedHash == _hashedOtp`). Attackers can hook the method or bypass client validation. | Move OTP generation, SMS dispatch, and verification to a server-side endpoint (Supabase Auth / Edge Functions). |
| **MEDIUM** | `lib/core/services/auth_service.dart:229` | Plaintext OTP output via `print()` | `print()` outputs OTP directly to system logcat/console on Android/Windows, exposing verification codes to log-monitoring utilities. | Remove `print` statements or replace with `debugPrint` inside `kDebugMode` checks. |
| **MEDIUM** | `lib/core/services/storage_service.dart:44-48` | Public URLs returned for private complaint & installation photos; silent error swallowing | Photos containing private customer residences, addresses, and installation serials are stored in public storage; network failures return `null` silently. | Use authenticated private buckets with signed, time-limited URLs; bubble up storage errors to UI. |
| **MEDIUM** | `lib/core/services/offline_queue_service.dart:22-35, 64` | Unencrypted Hive box for offline queue; single item error halts queue permanently | Customer PII stored offline in plaintext; if one queue item fails constraint validation, `break;` leaves it in the queue, halting all offline syncs. | Use encrypted Hive box (`HiveAesCipher`); implement dead-letter queue / retry counters instead of halting. |
| **LOW** | `lib/core/services/notification_backend_helper.dart:18` | `.inFilter('role', roles)` does not query multi-role array `roles` | Staff members who possess target roles as secondary roles in `profiles.roles` will not be returned and miss operational notifications. | Use PostgreSQL array overlap query (`.contains('roles', [role])` or `.overlaps(...)`). |

---

### 3. `core/router/`

| Severity | File:Line | Issue | Why it matters | Suggested fix |
| :--- | :--- | :--- | :--- | :--- |
| **HIGH** | `lib/core/router/app_router.dart:190-205` | Unauthenticated customer routes | `if (isCustomerRoute) return null;` is placed before `isLoggedIn` checks. Anyone can browse to `/customer/dashboard`, `/bookings`, `/track`, and `/invoices` without logging in. | Enforce authentication checks on customer routes or redirect to `/login` / `/otp`. |
| **MEDIUM** | `lib/core/router/app_router.dart:228-299` | Role access checks performed only at navigation layer | If a user discovers internal deep links or triggers RPCs/queries directly via PostgREST, client-side router checks do not protect backend data. | Enforce RBAC in Supabase RLS and server-side RPCs in tandem with GoRouter guards. |

---

### 4. `features/admin/`

| Severity | File:Line | Issue | Why it matters | Suggested fix |
| :--- | :--- | :--- | :--- | :--- |
| **CRITICAL** | `lib/features/admin/screens/user_management_screen.dart:677,928,1116` | Relies on RPCs (`create_new_user`, `edit_existing_user`, `delete_existing_user`) that lack server-side admin role enforcement | The admin screen assumes only admins can reach it, but the underlying database RPCs allow execution by `anon` and unauthenticated callers. | Alter RPCs in PostgreSQL to require `auth.uid()` verification against `profiles.role = 'admin'` or use Supabase Service Role key inside an Edge Function. |
| **HIGH** | `lib/features/admin/screens/user_roles_editor_screen.dart:150-180` | Client-side role string array manipulation | Modifying user roles sends updates directly to `profiles.roles` without verifying admin hierarchy. | Enforce server-side validation that prevents non-superadmins from assigning `admin` role. |
| **MEDIUM** | `lib/features/admin/screens/product_catalog_screen.dart:210` | Unsafe type cast on dynamic product JSON fields | `p['specs'] as Map<String, dynamic>` without null check causes runtime crash when loading newly migrated products with null specs. | Use safe null-aware mapping: `(p['specs'] as Map?)?.cast<String, dynamic>() ?? {}`. |

---

### 5. `features/amc/`

| Severity | File:Line | Issue | Why it matters | Suggested fix |
| :--- | :--- | :--- | :--- | :--- |
| **HIGH** | `lib/features/amc/screens/amc_setup_form_screen.dart:563-570` | Unconditional deletion of existing service visits upon contract update | Re-editing an active contract deletes all records from `amc_service_visits`, destroying completed technician visit history and customer signoffs. | Only delete visits with `status = 'scheduled'`; preserve visits marked as `completed` or `in_progress`. |
| **MEDIUM** | `lib/features/amc/screens/amc_setup_form_screen.dart:46, 342` | Leap year date calculation bug | `DateTime(_startDate.year + yrs, _startDate.month, _startDate.day)` evaluates Feb 29 on non-leap years to March 1, creating subtle contract date discrepancies. | Use date math utility that clamps end date to the last valid day of the target month. |
| **LOW** | `lib/features/amc/screens/service_visit_form_screen.dart:120` | Unchecked text controller inputs for visit notes | Empty submission can create blank service visit audit trails. | Add form validator requiring technician summary notes and photo before completion. |

---

### 6. `features/assigned_work/`

| Severity | File:Line | Issue | Why it matters | Suggested fix |
| :--- | :--- | :--- | :--- | :--- |
| **MEDIUM** | `lib/features/assigned_work/presentation/screens/assigned_work_screen.dart:95-120` | Stream subscription memory leak in tab switching | Subscribing to live assigned work streams without proper cancellation on widget dispose leaks listeners when switching navigation tabs. | Use Riverpod `ref.watch` on an autoDispose StreamProvider instead of manual subscriptions in State. |
| **LOW** | `lib/features/assigned_work/data/assigned_work_repository.dart:65` | Missing error handling on batch status update | Batch status updates on work assignments fail silently without informing the user if offline. | Wrap in `try/catch` and emit state error to display snackbar/toast to the user. |

---

### 7. `features/auth/`

| Severity | File:Line | Issue | Why it matters | Suggested fix |
| :--- | :--- | :--- | :--- | :--- |
| **CRITICAL** | `lib/features/auth/providers/auth_provider.dart:412-421` | Plaintext password query and verification for technicians | Client queries `technicians` table where `password` column is stored in plain text and compares `techPass == password.trim()`. | Store passwords hashed with bcrypt in `auth.users` only; never store plaintext passwords in table columns. |
| **HIGH** | `lib/features/auth/providers/auth_provider.dart:43-80, 290-312` | Unencrypted session storage in SharedPreferences & initial role assumption | The app saves `staff_session_roles` in plaintext and yields it on boot. A rooted Android device or Windows user can alter the XML/registry to grant themselves `admin`. | Store session tokens in `flutter_secure_storage`; never authorize permissions from unverified local cache without server token validation. |
| **HIGH** | `lib/features/auth/providers/auth_provider.dart:399` | Attempted primary key update on `profiles.id` | Updating `profiles.id` from client can break foreign keys referencing that profile across pipelines, quotations, and complaints. | Create profiles with auth UID as primary key from the outset via PostgreSQL trigger. |

---

### 8. `features/boq/`

| Severity | File:Line | Issue | Why it matters | Suggested fix |
| :--- | :--- | :--- | :--- | :--- |
| **HIGH** | `lib/features/boq/screens/boq_form_screen.dart:250` | Double-submit / race condition on BOQ creation | Rapid double-tapping "Submit & Generate PDF" or network retries can insert multiple BOQ rows for the same pipeline. | Enforce a unique constraint on `boqs(pipeline_id)` in SQL and disable submit button synchronously upon initial tap. |
| **MEDIUM** | `lib/features/boq/screens/boq_form_screen.dart:55-59` | Controller disposal in dynamically resized list | Removing BOQ rows dynamically during editing does not dispose individual item `TextEditingController` instances, leaking memory during extensive edits. | Dispose controllers when a row is removed from `_boqItems` before removing it from the list. |
| **LOW** | `lib/features/boq/screens/boq_form_screen.dart:230` | Fallback qty defaults to 1 on parse error | Invalid characters in quantity field silently convert to 1 without user notice. | Add strict regex validator `r'^\d+(\.\d+)?$'` to quantity form fields. |

---

### 9. `features/complaints/`

| Severity | File:Line | Issue | Why it matters | Suggested fix |
| :--- | :--- | :--- | :--- | :--- |
| **HIGH** | `lib/features/complaints/screens/book_complaint_screen.dart:384-389` | Base64 image upload silent failure | Upload errors are swallowed in empty `catch (_) {}`. The complaint is created with `finalUrls = []`, permanently losing attached photos. | Notify user that photo upload failed and prompt retry before creating complaint record. |
| **HIGH** | `lib/features/complaints/screens/book_complaint_screen.dart:386` | Storing raw high-res images as base64 strings in widget state | Storing multiple 5-10MB base64 strings in memory causes Out-Of-Memory (OOM) crashes on Android devices. | Compress images via `flutter_image_compress` and upload directly from file stream/Uint8List rather than caching full base64 strings. |
| **MEDIUM** | `lib/features/complaints/screens/book_complaint_screen.dart:426, 438` | Force unwrap `!` on `_selectedCustomer` and `_selectedTechnician` | If customer state is cleared or technician not found, `!` triggers unhandled `Null check operator used on a null value`. | Add guard checks with user-friendly error banners before accessing properties. |

---

### 10. `features/crm/`

| Severity | File:Line | Issue | Why it matters | Suggested fix |
| :--- | :--- | :--- | :--- | :--- |
| **HIGH** | `lib/features/crm/screens/lead_detail_screen.dart:100` | Inconsistent `isAdmin` definition grants manager write permissions | Line 100 includes `UserRole.manager` in `isAdmin`, contradicting strict read-only policy for managers defined elsewhere in the app. | Unify permission checks through `RecordEditPermissions` and remove manager from `isAdmin` checks. |
| **MEDIUM** | `lib/features/crm/screens/prospects_list_screen.dart:150` | Unsanitized search queries in PostgREST `.or()` filters | Special characters (commas, single quotes) in search input distort PostgREST query syntax. | Sanitize query inputs or use parameterized `.textSearch()` / `.ilike()` calls. |
| **LOW** | `lib/features/crm/screens/crm_dashboard_screen.dart:1551` | Absence of undo on CRM source deletion | Deleting a source deletes it immediately without soft delete or confirmation of linked leads. | Add check to prevent deleting CRM sources currently assigned to active leads. |

---

### 11. `features/customer_app/`

| Severity | File:Line | Issue | Why it matters | Suggested fix |
| :--- | :--- | :--- | :--- | :--- |
| **CRITICAL** | `lib/features/customer_app/data/repositories/app_repositories.dart:2176-2182` | Client-driven direct invoice status update to `paid` | Client calls `_supabase.from('invoices').update({'status': 'paid'})`. Any authenticated customer can mark their invoices paid via PostgREST without paying. | Restrict `invoices` update policy in SQL. Only verify payments server-side via Razorpay webhook. |
| **CRITICAL** | `lib/features/customer_app/data/repositories/app_repositories.dart:659-664` | Bulk download of entire `customer_profiles` table | `_supabase.from('customer_profiles').select()` fetches all customer records to filter by phone in Flutter memory, leaking customer PII. | Query specifically by exact phone number: `.eq('phone', cleanPhone).limit(1)`. |
| **HIGH** | `lib/features/customer_app/data/repositories/app_repositories.dart:576-583` | Mock mode sets synthetic UID without server authentication | Setting `_mockUid = 'mock-user-...'` in SharedPreferences allows spoofed login without valid OTP from backend. | Disallow client-side synthetic mock mode in production builds. |

---

### 12. `features/customers/`

| Severity | File:Line | Issue | Why it matters | Suggested fix |
| :--- | :--- | :--- | :--- | :--- |
| **HIGH** | `lib/features/customers/screens/create_customer_screen.dart:180-210` | Offline customer creation missing conflict handling | Creating customer offline queues write; if duplicate phone exists when syncing, queue crashes or duplicate customer is created. | Implement upsert or phone number deduplication logic in offline sync handler. |
| **MEDIUM** | `lib/features/customers/services/customer_documents_service.dart:85` | Unsafe file paths on Windows desktop | Constructing paths with forward slashes without platform path normalization can fail on Windows file operations. | Use `p.join(...)` from `package:path` for all cross-platform file paths. |

---

### 13. `features/daily_tasks/`

| Severity | File:Line | Issue | Why it matters | Suggested fix |
| :--- | :--- | :--- | :--- | :--- |
| **MEDIUM** | `lib/features/daily_tasks/screens/daily_tasks_screen.dart:53` | Riverpod notifier modification during dispose lifecycle | Calling `ref.read(...notifier).update(...)` inside `dispose()` can trigger framework lifecycle warnings or exceptions if widget tree is unmounting. | Perform state cleanup in `deactivate()` or reset provider state when leaving the route. |
| **LOW** | `lib/features/daily_tasks/screens/daily_tasks_screen.dart:1302` | Unmanaged controller in sub-widget dialog | Dialog controller disposed without checking if widget is mounted. | Verify standard lifecycle binding inside dialog state. |

---

### 14. `features/dashboard/`

| Severity | File:Line | Issue | Why it matters | Suggested fix |
| :--- | :--- | :--- | :--- | :--- |
| **MEDIUM** | `lib/features/dashboard/screens/admin_dashboard_screen.dart:180-220` | Division by zero in conversion rate calculations | If lead or deal count is 0, `(wonDeals / totalDeals) * 100` can yield `NaN` or `Infinity`, causing UI render crashes in Flutter text widgets. | Guard all ratios: `totalDeals > 0 ? (wonDeals / totalDeals) * 100 : 0.0`. |
| **LOW** | `lib/features/dashboard/screens/sales_dashboard_screen.dart:95` | Redundant full dataset re-fetching on pull-to-refresh | Invalidate calls trigger full queries without pagination, increasing egress costs and lag on poor cellular connections. | Implement date-bounded limit queries for dashboard metric summaries. |

---

### 15. `features/factory_order/`

| Severity | File:Line | Issue | Why it matters | Suggested fix |
| :--- | :--- | :--- | :--- | :--- |
| **HIGH** | `lib/features/factory_order/screens/factory_order_screen.dart:369-370` | Direct pipeline advancement from client | Client directly executes `sales_pipelines.update({'current_step': 'purchase_order'})`. A user can skip factory production by sending this query. | Restrict step advancement via PostgreSQL trigger or check functions that enforce valid stage transitions. |
| **MEDIUM** | `lib/features/factory_order/screens/factory_order_screen.dart:359` | Unsafe cast `(res as Map)['id']` | If Supabase returns empty response or error format, direct casting to `Map` throws `TypeError`. | Use `if (res is Map<String, dynamic> && res.containsKey('id'))`. |

---

### 16. `features/installations/`

| Severity | File:Line | Issue | Why it matters | Suggested fix |
| :--- | :--- | :--- | :--- | :--- |
| **MEDIUM** | `lib/features/installations/screens/book_installation_screen.dart:358-361` | Wrong bucket used (`complaint-photos` instead of dedicated installation bucket) | Installation photos are stored in `complaint-photos/installation_photos`, violating isolation and complicating retention policies. | Create a dedicated `installation-photos` bucket with independent storage policies. |
| **LOW** | `lib/features/installations/screens/assign_technician_screen.dart:158` | Unsafe `!` check: `complaint.technicianName!.isNotEmpty` | Throws `Null check operator` if technician name is null. | Use `complaint.technicianName?.isNotEmpty == true`. |

---

### 17. `features/notifications/`

| Severity | File:Line | Issue | Why it matters | Suggested fix |
| :--- | :--- | :--- | :--- | :--- |
| **HIGH** | `lib/core/services/notification_service.dart:98-105` | Foreground notifications do not sanitize notification payload | Direct parsing of FCM payload strings into routing without schema validation can cause deep-link injection or crashes. | Validate payload schema and route names against an allowlist before invoking `context.go()`. |
| **LOW** | `lib/features/notifications/screens/notification_center_screen.dart:140` | Lack of pagination on notification feed | Fetches all notifications for user, leading to unbounded memory growth over months of usage. | Add `.limit(50)` and cursor-based infinite scrolling. |

---

### 18. `features/pdf_search/`

| Severity | File:Line | Issue | Why it matters | Suggested fix |
| :--- | :--- | :--- | :--- | :--- |
| **HIGH** | `lib/features/pdf_search/screens/search_pdf_screen.dart:248, 281` | Unsanitized query string interpolation in PostgREST `.or()` | `q.or('quotation_number.ilike.%$padded,quotation_number.ilike.%/$query')` allows malformed queries or injection of PostgREST operators. | Strip special PostgREST control characters (`(`, `)`, `,`, `.`) or use exact pattern matching. |
| **MEDIUM** | `lib/features/pdf_search/screens/search_pdf_screen.dart:253, 286` | Unsafe map casts on joined relations | `(row['sales_pipelines'] as Map<String, dynamic>?)` throws if relation returns a list instead of a single object (e.g. 1-to-many join). | Safely inspect type: `row['sales_pipelines'] is Map ? row['sales_pipelines'] : null`. |

---

### 19. `features/pipelines/`

| Severity | File:Line | Issue | Why it matters | Suggested fix |
| :--- | :--- | :--- | :--- | :--- |
| **HIGH** | `lib/features/pipelines/screens/pipeline_detail_screen.dart:310-340` | Client-enforced pipeline stage transitions | Users can click unlocked steps or call updates out of sequence because server-side RLS permits blanket updates. | Implement a state machine in PostgreSQL triggers that validates `current_step` progression. |
| **MEDIUM** | `lib/features/pipelines/screens/pipeline_list_screen.dart:180` | Memory accumulation in real-time stream listener | Real-time subscription to `sales_pipelines` does not throttle rapid updates, causing continuous re-rendering under high activity. | Apply `.debounce()` on stream emissions before updating Riverpod state. |

---

### 20. `features/project_manager/`

| Severity | File:Line | Issue | Why it matters | Suggested fix |
| :--- | :--- | :--- | :--- | :--- |
| **HIGH** | `lib/features/project_manager/data/repositories/pm_projects_repository.dart:39-40` | Unbounded `inFilter` list parameter length | Passing hundreds of project IDs into `inFilter('project_id', projectIds)` generates HTTP GET requests that exceed server URI length limits (414 URI Too Long). | Batch queries into chunks of 50 or execute an RPC / inner join view directly in PostgreSQL. |
| **MEDIUM** | `lib/features/project_manager/data/repositories/pm_projects_repository.dart:19` | `customers!inner` join silently drops orphaned projects | If a customer is deleted, soft-deleted, or missing, the inner join excludes the project completely from the listing. | Use left outer join `customers (...)` and handle null customer in model parsing. |

---

### 21. `features/purchase_order/`

| Severity | File:Line | Issue | Why it matters | Suggested fix |
| :--- | :--- | :--- | :--- | :--- |
| **HIGH** | `lib/features/purchase_order/screens/purchase_order_screen.dart:273, 302` | Unsafe `supabase.auth.currentUser!.id` assertions | Throws null-check exception if user session is interrupted or in offline/mock mode during order placement. | Guard with `final uid = supabase.auth.currentUser?.id; if (uid == null) throw ...`. |
| **MEDIUM** | `lib/features/purchase_order/screens/purchase_order_screen.dart:280-281` | Unchecked `.single()` query throws unhandled exception on missing record | If pipeline is deleted concurrently, `.single()` throws `PostgrestException` with unhandled crash dialog. | Use `.maybeSingle()` and verify record existence before processing completion. |

---

### 22. `features/quotation/` & `quotation_generator/`

| Severity | File:Line | Issue | Why it matters | Suggested fix |
| :--- | :--- | :--- | :--- | :--- |
| **CRITICAL** | `lib/features/quotation/screens/quotation_form_screen.dart:1483-1501` | Quotation approval enforced only client-side | The code checks `profile?.primaryRole == UserRole.salesHead`, but Supabase RLS allows the creator sales executive to execute `update({'status': 'confirmed', 'approved_by': auth.uid()})` directly. | Enforce approval privileges in PostgreSQL RLS `WITH CHECK (get_my_role() IN ('sales_head', 'admin'))`. |
| **HIGH** | `lib/features/quotation_generator/services/price_calculator.dart:238-242` | `numberToWords` throws `RangeError` on quotes >= 100 Crore | `tens[n ~/ 10]` accesses index 10 on numbers with 100+ Crore, throwing `RangeError` and crashing PDF generation. | Handle 3-digit crore grouping using `threeDigits(crores)` instead of `twoDigits(crores)`. |
| **MEDIUM** | `lib/features/quotation_generator/services/price_calculator.dart:104, 123` | Integer division `~/` causes invoice line item total discrepancies | `rate = sub ~/ qty` truncates decimals. For subtotal ₹100 and qty 3, rate becomes ₹33, but `3 * 33 = 99 != 100`. | Store rates and amounts with 2 decimal precision; adjust last line item or add explicit rounding row. |

---

### 23. `features/reports/`

| Severity | File:Line | Issue | Why it matters | Suggested fix |
| :--- | :--- | :--- | :--- | :--- |
| **HIGH** | `lib/features/reports/screens/user_activity_report_screen.dart:88` | `get_all_staff_profiles()` RPC exposes staff metadata to all authenticated users | Any authenticated user (including customer accounts) can invoke this SECURITY DEFINER function to scrape staff IDs, emails, phone numbers, and roles. | Add role verification inside the SQL function: `IF get_my_role() NOT IN ('admin', 'sales_head', 'manager') THEN RAISE EXCEPTION 'Access Denied';`. |
| **LOW** | `lib/features/reports/screens/customer_report_screen.dart:89` | WhatsApp launch without URL encoding | Constructing `https://wa.me/$fullNumber` fails if phone contains unstripped spaces or non-numeric characters. | Use `cleanPhone.replaceAll(RegExp(r'\D'), '')` before parsing URL. |

---

### 24. `features/sales_order/`

| Severity | File:Line | Issue | Why it matters | Suggested fix |
| :--- | :--- | :--- | :--- | :--- |
| **MEDIUM** | `lib/features/sales_order/screens/sales_order_form_screen.dart:276` | Floating-point rounding inaccuracies in financial totals | `total += (qty * rate) * (1 - disc / 100)` uses standard double math, leading to IEEE 754 precision issues (e.g. ₹0.01 round-off errors). | Round line item totals explicitly to 2 decimal places before summing. |
| **LOW** | `lib/features/sales_order/screens/sales_order_form_screen.dart:729` | Unsafe map cast on insert response | `(response as Map)['id']` can fail on malformed network payloads. | Safely cast: `(response as Map<String, dynamic>)['id'] as String`. |

---

### 25. Platform & Dependencies (`android/`, `windows/`, `pubspec.yaml`)

| Severity | File:Line | Issue | Why it matters | Suggested fix |
| :--- | :--- | :--- | :--- | :--- |
| **HIGH** | `android/app/build.gradle.kts:49` | Release builds signed with debug keystore | Debug keys are well-known and public. Tampered APKs can be redistributed and installed as updates. | Configure a dedicated production keystore via environment variables in `signingConfigs`. |
| **HIGH** | `android/app/build.gradle.kts:45-51` | Absence of R8 / ProGuard code shrinking & obfuscation | Source code, models, and endpoints can be reconstructed using tools like `apktool` and `jadx-gui`. | Enable `isMinifyEnabled = true`, `isShrinkResources = true`, and provide ProGuard rules; compile with `flutter build apk --obfuscate --split-debug-info=...`. |
| **HIGH** | `android/app/src/main/AndroidManifest.xml:9-12` | `android:allowBackup` not disabled | Defaults to `true`. Attackers with physical access or ADB debugging can dump application files, Hive offline databases, and SharedPreferences. | Set `android:allowBackup="false"` in `<application>`. |
| **MEDIUM** | `pubspec.yaml:38` | `flutter_secure_storage` missing from dependencies | Plaintext `shared_preferences` is used for sensitive credentials and session tokens. | Add `flutter_secure_storage: ^9.2.2` and migrate all token/session storage to hardware-backed keystore/keychain. |
| **LOW** | `pubspec.yaml:50, 82, 95-98` | Wildcard `any` dependencies (`file_picker`, `collection`, `freezed`, etc.) | Unpinned dependencies can pull breaking or compromised minor/major updates unexpectedly. | Pin exact version constraints (`^x.y.z`) for all production and dev dependencies. |

---

## Remediation Roadmap

1. **Immediate Database Hardening (Day 1):**
   - Revoke `EXECUTE` on `create_new_user` and `edit_existing_user` from `anon`. Add strict `get_my_role() = 'admin'` checks to all administrative functions.
   - Drop policies that grant `anon` update on `quotations` or select on `technicians`.
   - Remove plaintext `password` and `plain_password` columns from `profiles` and `technicians` tables.
2. **Secrets & Financial Remediation (Day 2):**
   - Invalidate the compromised Razorpay Key Secret in the Razorpay Dashboard.
   - Remove Razorpay secrets from `AppConfig` and client code; route all order creation and signature verification through Supabase Edge Functions.
   - Remove "Simulate Test Success" dialog options.
   - Enforce server-side verification for marking invoices as `paid`.
3. **Authentication & Session Hardening (Days 3-4):**
   - Integrate `flutter_secure_storage` for user sessions, tokens, and roles.
   - Move OTP generation and verification to Supabase Auth or a server-side endpoint.
   - Require authentication on all customer routes in `app_router.dart`.
4. **Platform & Build Security (Day 5):**
   - Configure a dedicated release keystore for Android in `build.gradle.kts`.
   - Set `android:allowBackup="false"`.
   - Enable code shrinking, ProGuard, and Flutter command-line obfuscation (`--obfuscate`).

