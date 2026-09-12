import requests
import json

url = "https://dnhbtkhcjpkthvyhyzmt.supabase.co/rest/v1/sales_pipelines?select=id,created_at,customer_id,status,product_id,products(id,name,category,image_urls,brochure_urls),customers(id,address,company_name,customer_name),sales_orders(shipping_address),quotations(grand_total),warranty_cards(start_date,end_date)"
anon_key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRuaGJ0a2hjanBrdGh2eWh5em10Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODIwNTQxODgsImV4cCI6MjA5NzYzMDE4OH0.oMh-wN5YgqnxTBy_KOvNCQIhPu1G2xwFnfkdwaN81u8"

headers = {
    "apikey": anon_key,
    "Authorization": f"Bearer {anon_key}",
}

r = requests.get(url, headers=headers)
print("Status code:", r.status_code)
print("Response:", r.text[:500])
