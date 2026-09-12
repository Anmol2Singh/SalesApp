-- ============================================================
-- Migration 009: Production Readiness (P1 - P6) Schema Updates
-- ============================================================

-- 1. Notes column on crm_prospects
ALTER TABLE crm_prospects ADD COLUMN IF NOT EXISTS notes text;

-- 2. Notes column on customers
ALTER TABLE customers ADD COLUMN IF NOT EXISTS notes text;

-- 3. Source and notes on complaints
ALTER TABLE complaints ADD COLUMN IF NOT EXISTS source text DEFAULT 'staff';
ALTER TABLE complaints ADD COLUMN IF NOT EXISTS notes text;

-- 4. Final quotation marker
ALTER TABLE quotations ADD COLUMN IF NOT EXISTS is_final boolean DEFAULT false;

-- 5. Reminder columns on crm_leads
ALTER TABLE crm_leads ADD COLUMN IF NOT EXISTS reminder_date timestamptz;
ALTER TABLE crm_leads ADD COLUMN IF NOT EXISTS reminder_note text;

-- 6. Flexible foreign key constraint on complaints.technician_id
ALTER TABLE complaints DROP CONSTRAINT IF EXISTS complaints_technician_id_fkey;

-- 7. Global customer data sync trigger
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

-- 8. Quotation deal value auto-sync trigger to crm_leads
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
