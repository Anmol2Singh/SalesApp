import psycopg2
from psycopg2.extras import RealDictCursor

conn_str = "dbname='postgres' user='postgres' host='db.dnhbtkhcjpkthvyhyzmt.supabase.co' password='CHTxPuCOTxh2eD5K' port='5432'"
conn = psycopg2.connect(conn_str)
cur = conn.cursor(cursor_factory=RealDictCursor)

cur.execute("""
    SELECT polname, polcmd, pg_get_expr(polqual, polrelid) as qual
    FROM pg_policy 
    JOIN pg_class ON pg_policy.polrelid = pg_class.oid 
    WHERE relname = 'sales_pipelines';
""")
for p in cur.fetchall():
    print(p['polname'], ":", p['qual'])

cur.execute("""
    SELECT polname, polcmd, pg_get_expr(polqual, polrelid) as qual
    FROM pg_policy 
    JOIN pg_class ON pg_policy.polrelid = pg_class.oid 
    WHERE relname = 'customers';
""")
for p in cur.fetchall():
    print(p['polname'], ":", p['qual'])

cur.close()
conn.close()
