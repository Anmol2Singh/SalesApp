-- Migration 010: CRM Enhancements
-- 1. Seed crm_sources with defaults if missing
INSERT INTO crm_sources (name)
VALUES 
    ('Manual'),
    ('Website'),
    ('WhatsApp'),
    ('Cold Call'),
    ('Walk-in')
ON CONFLICT (name) DO NOTHING;

-- 2. Create crm_interaction_types table
CREATE TABLE IF NOT EXISTS crm_interaction_types (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name text UNIQUE NOT NULL,
    created_at timestamptz DEFAULT now()
);

-- Enable RLS and add open policy for interaction types
ALTER TABLE crm_interaction_types ENABLE ROW LEVEL SECURITY;

DO $$ 
BEGIN 
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'crm_interaction_types' AND policyname = 'Allow all access to crm_interaction_types'
    ) THEN 
        CREATE POLICY "Allow all access to crm_interaction_types" 
        ON crm_interaction_types FOR ALL 
        USING (true) WITH CHECK (true);
    END IF;
END $$;

INSERT INTO crm_interaction_types (name)
VALUES 
    ('Call'),
    ('WhatsApp'),
    ('Email'),
    ('Meeting'),
    ('Note'),
    ('Site Visit'),
    ('Demo')
ON CONFLICT (name) DO NOTHING;

-- 3. Add reminders jsonb column to crm_leads for multiple alerts
DO $$ 
BEGIN 
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'crm_leads' AND column_name = 'reminders'
    ) THEN 
        ALTER TABLE crm_leads ADD COLUMN reminders jsonb DEFAULT '[]'::jsonb;
    END IF;
END $$;

-- 4. Create Global Leaderboard RPC (bypasses user-scoped RLS for global ranking)
CREATE OR REPLACE FUNCTION get_crm_leaderboard()
RETURNS TABLE (
    user_id uuid,
    user_name text,
    user_email text,
    total_leads bigint,
    won_deals bigint,
    active_leads bigint,
    total_revenue numeric,
    conversion_rate numeric
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    WITH sales_users AS (
        SELECT p.id AS u_id, p.full_name AS u_name, p.email AS u_email
        FROM profiles p
        WHERE p.role IN ('sales', 'sales_head', 'admin', 'manager')
           OR 'sales' = ANY(p.roles)
           OR 'sales_head' = ANY(p.roles)
           OR 'admin' = ANY(p.roles)
    ),
    lead_stats AS (
        SELECT 
            COALESCE(l.assigned_to, l.created_by) AS lead_user_id,
            COUNT(*) AS cnt_total,
            COUNT(*) FILTER (WHERE LOWER(l.status) = 'won') AS cnt_won,
            COUNT(*) FILTER (WHERE LOWER(l.status) NOT IN ('won', 'lost')) AS cnt_active,
            COALESCE(SUM(CASE WHEN LOWER(l.status) = 'won' THEN l.estimated_value ELSE 0 END), 0) AS sum_revenue
        FROM crm_leads l
        GROUP BY COALESCE(l.assigned_to, l.created_by)
    )
    SELECT 
        su.u_id AS user_id,
        COALESCE(su.u_name, 'Sales Representative') AS user_name,
        su.u_email AS user_email,
        COALESCE(ls.cnt_total, 0) AS total_leads,
        COALESCE(ls.cnt_won, 0) AS won_deals,
        COALESCE(ls.cnt_active, 0) AS active_leads,
        COALESCE(ls.sum_revenue, 0)::numeric AS total_revenue,
        CASE 
            WHEN COALESCE(ls.cnt_total, 0) > 0 THEN 
                ROUND((COALESCE(ls.cnt_won, 0)::numeric / ls.cnt_total::numeric) * 100, 1)
            ELSE 0.0 
        END AS conversion_rate
    FROM sales_users su
    LEFT JOIN lead_stats ls ON su.u_id = ls.lead_user_id
    ORDER BY cnt_won DESC, sum_revenue DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION get_crm_leaderboard() TO authenticated;
GRANT EXECUTE ON FUNCTION get_crm_leaderboard() TO anon;
