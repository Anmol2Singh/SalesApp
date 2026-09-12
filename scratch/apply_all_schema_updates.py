import psycopg2

conn_str = "dbname='postgres' user='postgres' host='db.dnhbtkhcjpkthvyhyzmt.supabase.co' password='CHTxPuCOTxh2eD5K' port='5432'"
conn = psycopg2.connect(conn_str)
conn.autocommit = True
cur = conn.cursor()

# 1. Add source and notes to complaints
cur.execute("""
    DO $$ 
    BEGIN 
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' AND table_name = 'complaints' AND column_name = 'source'
        ) THEN 
            ALTER TABLE complaints ADD COLUMN source text DEFAULT 'staff';
        END IF;

        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' AND table_name = 'complaints' AND column_name = 'notes'
        ) THEN 
            ALTER TABLE complaints ADD COLUMN notes text;
        END IF;
    END $$;
""")
print("Added source and notes to complaints")

# 2. Fix foreign key on complaints.technician_id if needed
cur.execute("""
    DO $$
    BEGIN
        IF EXISTS (
            SELECT 1 FROM pg_constraint WHERE conname = 'complaints_technician_id_fkey'
        ) THEN
            ALTER TABLE complaints DROP CONSTRAINT complaints_technician_id_fkey;
        END IF;
    END $$;
""")
print("Removed rigid complaints_technician_id_fkey to allow flexible technician allocation")

# 3. Add quotation deal-value auto-sync trigger to crm_leads (Task 2.2)
cur.execute("""
    CREATE OR REPLACE FUNCTION sync_quotation_deal_value_to_lead()
    RETURNS TRIGGER AS $$
    BEGIN
        IF NEW.lead_id IS NOT NULL AND NEW.grand_total IS NOT NULL THEN
            UPDATE crm_leads 
            SET estimated_value = NEW.grand_total,
                updated_at = NOW()
            WHERE id = NEW.lead_id;
        END IF;
        RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;

    DROP TRIGGER IF EXISTS trg_sync_quotation_deal_value_to_lead ON quotations;

    CREATE TRIGGER trg_sync_quotation_deal_value_to_lead
    AFTER INSERT OR UPDATE OF grand_total, lead_id ON quotations
    FOR EACH ROW
    EXECUTE FUNCTION sync_quotation_deal_value_to_lead();
""")
print("Created trigger trg_sync_quotation_deal_value_to_lead on quotations table")

# 4. Add is_final to quotations (Task 2.4)
cur.execute("""
    DO $$ 
    BEGIN 
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' AND table_name = 'quotations' AND column_name = 'is_final'
        ) THEN 
            ALTER TABLE quotations ADD COLUMN is_final boolean DEFAULT false;
        END IF;
    END $$;
""")
print("Added is_final column to quotations")

# 5. Add reminder columns to crm_leads (Task 2.6)
cur.execute("""
    DO $$ 
    BEGIN 
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' AND table_name = 'crm_leads' AND column_name = 'reminder_date'
        ) THEN 
            ALTER TABLE crm_leads ADD COLUMN reminder_date timestamptz;
        END IF;

        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' AND table_name = 'crm_leads' AND column_name = 'reminder_note'
        ) THEN 
            ALTER TABLE crm_leads ADD COLUMN reminder_note text;
        END IF;
    END $$;
""")
print("Added reminder_date and reminder_note to crm_leads")

cur.close()
conn.close()
