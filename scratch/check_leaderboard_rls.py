import urllib.request
import json

url = "https://dnhbtkhcjpkthvyhyzmt.supabase.co"
key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRuaGJ0a2hjanBrdGh2eWh5em10Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODIwNTQxODgsImV4cCI6MjA5NzYzMDE4OH0.oMh-wN5YgqnxTBy_KOvNCQIhPu1G2xwFnfkdwaN81u8"

def get(path):
    req = urllib.request.Request(f"{url}/rest/v1/{path}", headers={
        "apikey": key,
        "Authorization": f"Bearer {key}",
    })
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read().decode())
    except Exception as e:
        return f"Error: {e}"

print("=== CRM LEADS ===")
leads = get("crm_leads?select=id,status,estimated_value,assigned_to,created_by&limit=5")
print(f"Count returned with anon key: {len(leads) if isinstance(leads, list) else leads}")
if isinstance(leads, list):
    for l in leads:
        print(l)

print("\n=== PROFILES ===")
profs = get("profiles?select=id,full_name,email,role,roles&limit=5")
print(f"Profiles returned: {len(profs) if isinstance(profs, list) else profs}")
if isinstance(profs, list):
    for p in profs:
        print(p)
