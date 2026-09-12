import psycopg2
from psycopg2.extras import RealDictCursor

conn_str = "dbname='postgres' user='postgres' host='db.dnhbtkhcjpkthvyhyzmt.supabase.co' password='CHTxPuCOTxh2eD5K' port='5432'"
conn = psycopg2.connect(conn_str)
cur = conn.cursor(cursor_factory=RealDictCursor)

for tbl in ['sales_pipelines', 'customers', 'products', 'quotations']:
    cur.execute("""
        SELECT polname, polcmd, polroles::regrole[], polqual 
        FROM pg_policy 
        JOIN pg_class ON pg_policy.polrelid = pg_class.oid 
        WHERE relname = %s;
    """, (tbl,))
    policies = cur.fetchall()
    print(f"\nRLS Policies on {tbl}:")
    for p in policies:
        print(" ", p['polname'], p['polcmd'], p['polqual'])

cur.close()
conn.close()
