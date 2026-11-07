# SECRETS AUDIT & REMEDIATION REPORT

**Audit Date:** November 2026  
**Auditor:** Automated Security Specialist  
**Status:** STEP 1 COMPLETE (Read-Only Audit) — AWAITING USER APPROVAL TO APPLY FIXES  

---

## 1. Executive Summary

A comprehensive, read-only secret discovery and repository audit was conducted across the entire repository, including source files (`lib/`), build scripts (`android/`, `windows/`, `ios/`, `web/`), configurations, `.env` files, scratch directories, tool scripts, documentation, and the entire Git revision history.

### Summary of Key Findings:
- **No Supabase `service_role` key** was detected in the repository (all JWTs found correspond to `role: "anon"`).
- **Critical Secrets Leaked in Git History and Client Artifacts:**
  - **Razorpay Secret Key & Key ID** are hardcoded as default values in `lib/core/config/app_config.dart`, stored in `config.json`, committed in `SECURITY_AUDIT.md`, and compiled into tracked web distribution files (`build/web/main.dart.js`).
  - **Supabase Database Plaintext Password** was committed to Git history across multiple Python migration scripts in root and `scratch/`.
  - **WhatsApp Cloud API Access Token & Phone ID** and **Fast2SMS API Key** are hardcoded in `lib/core/config/app_config.dart`, `config.json`, and `.env`.
  - **Google Maps API Key** is hardcoded in `lib/core/config/app_config.dart`, `config.json`, and `.env`, and previously committed in `android/app/src/main/AndroidManifest.xml`.
  - **Google Services / Firebase Private Key JSON** (`insiya-salesapp-firebase-adminsdk-*.json`) exists in the project root directory; while gitignored and absent from git history, it must be safeguarded.
  - **`build/web/` is un-ignored** via `!build/web/` in `.gitignore`, causing compiled JavaScript bundles (`main.dart.js`) containing sensitive client-embedded keys to be committed into Git history across dozens of commits.
  - **`tools/migrate_pm_data.py`** and **`config.json`** are actively tracked by Git.

---

## 2. Secrets Audit Findings Table

| Severity | File:Line | Type | In git history? | Shipped in the app binary? | Action needed |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **CRITICAL** | `lib/core/config/app_config.dart:27-29` | Razorpay Key Secret | Yes (commit `ca4c2ca`) | **Yes** (compiled as default const String) | Remove default fallback value; migrate payment operations to Supabase Edge Function; rotate secret in Razorpay Dashboard. |
| **CRITICAL** | `config.json:5-6` | Razorpay Key ID & Key Secret | Yes (commit `ca4c2ca`) | No (not in Flutter assets) | Untrack with `git rm --cached`, add to `.gitignore`, purge from git history; rotate secret. |
| **CRITICAL** | `SECURITY_AUDIT.md:66, 84` | Razorpay Key Secret (Plaintext) | Yes (commit `d22a06c`) | No | Redact real secret strings immediately with placeholder `[REDACTED]`. |
| **CRITICAL** | `build/web/main.dart.js` | Compiled Razorpay Key Secret & Key ID | Yes (multiple commits, e.g. `01a68a8`, `ca4c2ca`, `b30db5e`) | **Yes** (shipped in web distribution) | Remove `!build/web/` exception from `.gitignore`; `git rm --cached -r build/web/`; purge from git history. |
| **CRITICAL** | `add_quotation_columns.py:5` (historical) | Supabase PostgreSQL Database Password | Yes (commit `c5ebb40`) | No | Password already converted to `os.environ` in working tree; purge historical commit from git history; rotate DB password in Supabase. |
| **CRITICAL** | `check_quotations.py:6` (historical) | Supabase PostgreSQL Database Password | Yes (commit `c5ebb40`) | No | Password converted to `os.environ` in working tree; purge historical commit from git history; rotate DB password. |
| **CRITICAL** | `query_db.py:6` (historical) | Supabase PostgreSQL Database Password | Yes (commit `c5ebb40`) | No | Purge historical commit from git history; rotate DB password. |
| **CRITICAL** | `update_rpc.py:52` (historical) | Supabase PostgreSQL Database Password | Yes (commit `c5ebb40`) | No | Purge historical commit from git history; rotate DB password. |
| **CRITICAL** | `scratch/apply_010_migration.py:3` (historical) | Supabase PostgreSQL Database Password | Yes (commits `0dba7b5`, `e9840d4`) | No | Purge `scratch/` from git history; ensure `scratch/` remains ignored; rotate DB password. |
| **CRITICAL** | `scratch/apply_all_schema_updates.py:3` (historical) | Supabase PostgreSQL Database Password | Yes (commits `0dba7b5`, `e9840d4`) | No | Purge from git history; rotate DB password. |
| **CRITICAL** | `scratch/apply_priority1_migrations.py:3` (historical) | Supabase PostgreSQL Database Password | Yes (commits `0dba7b5`, `e9840d4`) | No | Purge from git history; rotate DB password. |
| **CRITICAL** | `scratch/audit_data_propagation.py:3` (historical) | Supabase PostgreSQL Database Password | Yes (commits `0dba7b5`, `e9840d4`) | No | Purge from git history; rotate DB password. |
| **CRITICAL** | `scratch/check_complaints_rls.py:3` (historical) | Supabase PostgreSQL Database Password | Yes (commits `0dba7b5`, `e9840d4`) | No | Purge from git history; rotate DB password. |
| **CRITICAL** | `scratch/check_counts.py:3` (historical) | Supabase PostgreSQL Database Password | Yes (commits `0dba7b5`, `e9840d4`) | No | Purge from git history; rotate DB password. |
| **CRITICAL** | `scratch/check_pipeline_rls.py:3` (historical) | Supabase PostgreSQL Database Password | Yes (commits `0dba7b5`, `e9840d4`) | No | Purge from git history; rotate DB password. |
| **CRITICAL** | `scratch/check_readable_rls.py:3` (historical) | Supabase PostgreSQL Database Password | Yes (commits `0dba7b5`, `e9840d4`) | No | Purge from git history; rotate DB password. |
| **CRITICAL** | `scratch/check_technicians.py:3` (historical) | Supabase PostgreSQL Database Password | Yes (commits `0dba7b5`, `e9840d4`) | No | Purge from git history; rotate DB password. |
| **CRITICAL** | `scratch/inspect_products_inventory.py:3` (historical) | Supabase PostgreSQL Database Password | Yes (commits `0dba7b5`, `e9840d4`) | No | Purge from git history; rotate DB password. |
| **CRITICAL** | `scratch/inspect_sources.py:3` (historical) | Supabase PostgreSQL Database Password | Yes (commits `0dba7b5`, `e9840d4`) | No | Purge from git history; rotate DB password. |
| **CRITICAL** | `scratch/inspect_tables.py:3` (historical) | Supabase PostgreSQL Database Password | Yes (commits `0dba7b5`, `e9840d4`) | No | Purge from git history; rotate DB password. |
| **CRITICAL** | `scratch/test_leaderboard_query.py:3` (historical) | Supabase PostgreSQL Database Password | Yes (commits `0dba7b5`, `e9840d4`) | No | Purge from git history; rotate DB password. |
| **HIGH** | `insiya-salesapp-firebase-adminsdk-fbsvc-4347c34ec2.json:5` | Google Service Account Private Key | No | No | Ignored by pattern; keep strictly in `.gitignore`; rotate private key in Google Cloud/Firebase console if shared outside secure environment. |
| **HIGH** | `lib/core/config/app_config.dart:37-38` | Fast2SMS API Key | Yes (commit `ca4c2ca`) | **Yes** (compiled as default const String) | Remove default fallback; move SMS OTP dispatch to Supabase Edge Function; rotate Fast2SMS API key. |
| **HIGH** | `lib/core/config/app_config.dart:47-49` | WhatsApp Cloud API Access Token | Yes (commit `ca4c2ca`) | **Yes** (compiled as default const String) | Remove default fallback; move WhatsApp notification dispatch to backend/Edge Function; rotate token in Meta Developer Portal. |
| **HIGH** | `config.json:7-9` | Fast2SMS API Key & WhatsApp Token | Yes (commit `ca4c2ca`) | No | Untrack `config.json`; purge from git history; rotate keys. |
| **HIGH** | `.env:13, 16, 20` | Razorpay Secret, Fast2SMS Key, WhatsApp Token | No | No | File is gitignored; replace values with rotated keys; ensure never added to git. |
| **HIGH** | `.env.example:5-6` | Real Razorpay Key ID & Key Secret | No | No | Replace real values with placeholder strings (e.g. `RAZORPAY_KEY_ID_PLACEHOLDER`, `your_secret_here`); explicitly allow `.env.example` in `.gitignore`. |
| **HIGH** | `android/app/google-services.json:18` | Google Services API Key & Client Config | Yes (commit `470db1a`) | **Yes** (compiled into Android app) | Untrack from git (`git rm --cached`); ensure `.gitignore` covers `android/app/google-services.json`; restrict key in Google Cloud Console to app package & SHA-1. |
| **MEDIUM** | `lib/core/config/app_config.dart:17-19` | Google Maps API Key | Yes (commit `ca4c2ca`) | **Yes** (compiled as default const String) | Remove default fallback; load via `--dart-define=MAPS_API_KEY=...`; restrict key by package name/SHA-1 and HTTP referrer in Google Cloud Console. |
| **MEDIUM** | `config.json:4` | Google Maps API Key | Yes (commit `ca4c2ca`) | No | Untrack and purge `config.json`. |
| **MEDIUM** | `android/app/src/main/AndroidManifest.xml:37` (historical) | Google Maps API Key | Yes (commit `c5ebb40`) | Was shipped, now uses `${mapsApiKey}` | Key was previously committed directly into manifest; purge from git history. |
| **MEDIUM** | `lib/core/config/app_config.dart:11-14` | Supabase Anon Key JWT | Yes (commit `ca4c2ca`) | **Yes** (compiled as default const String) | While Anon Key is designed to be client-side, remove hardcoded fallback and inject strictly via `--dart-define-from-file`; harden Supabase RLS. |
| **MEDIUM** | `check_schema.py:6` | Supabase Anon Key JWT | Yes (commit `c5ebb40`) | No | Untracked on disk; purge historical commit from git history. |
| **MEDIUM** | `tools/migrate_pm_data.py` | Migration script accessing `.env` | Yes (commit `c989910`) | No | Tracked by Git despite `tools` in `.gitignore`. Untrack with `git rm --cached tools/migrate_pm_data.py`. |

---

## 3. Detailed Audit Check Items

### Item 1: `insiya-salesapp-firebase-adminsdk*.json` (Project Root)
- **a) Listed in `.gitignore`?**  
  **YES.** Matched by line 84: `*-firebase-adminsdk-*.json` (verified via `git check-ignore -v`).
- **b) Listed in `pubspec.yaml` assets or build configs?**  
  **NO.** Not listed under `pubspec.yaml` `assets:` (only `assets/images/`, `assets/images/boom_barrier/`, `assets/icons/`, `assets/fonts/`, `assets/data/` are declared). Not referenced in `android/`, `windows/`, `ios/`, or `web/` build files.
- **c) Present in git history?**  
  **NO.** Executed `git log --all --oneline -- "*firebase-adminsdk*.json"` which returned 0 results.
- **d) Referenced in `lib/`?**  
  **NO.** No runtime loading references found in `lib/`.

---

### Item 2: Same Checks for `.env`, `scratch/`, `tools/`, and Root `.py` Files
- **`.env`:**
  - **a) .gitignore:** YES (lines 49-51: `.env`, `*.env`, `.env.*`).
  - **b) pubspec.yaml assets / build configs:** NO.
  - **c) Git history:** NO (0 occurrences in git commit history).
  - **d) Referenced in `lib/`:** Only mentioned in UI comments and diagnostic dialogs; not loaded via `flutter_dotenv` at runtime. (Loaded by root `server.js`).
- **`scratch/`:**
  - **a) .gitignore:** YES (line 56: `scratch/`).
  - **b) pubspec.yaml assets / build configs:** NO.
  - **c) Git history:** **YES.** Committed in commits `88a486b`, `e9840d4`, `0dba7b5`, `c5ebb40` (contained 18 python and dart scripts with hardcoded plaintext database passwords).
  - **d) Referenced in `lib/`:** NO.
- **`tools/`:**
  - **a) .gitignore:** YES (line 79: `tools`).
  - **b) pubspec.yaml assets / build configs:** NO.
  - **c) Git history:** **YES.** `tools/migrate_pm_data.py` was committed in `c989910` and **remains currently tracked in git index** despite `.gitignore`.
  - **d) Referenced in `lib/`:** NO.
- **Root `.py` files (`check_schema.py`, `add_quotation_columns.py`, `check_quotations.py`, `query_db.py`, `read_pdf.py`, `update_rpc.py`):**
  - **a) .gitignore:** YES (line 57: `*.py`).
  - **b) pubspec.yaml assets / build configs:** NO.
  - **c) Git history:** **YES.** Committed in commits `88a486b`, `e9840d4`, `c5ebb40`. In `c5ebb40`, they contained plaintext database passwords and anon JWTs.
  - **d) Referenced in `lib/`:** NO.

---

### Item 3: Whole-Repo Secrets Search Summary
- **Service Role Keys:** **NONE FOUND.** No Supabase `service_role` secret keys exist in the repository or git history.
- **Database Passwords:** Found hardcoded in git history across 18 scripts in `scratch/` and root `.py` files (commit `c5ebb40` and `0dba7b5`), and in `scratch/` local files.
- **Razorpay Key & Secret:** Hardcoded in `lib/core/config/app_config.dart:27-29`, `config.json:5-6`, `SECURITY_AUDIT.md:66, 84`, `.env.example:5-6`, and compiled into `build/web/main.dart.js`.
- **Fast2SMS Key:** Hardcoded in `lib/core/config/app_config.dart:37-38`, `config.json:7`, and `.env:16`.
- **WhatsApp Cloud API Token & Phone ID:** Hardcoded in `lib/core/config/app_config.dart:42-49`, `config.json:8-10`, and `.env:19-20`.
- **Google Maps Key:** Hardcoded in `lib/core/config/app_config.dart:17-19`, `config.json:4`, `.env:5`, and historically in `android/app/src/main/AndroidManifest.xml:37`.
- **Private Key (`-----BEGIN PRIVATE KEY-----`):** Present in `insiya-salesapp-firebase-adminsdk-fbsvc-4347c34ec2.json` (untracked, not in git history).
- **Hardcoded JWTs:** Supabase Anon Key JWT hardcoded in `check_schema.py:6`, `lib/core/config/app_config.dart:11-14`, `config.json:3`, `.env.example:2`, `build/web/main.dart.js`, and historically in `lib/main.dart` (commit `c5ebb40`).

---

### Item 4: `.env` Declaration in `pubspec.yaml`
- **Check Result:** `.env` is **NOT** declared as an asset in `pubspec.yaml`. The declared assets are exclusively:
  ```yaml
  assets:
    - assets/images/
    - assets/images/boom_barrier/
    - assets/icons/
    - assets/fonts/
    - assets/data/
  ```

---

### Item 5: `SECURITY_AUDIT.md` and `docs/` Files
- **`SECURITY_AUDIT.md`:** **CONTAINS REAL SECRET VALUES.**
  - Line 66: Contains actual Razorpay Key Secret string in finding #2 description.
  - Line 84: Contains actual Razorpay Key Secret string in detailed section 1 table.
  - Action: Must redact immediately to `[REDACTED]`.
- **`docs/` files:** Checked all baseline and gap analysis documents in `docs/quotation_generator/`. **NO real secret values found.**

---

## 4. Required Edge Functions Architecture (Plan for Server-Only Secrets)

Client devices must never hold merchant or administrative secrets. The following Supabase Edge Functions must be deployed to replace client-side operations:

1. **`razorpay-create-order`**:
   - **Secret Needed:** `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`
   - **Purpose:** Creates standard Razorpay orders or UPI QR codes server-side and returns the `order_id` to the client app.
2. **`razorpay-verify-payment`**:
   - **Secret Needed:** `RAZORPAY_KEY_SECRET`
   - **Purpose:** Receives `razorpay_order_id`, `razorpay_payment_id`, and `razorpay_signature`; computes server-side HMAC-SHA256 signature verification; updates invoice / quotation status to `paid` using `service_role`.
3. **`send-sms-otp`**:
   - **Secret Needed:** `FAST2SMS_API_KEY`
   - **Purpose:** Generates cryptographically secure OTP, stores hash/expiry in private database table, dispatches SMS via Fast2SMS API.
4. **`send-whatsapp-notification`**:
   - **Secret Needed:** `WHATSAPP_ACCESS_TOKEN`, `WHATSAPP_PHONE_ID`
   - **Purpose:** Dispatches template notifications (order confirmation, quotation delivery, dispatch alert) via WhatsApp Cloud API.
5. **`fcm-push-dispatcher`**:
   - **Secret Needed:** `insiya-salesapp-firebase-adminsdk-*.json` (Service Account Key)
   - **Purpose:** Dispatches high-priority Firebase push notifications to staff and customer devices securely from the backend.

---

## 5. Git History Cleanup Commands (For User Execution)

> [!WARNING]
> Rewriting git history modifies commit hashes and requires forced pushes (`git push --force-with-lease`). Run these commands in a clean clone or backup of your repository.

### Option A: Using `git-filter-repo` (Recommended)
1. Install `git-filter-repo` (`pip install git-filter-repo`).
2. Create a `replace_expressions.txt` file listing regexes to redact (or paths to remove):
   ```bash
   # Remove tracked secret files from all history:
   git filter-repo --invert-paths \
     --path config.json \
     --path android/app/google-services.json \
     --path build/web \
     --path-glob "scratch/*" \
     --path-glob "*firebase-adminsdk*.json" \
     --path-glob "*.py"
   ```
3. To scrub specific secret strings (such as the database password and Razorpay secret) across any remaining commits:
   Create `replace_passwords.txt`:
   ```
   regex:<LEAKED_DB_PASSWORD>==>[REDACTED_DB_PASSWORD]
   regex:<LEAKED_RAZORPAY_SECRET>==>[REDACTED_RAZORPAY_SECRET]
   ```
   Execute:
   ```bash
   git filter-repo --replace-text replace_passwords.txt
   ```

### Option B: Using BFG Repo-Cleaner
```bash
# 1. Download bfg.jar
# 2. Delete secret files:
java -jar bfg.jar --delete-files "{*firebase-adminsdk*.json,config.json,google-services.json}"
# 3. Replace secret text inside files:
# Create passwords.txt with the secrets (one per line)
java -jar bfg.jar --replace-text passwords.txt
# 4. Clean reflog and prune:
git reflog expire --expire=now --all && git gc --prune=now --aggressive
```

---

## 6. Manual Dashboard Key Rotation Checklist

Once code remediation is applied, rotate the following credentials in their provider dashboards:

- [ ] **Supabase Dashboard** (`https://supabase.com/dashboard/project/dnhbtkhcjpkthvyhyzmt`):
  - [ ] Rotate PostgreSQL Database Password (Settings -> Database -> Database Password).
  - [ ] Rotate Supabase Anon Key & JWT Secret (Settings -> API -> JWT Settings).
- [ ] **Razorpay Dashboard** (`https://dashboard.razorpay.com/`):
  - [ ] Invalidate compromised Key Secret `<LEAKED_RAZORPAY_SECRET>` (Settings -> API Keys -> Regenerate Key Secret).
  - [ ] Configure Webhooks for backend payment capture verification.
- [ ] **Fast2SMS Dashboard** (`https://www.fast2sms.com/`):
  - [ ] Regenerate Dev/API Key in Dev API settings.
- [ ] **Meta for Developers / WhatsApp Cloud API** (`https://developers.facebook.com/`):
  - [ ] Generate a new System User Permanent Access Token.
  - [ ] Revoke previous user access token.
- [ ] **Google Cloud Platform Console** (`https://console.cloud.google.com/`):
  - [ ] Restrict Google Maps API Key to Android package `com.izyheat.salesapp` with SHA-1 fingerprint.
  - [ ] Invalidate and generate a new Service Account Private Key for Firebase Admin SDK.
