import os
import psycopg2

db_password = os.environ.get("SUPABASE_DB_PASSWORD", "")
conn_str = f"dbname='postgres' user='postgres' host='db.dnhbtkhcjpkthvyhyzmt.supabase.co' password='{db_password}' port='5432'"

alter_sql = """
ALTER TABLE quotations
ADD COLUMN IF NOT EXISTS sales_order_no TEXT,
ADD COLUMN IF NOT EXISTS order_date TIMESTAMPTZ DEFAULT NOW(),
ADD COLUMN IF NOT EXISTS bill_type TEXT DEFAULT 'Credit',
ADD COLUMN IF NOT EXISTS place_of_supply TEXT,
ADD COLUMN IF NOT EXISTS distance NUMERIC,
ADD COLUMN IF NOT EXISTS gr_lr_no TEXT,
ADD COLUMN IF NOT EXISTS destination TEXT,
ADD COLUMN IF NOT EXISTS customer_name TEXT,
ADD COLUMN IF NOT EXISTS billing_address TEXT,
ADD COLUMN IF NOT EXISTS customer_gstin TEXT,
ADD COLUMN IF NOT EXISTS customer_phone TEXT,
ADD COLUMN IF NOT EXISTS party_contact_person TEXT,
ADD COLUMN IF NOT EXISTS shipping_name TEXT,
ADD COLUMN IF NOT EXISTS shipping_address TEXT,
ADD COLUMN IF NOT EXISTS state_code INTEGER,
ADD COLUMN IF NOT EXISTS salesman TEXT,
ADD COLUMN IF NOT EXISTS remarks TEXT DEFAULT 'Being Sales Order Generated',
ADD COLUMN IF NOT EXISTS igst_amount NUMERIC(15,2) DEFAULT 0;
"""

try:
    conn = psycopg2.connect(conn_str)
    conn.autocommit = True
    cur = conn.cursor()
    
    print("Running database migration to add quotation fields...")
    cur.execute(alter_sql)
    print("Migration completed successfully!")
    
    cur.close()
    conn.close()

except Exception as e:
    print("Error running migration:", e)
