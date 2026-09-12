import psycopg2
from psycopg2.extras import RealDictCursor

conn_str = "dbname='postgres' user='postgres' host='db.dnhbtkhcjpkthvyhyzmt.supabase.co' password='CHTxPuCOTxh2eD5K' port='5432'"
conn = psycopg2.connect(conn_str)
cur = conn.cursor(cursor_factory=RealDictCursor)

cur.execute("""
    SELECT polname, polcmd, polroles::regrole[], polqual, polwithcheck 
    FROM pg_policy 
    JOIN pg_class ON pg_policy.polrelid = pg_class.oid 
    WHERE relname = 'complaints';
""")
policies = cur.fetchall()
print("RLS Policies on complaints table:")
for p in policies:
    print(p)

cur.execute("""
    SELECT relrowsecurity 
    FROM pg_class 
    WHERE relname = 'complaints';
""")
print("\nRow security enabled on complaints?:", cur.fetchone())

cur.close()
conn.close()
