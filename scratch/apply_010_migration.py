import psycopg2

conn_str = "dbname='postgres' user='postgres' host='db.dnhbtkhcjpkthvyhyzmt.supabase.co' password='CHTxPuCOTxh2eD5K' port='5432'"
conn = psycopg2.connect(conn_str)
conn.autocommit = True
cur = conn.cursor()

with open('supabase/migrations/010_crm_enhancements.sql', 'r', encoding='utf-8') as f:
    sql = f.read()

cur.execute(sql)
print("Migration 010 successfully applied!")

# Test RPC
cur.execute("SELECT * FROM get_crm_leaderboard();")
rows = cur.fetchall()
print(f"Leaderboard RPC returned {len(rows)} entries:")
for r in rows:
    print(" ", r)

# Verify crm_sources
cur.execute("SELECT name FROM crm_sources ORDER BY name;")
sources = [r[0] for r in cur.fetchall()]
print(f"Current CRM sources ({len(sources)}):", sources)

# Verify crm_interaction_types
cur.execute("SELECT name FROM crm_interaction_types ORDER BY name;")
types = [r[0] for r in cur.fetchall()]
print(f"Current CRM interaction types ({len(types)}):", types)

cur.close()
conn.close()
