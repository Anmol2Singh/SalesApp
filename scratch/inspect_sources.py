import psycopg2
from psycopg2.extras import RealDictCursor

conn_str = "dbname='postgres' user='postgres' host='db.dnhbtkhcjpkthvyhyzmt.supabase.co' password='CHTxPuCOTxh2eD5K' port='5432'"
conn = psycopg2.connect(conn_str)
conn.autocommit = True
cur = conn.cursor(cursor_factory=RealDictCursor)

cur.execute("SELECT * FROM crm_sources;")
sources = cur.fetchall()
print("crm_sources:", sources)

if not sources:
    default_sources = [
        'Website', 'Referral', 'Cold Call', 'Social Media', 'Exhibition', 'Direct Walk-in', 'Manual'
    ]
    for s in default_sources:
        cur.execute("INSERT INTO crm_sources (name) VALUES (%s) ON CONFLICT DO NOTHING;", (s,))
    print("Seeded default crm_sources!")
    cur.execute("SELECT * FROM crm_sources;")
    print("New crm_sources:", cur.fetchall())
