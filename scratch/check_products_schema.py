import urllib.request
import json

url = "https://dnhbtkhcjpkthvyhyzmt.supabase.co"
key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRuaGJ0a2hjanBrdGh2eWh5em10Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODIwNTQxODgsImV4cCI6MjA5NzYzMDE4OH0.oMh-wN5YgqnxTBy_KOvNCQIhPu1G2xwFnfkdwaN81u8"

def get(path):
    req = urllib.request.Request(f"{url}/rest/v1/{path}", headers={
        "apikey": key,
        "Authorization": f"Bearer {key}",
    })
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read().decode())

print("=== PRODUCTS ===")
prods = get("products?select=id,name,category,base_specs&limit=5")
for p in prods:
    print(p)

print("\n=== INVENTORY SIZES ===")
sizes = get("inventory_sizes?select=*&limit=5")
for s in sizes:
    print(s)
