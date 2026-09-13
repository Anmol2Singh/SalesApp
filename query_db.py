import os
import psycopg2
from psycopg2.extras import RealDictCursor

db_password = os.environ.get("SUPABASE_DB_PASSWORD", "")
conn_str = f"dbname='postgres' user='postgres' host='db.dnhbtkhcjpkthvyhyzmt.supabase.co' password='{db_password}' port='5432'"

try:
    conn = psycopg2.connect(conn_str)
    cur = conn.cursor(cursor_factory=RealDictCursor)
    
    # Let's query public tables
    cur.execute("""
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = 'public' 
        ORDER BY table_name;
    """)
    tables = cur.fetchall()
    print("Tables in public schema:")
    for t in tables:
        print(f"  {t['table_name']}")
        
    # Let's inspect enum values for pipeline_step
    cur.execute("""
        SELECT enumlabel 
        FROM pg_enum 
        JOIN pg_type ON pg_enum.enumtypid = pg_type.oid 
        WHERE pg_type.typname = 'pipeline_step';
    """)
    steps = cur.fetchall()
    print("\nEnum values for pipeline_step:")
    for s in steps:
        print(f"  {s['enumlabel']}")
        
    # Let's inspect enum values for document_type
    cur.execute("""
        SELECT enumlabel 
        FROM pg_enum 
        JOIN pg_type ON pg_enum.enumtypid = pg_type.oid 
        WHERE pg_type.typname = 'document_type';
    """)
    doc_types = cur.fetchall()
    print("\nEnum values for document_type:")
    for d in doc_types:
        print(f"  {d['enumlabel']}")

    # Let's check if sales_orders exists and show columns
    cur.execute("""
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'sales_orders';
    """)
    if cur.fetchone():
        print("\nColumns of table sales_orders:")
        cur.execute("""
            SELECT column_name, data_type, is_nullable
            FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = 'sales_orders'
            ORDER BY ordinal_position;
        """)
        cols = cur.fetchall()
        for c in cols:
            print(f"  {c['column_name']}: {c['data_type']} (nullable: {c['is_nullable']})")
    else:
        print("\nTable sales_orders does not exist!")

    cur.close()
    conn.close()

except Exception as e:
    print("Error connecting/querying DB:", e)
