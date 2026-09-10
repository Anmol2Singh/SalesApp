import os
import requests
import json

url = "https://dnhbtkhcjpkthvyhyzmt.supabase.co/rest/v1/"
anon_key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRuaGJ0a2hjanBrdGh2eWh5em10Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODIwNTQxODgsImV4cCI6MjA5NzYzMDE4OH0.oMh-wN5YgqnxTBy_KOvNCQIhPu1G2xwFnfkdwaN81u8"

# We can query postgrest to see table columns if postgrest endpoints are accessible
# Or we can do an RPC call if there is a function.
# Let's inspect the sales_orders table columns using openapi description of postgrest!
headers = {
    "apikey": anon_key,
    "Authorization": f"Bearer {anon_key}",
    "Accept": "application/openapi+json"
}

try:
    r = requests.get(url, headers=headers)
    openapi = r.json()
    paths = openapi.get("paths", {})
    print("Available tables in Postgrest API:")
    for path in sorted(paths.keys()):
        print("  ", path)
    
    # Details of /sales_orders
    if "/sales_orders" in paths:
        print("\nColumns of /sales_orders:")
        parameters = paths["/sales_orders"].get("get", {}).get("parameters", [])
        for param in parameters:
            print(f"  {param.get('name')}: {param.get('type')} ({param.get('description')})")
    else:
        print("\n/sales_orders table NOT found in Postgrest OpenAPI")
except Exception as e:
    print("Error:", e)
