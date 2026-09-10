import psycopg2
from psycopg2.extras import RealDictCursor

conn_str = "dbname='postgres' user='postgres' host='db.dnhbtkhcjpkthvyhyzmt.supabase.co' password='CHTxPuCOTxh2eD5K' port='5432'"

try:
    conn = psycopg2.connect(conn_str)
    cur = conn.cursor(cursor_factory=RealDictCursor)
    
    cur.execute("""
        SELECT column_name, data_type, is_nullable
        FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'quotations'
        ORDER BY ordinal_position;
    """)
    cols = cur.fetchall()
    print("Columns of table quotations:")
    for c in cols:
        print(f"  {c['column_name']}: {c['data_type']} (nullable: {c['is_nullable']})")
        
    cur.close()
    conn.close()

except Exception as e:
    print("Error:", e)
