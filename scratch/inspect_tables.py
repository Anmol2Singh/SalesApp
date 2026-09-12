import psycopg2
from psycopg2.extras import RealDictCursor

conn_str = "dbname='postgres' user='postgres' host='db.dnhbtkhcjpkthvyhyzmt.supabase.co' password='CHTxPuCOTxh2eD5K' port='5432'"

tables_to_check = [
    'crm_prospects',
    'crm_leads',
    'customers',
    'sales_pipelines',
    'quotations',
    'complaints',
    'technicians',
    'crm_sources',
    'products',
    'inventory_items',
    'inventory_sizes',
    'profiles',
    'customer_profiles'
]

conn = psycopg2.connect(conn_str)
cur = conn.cursor(cursor_factory=RealDictCursor)

for table in tables_to_check:
    cur.execute("""
        SELECT column_name, data_type, is_nullable
        FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = %s
        ORDER BY ordinal_position;
    """, (table,))
    cols = cur.fetchall()
    print(f"\n================ Table: {table} ================")
    if not cols:
        print("  (Table does not exist)")
    for c in cols:
        print(f"  {c['column_name']}: {c['data_type']} (nullable: {c['is_nullable']})")

# Also check foreign keys between crm_prospects, crm_leads, customers, sales_pipelines
cur.execute("""
    SELECT
        tc.table_name, 
        kcu.column_name, 
        ccu.table_name AS foreign_table_name,
        ccu.column_name AS foreign_column_name 
    FROM 
        information_schema.table_constraints AS tc 
        JOIN information_schema.key_column_usage AS kcu
          ON tc.constraint_name = kcu.constraint_name
          AND tc.table_schema = kcu.table_schema
        JOIN information_schema.constraint_column_usage AS ccu
          ON ccu.constraint_name = tc.constraint_name
          AND ccu.table_schema = tc.table_schema
    WHERE tc.constraint_type = 'FOREIGN KEY' AND tc.table_schema='public'
      AND tc.table_name IN ('crm_prospects', 'crm_leads', 'customers', 'sales_pipelines', 'quotations', 'complaints')
    ORDER BY tc.table_name;
""")
fks = cur.fetchall()
print("\n================ Foreign Keys ================")
for fk in fks:
    print(f"  {fk['table_name']}.{fk['column_name']} -> {fk['foreign_table_name']}.{fk['foreign_column_name']}")

cur.close()
conn.close()
