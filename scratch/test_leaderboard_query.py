import psycopg2
from psycopg2.extras import RealDictCursor

conn_str = "dbname='postgres' user='postgres' host='db.dnhbtkhcjpkthvyhyzmt.supabase.co' password='CHTxPuCOTxh2eD5K' port='5432'"
conn = psycopg2.connect(conn_str)
cur = conn.cursor(cursor_factory=RealDictCursor)

# Query sales reps and their performance
cur.execute("""
    SELECT 
        p.id, 
        p.full_name, 
        p.email,
        COUNT(l.id) AS total_leads,
        COUNT(l.id) FILTER (WHERE l.status = 'Won') AS won_deals,
        COUNT(l.id) FILTER (WHERE l.status != 'Won' AND l.status != 'Lost') AS active_leads,
        COALESCE(SUM(l.estimated_value) FILTER (WHERE l.status = 'Won'), 0) AS total_revenue
    FROM profiles p
    LEFT JOIN crm_leads l ON l.assigned_to = p.id OR (l.assigned_to IS NULL AND l.created_by = p.id)
    WHERE p.role::text = 'sales' OR 'sales' = ANY(p.roles::text[]) OR p.role::text IN ('admin', 'manager')
    GROUP BY p.id, p.full_name, p.email
    ORDER BY won_deals DESC, total_revenue DESC;
""")
reps = cur.fetchall()
print(f"Sales Reps Performance ({len(reps)} found):")
for r in reps:
    print(r)
