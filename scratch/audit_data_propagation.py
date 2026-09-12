import psycopg2
from psycopg2.extras import RealDictCursor
import uuid

conn_str = "dbname='postgres' user='postgres' host='db.dnhbtkhcjpkthvyhyzmt.supabase.co' password='CHTxPuCOTxh2eD5K' port='5432'"

conn = psycopg2.connect(conn_str)
conn.autocommit = True
cur = conn.cursor(cursor_factory=RealDictCursor)

test_id = str(uuid.uuid4())[:8]
sample_phone = f"+9198{test_id}"[:13]
test_name = f"Audit Customer {test_id}"
test_notes = f"Initial prospect notes for {test_id}"

cur.execute("SELECT id FROM profiles LIMIT 1;")
profile = cur.fetchone()
creator_id = profile['id'] if profile else None
print(f"Using creator_id: {creator_id}")

print(f"--- 1. Testing Prospect Creation ---")
cur.execute("""
    INSERT INTO crm_prospects (name, phone, email, notes, company, address, created_by)
    VALUES (%s, %s, %s, %s, %s, %s, %s)
    RETURNING id, name, phone, notes;
""", (test_name, sample_phone, f"audit_{test_id}@example.com", test_notes, "Acme Solar", "Jaipur, Rajasthan", creator_id))
prospect = cur.fetchone()
print(f"Created prospect: {prospect}")

print(f"\n--- 2. Testing Lead Creation from Prospect ---")
cur.execute("""
    INSERT INTO crm_leads (prospect_id, prospect_name, contact_phone, product_name, notes, status, estimated_value, created_by)
    VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
    RETURNING id, prospect_id, prospect_name, contact_phone, notes, estimated_value;
""", (prospect['id'], prospect['name'], prospect['phone'], "Commercial 10kW", prospect['notes'], "New", 0.0, creator_id))
lead = cur.fetchone()
print(f"Created lead: {lead}")

print(f"\n--- 3. Testing Quotation Deal Value Auto-Sync ---")
cur.execute("""
    INSERT INTO quotations (lead_id, quotation_number, grand_total, status)
    VALUES (%s, %s, %s, %s)
    RETURNING id, lead_id, quotation_number, grand_total;
""", (lead['id'], f"Q-AUDIT-{test_id}", 450000.0, "draft"))
quot = cur.fetchone()
print(f"Created quotation: {quot}")

# Check if lead.estimated_value was auto-synced by trigger
cur.execute("SELECT id, estimated_value FROM crm_leads WHERE id = %s", (lead['id'],))
updated_lead = cur.fetchone()
print(f"Lead estimated_value after quotation trigger: {updated_lead['estimated_value']}")
assert float(updated_lead['estimated_value']) == 450000.0, "Trigger failed to sync quotation total to lead estimated_value!"
print(">>> Quotation deal value auto-sync VERIFIED! <<<")

print(f"\n--- 4. Testing Customer Creation & Conversion ---")
cur.execute("""
    INSERT INTO customers (company_name, contact_person, phone, email, notes, created_by)
    VALUES (%s, %s, %s, %s, %s, %s)
    RETURNING id, company_name, contact_person, phone, email, notes;
""", ("Acme Solar", test_name, sample_phone, f"audit_{test_id}@example.com", test_notes, creator_id))
customer = cur.fetchone()
print(f"Created customer: {customer}")

# Link customer to lead
cur.execute("""
    UPDATE crm_leads
    SET converted_to_customer_id = %s, status = 'Won'
    WHERE id = %s
    RETURNING id, status, converted_to_customer_id;
""", (customer['id'], lead['id']))
won_lead = cur.fetchone()
print(f"Updated lead to Won: {won_lead}")

print(f"\n--- 5. Testing Global Sync Trigger when Customer is Edited ---")
new_customer_name = f"Updated Customer {test_id}"
new_phone = f"+9199{test_id}"[:13]
cur.execute("""
    UPDATE customers
    SET company_name = %s, contact_person = %s, phone = %s
    WHERE id = %s
    RETURNING id, company_name, contact_person, phone;
""", (new_customer_name, new_customer_name, new_phone, customer['id']))
updated_cust = cur.fetchone()
print(f"Customer updated: {updated_cust}")

# Check if lead synced
cur.execute("SELECT id, prospect_name, contact_phone FROM crm_leads WHERE id = %s", (lead['id'],))
synced_lead = cur.fetchone()
print(f"Synced lead: {synced_lead}")
assert synced_lead['prospect_name'] == new_customer_name, "Global sync failed to update lead prospect_name!"
assert synced_lead['contact_phone'] == new_phone, "Global sync failed to update lead contact_phone!"
print(">>> Global sync on customer edit VERIFIED! <<<")

# Cleanup
print(f"\n--- Cleaning up test records ---")
cur.execute("DELETE FROM quotations WHERE id = %s", (quot['id'],))
cur.execute("DELETE FROM crm_leads WHERE id = %s", (lead['id'],))
cur.execute("DELETE FROM crm_prospects WHERE id = %s", (prospect['id'],))
cur.execute("DELETE FROM customers WHERE id = %s", (customer['id'],))
print("Cleanup complete. All audit assertions passed!")
