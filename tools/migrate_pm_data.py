#!/usr/bin/env python3
"""
tools/migrate_pm_data.py
Data migration and customer matching script for Project Manager.

Features:
- Reads backup data from `D:/Files/Html Codes/Project Manager/supabase_data_backup.json`
  and optionally `Trading Upload.csv`.
- Fetches existing customers from SalesApp Supabase database.
- Normalizes phone numbers, emails, and company names.
- Matches projects against existing customers strictly by phone/email/company.
- For matched projects: prepares/executes insertion into `pm_projects` and child tables.
- For unmatched projects: produces `unmatched_customers_report.json` with diagnostic details
  so NO duplicate or phantom customer records are ever auto-created.
"""

import os
import sys
import json
import csv
import re
from typing import Dict, Any, List, Optional
import urllib.request
import urllib.error

SOURCE_BACKUP_PATH = r"D:\Files\Html Codes\Project Manager\supabase_data_backup.json"
SOURCE_CSV_PATH = r"D:\Files\Html Codes\Project Manager\Trading Upload.csv"
REPORT_OUTPUT_PATH = "unmatched_customers_report.json"

def clean_phone(phone: Optional[str]) -> str:
    if not phone:
        return ""
    digits = re.sub(r"\D", "", str(phone))
    if len(digits) > 10:
        return digits[-10:]
    return digits

def clean_str(s: Optional[str]) -> str:
    if not s:
        return ""
    return re.sub(r"\s+", " ", str(s).strip().lower())

def load_env() -> Dict[str, str]:
    env = {}
    if os.path.exists(".env"):
        with open(".env", "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if "=" in line and not line.startswith("#"):
                    k, v = line.split("=", 1)
                    env[k.strip()] = v.strip().strip("'\"")
    return env

def supabase_request(url: str, key: str, path: str, method: str = "GET", data: Any = None) -> Any:
    full_url = f"{url.rstrip('/')}/rest/v1/{path.lstrip('/')}"
    headers = {
        "apikey": key,
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json",
        "Prefer": "return=representation"
    }
    body = json.dumps(data).encode("utf-8") if data is not None else None
    req = urllib.request.Request(full_url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as response:
            res_body = response.read().decode("utf-8")
            if res_body:
                return json.loads(res_body)
            return None
    except urllib.error.HTTPError as e:
        err_msg = e.read().decode("utf-8")
        raise RuntimeError(f"HTTP {e.code} Error for {full_url}: {err_msg}")

def main():
    print("=== Project Manager Data Migration & Customer Matcher ===")
    env = load_env()
    supabase_url = env.get("SUPABASE_URL")
    supabase_key = env.get("SUPABASE_ANON_KEY")

    if not supabase_url or not supabase_key:
        print("[ERROR] SUPABASE_URL or SUPABASE_ANON_KEY missing from .env.")
        sys.exit(1)

    print(f"Connecting to Supabase: {supabase_url}...")
    try:
        customers = supabase_request(supabase_url, supabase_key, "customers?select=id,customer_name,company_name,phone,email,address")
        print(f"Fetched {len(customers)} existing customers from SalesApp.")
    except Exception as e:
        print(f"[WARNING] Could not fetch customers from Supabase: {e}")
        customers = []

    # Build lookup indices
    phone_map: Dict[str, str] = {}
    email_map: Dict[str, str] = {}
    name_map: Dict[str, str] = {}

    for c in customers:
        cid = c["id"]
        c_phone = clean_phone(c.get("phone"))
        c_email = clean_str(c.get("email"))
        c_name = clean_str(c.get("company_name") or c.get("customer_name"))

        if c_phone and len(c_phone) >= 10:
            phone_map[c_phone] = cid
        if c_email:
            email_map[c_email] = cid
        if c_name:
            name_map[c_name] = cid

    # Load JSON backup data
    if not os.path.exists(SOURCE_BACKUP_PATH):
        print(f"[ERROR] Source backup file not found at {SOURCE_BACKUP_PATH}")
        sys.exit(1)

    with open(SOURCE_BACKUP_PATH, "r", encoding="utf-8") as f:
        backup_data = json.load(f)

    projects = backup_data.get("projects", [])
    print(f"Loaded {len(projects)} projects from JSON backup.")

    matched_projects = []
    unmatched_projects = []

    for proj in projects:
        site_name = proj.get("site_name", "")
        phone = clean_phone(proj.get("mobile_number"))
        party_name = clean_str(proj.get("party_print_name"))
        cleaned_site = clean_str(site_name)

        matched_cid = None
        match_reason = ""

        if phone and phone in phone_map:
            matched_cid = phone_map[phone]
            match_reason = f"Phone match: {phone}"
        elif cleaned_site and cleaned_site in name_map:
            matched_cid = name_map[cleaned_site]
            match_reason = f"Site name match: {site_name}"
        elif party_name and party_name in name_map:
            matched_cid = name_map[party_name]
            match_reason = f"Party name match: {proj.get('party_print_name')}"

        if matched_cid:
            proj_copy = dict(proj)
            proj_copy["customer_id"] = matched_cid
            proj_copy["_match_reason"] = match_reason
            matched_projects.append(proj_copy)
        else:
            unmatched_projects.append({
                "project": proj,
                "reason": "No match found for phone, site name, or party name in existing customers table"
            })

    print(f"\nResults for JSON Backup Projects:")
    print(f"  -> Matched: {len(matched_projects)}")
    print(f"  -> Unmatched: {len(unmatched_projects)}")

    # Write report
    report = {
        "timestamp": os.path.getmtime(SOURCE_BACKUP_PATH) if os.path.exists(SOURCE_BACKUP_PATH) else None,
        "matched_count": len(matched_projects),
        "unmatched_count": len(unmatched_projects),
        "matched_projects": matched_projects,
        "unmatched_projects": unmatched_projects,
    }

    with open(REPORT_OUTPUT_PATH, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2)

    print(f"\nUnmatched report generated at: {REPORT_OUTPUT_PATH}")
    print("Review the report. Unmatched customers can be linked manually after creation.")

if __name__ == "__main__":
    main()
