import psycopg2

conn_str = "dbname='postgres' user='postgres' host='db.dnhbtkhcjpkthvyhyzmt.supabase.co' password='CHTxPuCOTxh2eD5K' port='5432'"
conn = psycopg2.connect(conn_str)
conn.autocommit = True
cur = conn.cursor()

# 1. Add notes column to crm_prospects if not exists
cur.execute("""
    DO $$ 
    BEGIN 
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' AND table_name = 'crm_prospects' AND column_name = 'notes'
        ) THEN 
            ALTER TABLE crm_prospects ADD COLUMN notes text;
        END IF;
    END $$;
""")
print("Added notes column to crm_prospects (if not existed)")

# 2. Add notes column to customers if not exists
cur.execute("""
    DO $$ 
    BEGIN 
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' AND table_name = 'customers' AND column_name = 'notes'
        ) THEN 
            ALTER TABLE customers ADD COLUMN notes text;
        END IF;
    END $$;
""")
print("Added notes column to customers (if not existed)")

# 3. Create global customer sync trigger
cur.execute("""
    CREATE OR REPLACE FUNCTION sync_customer_details_globally()
    RETURNS TRIGGER AS $$
    DECLARE
        v_name text;
    BEGIN
        v_name := COALESCE(NEW.customer_name, NEW.company_name, NEW.contact_person);

        -- Update crm_leads
        UPDATE crm_leads 
        SET prospect_name = COALESCE(v_name, prospect_name),
            contact_phone = COALESCE(NEW.phone, contact_phone),
            updated_at = NOW()
        WHERE converted_to_customer_id = NEW.id;

        -- Update crm_prospects linked through leads
        UPDATE crm_prospects
        SET name = COALESCE(v_name, name),
            phone = COALESCE(NEW.phone, phone),
            email = COALESCE(NEW.email, email),
            address = COALESCE(NEW.address, address),
            gst = COALESCE(NEW.gst_number, gst),
            updated_at = NOW()
        WHERE converted_to_lead_id IN (
            SELECT id FROM crm_leads WHERE converted_to_customer_id = NEW.id
        );

        -- Update quotations denormalized customer info
        UPDATE quotations
        SET customer_name = COALESCE(v_name, customer_name),
            customer_phone = COALESCE(NEW.phone, customer_phone),
            billing_address = COALESCE(NEW.address, billing_address),
            customer_gstin = COALESCE(NEW.gst_number, customer_gstin),
            updated_at = NOW()
        WHERE pipeline_id IN (
            SELECT id FROM sales_pipelines WHERE customer_id = NEW.id
        ) OR lead_id IN (
            SELECT id FROM crm_leads WHERE converted_to_customer_id = NEW.id
        );

        -- Update complaints
        UPDATE complaints
        SET customer_name = COALESCE(v_name, customer_name),
            customer_phone = COALESCE(NEW.phone, customer_phone),
            customer_address = COALESCE(NEW.address, customer_address)
        WHERE customer_id = NEW.id;

        RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;

    DROP TRIGGER IF EXISTS trg_sync_customer_details_globally ON customers;

    CREATE TRIGGER trg_sync_customer_details_globally
    AFTER UPDATE ON customers
    FOR EACH ROW
    EXECUTE FUNCTION sync_customer_details_globally();
""")
print("Created trigger trg_sync_customer_details_globally on customers table")

cur.close()
conn.close()
