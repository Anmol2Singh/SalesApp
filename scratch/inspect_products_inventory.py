import psycopg2

conn = psycopg2.connect("dbname='postgres' user='postgres' host='db.dnhbtkhcjpkthvyhyzmt.supabase.co' password='CHTxPuCOTxh2eD5K' port='5432'")
cur = conn.cursor()

print("--- RELEVANT INVENTORY ITEMS ---")
cur.execute("SELECT item_name, price, uom FROM inventory_items WHERE item_name ILIKE '%heat%' OR item_name ILIKE '%solar%' OR item_name ILIKE '%pump%' OR item_name ILIKE '%barrier%' OR price > 0 ORDER BY item_name;")
for r in cur.fetchall():
    print(r)

cur.close()
conn.close()
