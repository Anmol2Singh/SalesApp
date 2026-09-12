import psycopg2
from psycopg2.extras import RealDictCursor

conn_str = "dbname='postgres' user='postgres' host='db.dnhbtkhcjpkthvyhyzmt.supabase.co' password='CHTxPuCOTxh2eD5K' port='5432'"
conn = psycopg2.connect(conn_str)
cur = conn.cursor(cursor_factory=RealDictCursor)

cur.execute("SELECT id, name, email FROM technicians;")
print("Technicians rows:", cur.fetchall())

cur.execute("SELECT id, full_name, email, role, roles FROM profiles WHERE role::text LIKE '%tech%' OR 'technician' = ANY(roles) LIMIT 5;")
print("Profiles with tech role:", cur.fetchall())

cur.execute("""
    SELECT conname, pg_get_constraintdef(oid) 
    FROM pg_constraint 
    WHERE conrelid = 'complaints'::regclass;
""")
print("\nConstraints on complaints table:")
for row in cur.fetchall():
    print(f"  {row['conname']}: {row['pg_get_constraintdef']}")

cur.close()
conn.close()
