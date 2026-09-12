import psycopg2
from psycopg2.extras import RealDictCursor

conn_str = "dbname='postgres' user='postgres' host='db.dnhbtkhcjpkthvyhyzmt.supabase.co' password='CHTxPuCOTxh2eD5K' port='5432'"
conn = psycopg2.connect(conn_str)
cur = conn.cursor(cursor_factory=RealDictCursor)

cur.execute("SELECT count(*) FROM customers;")
print("Customer count:", cur.fetchone())

cur.execute("SELECT count(*) FROM sales_pipelines;")
print("Sales pipelines count:", cur.fetchone())

cur.execute("SELECT count(*) FROM crm_leads;")
print("CRM Leads count:", cur.fetchone())

cur.execute("SELECT id, prospect_name, product_name, status, converted_to_customer_id FROM crm_leads WHERE status = 'Won' LIMIT 5;")
print("Won Leads:", cur.fetchall())

cur.execute("SELECT id, customer_id, product_id, current_step, status FROM sales_pipelines LIMIT 5;")
print("Sample sales pipelines:", cur.fetchall())

cur.close()
conn.close()
