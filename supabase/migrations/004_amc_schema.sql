-- ============================================================
-- IZYHEAT Sales App — Migration 004: AMC (Annual Maintenance Contract) Schema
-- ============================================================

-- ============================================================
-- EXTEND EXISTING ENUMS
-- ============================================================

-- Add amc_contract to document_type for PDF templates
ALTER TYPE document_type ADD VALUE IF NOT EXISTS 'amc_contract';

-- Add AMC notification types
ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'amc_visit_due_soon';
ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'amc_visit_missed';
ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'amc_expiring_soon';
ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'amc_expired';

-- Add AMC audit actions
ALTER TYPE audit_action ADD VALUE IF NOT EXISTS 'amc_created';
ALTER TYPE audit_action ADD VALUE IF NOT EXISTS 'amc_activated';
ALTER TYPE audit_action ADD VALUE IF NOT EXISTS 'amc_visit_completed';
ALTER TYPE audit_action ADD VALUE IF NOT EXISTS 'amc_renewed';
ALTER TYPE audit_action ADD VALUE IF NOT EXISTS 'amc_expired';
ALTER TYPE audit_action ADD VALUE IF NOT EXISTS 'amc_cancelled';

-- ============================================================
-- NEW ENUMS
-- ============================================================

CREATE TYPE amc_contract_status AS ENUM (
  'interested',
  'pending_setup',
  'active',
  'expiring_soon',
  'expired',
  'cancelled'
);

CREATE TYPE amc_visit_status AS ENUM (
  'scheduled',
  'completed',
  'missed',
  'rescheduled'
);

-- ============================================================
-- EXTEND EXISTING TABLES
-- ============================================================

-- Make step_audit_log.pipeline_id nullable so AMC-only entries work
ALTER TABLE step_audit_log ALTER COLUMN pipeline_id DROP NOT NULL;

-- Add amc_contract_id for AMC audit entries
ALTER TABLE step_audit_log ADD COLUMN amc_contract_id UUID;
-- FK will be added after table creation below

-- Add related_amc_id to notifications for AMC-specific navigation
ALTER TABLE notifications ADD COLUMN related_amc_id UUID;

-- ============================================================
-- TABLE: amc_contracts
-- ============================================================

CREATE TABLE amc_contracts (
  id                       UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  customer_id              UUID NOT NULL REFERENCES customers(id),
  pipeline_id              UUID REFERENCES sales_pipelines(id),
  product_id               UUID NOT NULL REFERENCES products(id),
  amc_number               TEXT NOT NULL UNIQUE,
  status                   amc_contract_status NOT NULL DEFAULT 'interested',
  start_date               DATE,
  end_date                 DATE,
  contract_amount          NUMERIC(15,2),
  number_of_visits_included INT,
  terms_text               TEXT,
  pdf_url                  TEXT,
  created_by               UUID NOT NULL REFERENCES profiles(id),
  created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at               TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_amc_contracts_customer_id ON amc_contracts(customer_id);
CREATE INDEX idx_amc_contracts_product_id ON amc_contracts(product_id);
CREATE INDEX idx_amc_contracts_pipeline_id ON amc_contracts(pipeline_id);
CREATE INDEX idx_amc_contracts_status ON amc_contracts(status);
CREATE INDEX idx_amc_contracts_customer_product ON amc_contracts(customer_id, product_id);
CREATE INDEX idx_amc_contracts_end_date ON amc_contracts(end_date);
CREATE INDEX idx_amc_contracts_created_by ON amc_contracts(created_by);

CREATE TRIGGER amc_contracts_updated_at
  BEFORE UPDATE ON amc_contracts
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Auto-generate AMC number: IZY/AMC/YYYY/NNNN
CREATE SEQUENCE amc_seq;

CREATE OR REPLACE FUNCTION generate_amc_number()
RETURNS TRIGGER AS $$
DECLARE
  year_str TEXT := TO_CHAR(NOW(), 'YYYY');
  seq_num  INT;
BEGIN
  seq_num := NEXTVAL('amc_seq');
  NEW.amc_number := 'IZY/AMC/' || year_str || '/' || LPAD(seq_num::TEXT, 4, '0');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_amc_number
  BEFORE INSERT ON amc_contracts
  FOR EACH ROW
  WHEN (NEW.amc_number IS NULL OR NEW.amc_number = '')
  EXECUTE FUNCTION generate_amc_number();

-- Now add the FK on step_audit_log
ALTER TABLE step_audit_log
  ADD CONSTRAINT fk_audit_amc_contract
  FOREIGN KEY (amc_contract_id) REFERENCES amc_contracts(id);

-- And on notifications
ALTER TABLE notifications
  ADD CONSTRAINT fk_notifications_amc
  FOREIGN KEY (related_amc_id) REFERENCES amc_contracts(id);

-- ============================================================
-- TABLE: amc_service_visits
-- ============================================================

CREATE TABLE amc_service_visits (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  amc_contract_id   UUID NOT NULL REFERENCES amc_contracts(id) ON DELETE CASCADE,
  visit_number      INT NOT NULL,
  scheduled_date    DATE NOT NULL,
  completed_date    DATE,
  status            amc_visit_status NOT NULL DEFAULT 'scheduled',
  assigned_to       UUID REFERENCES profiles(id),
  service_notes     TEXT,
  customer_signoff  BOOLEAN NOT NULL DEFAULT FALSE,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_amc_visits_contract_id ON amc_service_visits(amc_contract_id);
CREATE INDEX idx_amc_visits_status ON amc_service_visits(status);
CREATE INDEX idx_amc_visits_scheduled_date ON amc_service_visits(scheduled_date);
CREATE INDEX idx_amc_visits_assigned_to ON amc_service_visits(assigned_to);

CREATE TRIGGER amc_visits_updated_at
  BEFORE UPDATE ON amc_service_visits
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- RLS POLICIES
-- ============================================================

ALTER TABLE amc_contracts ENABLE ROW LEVEL SECURITY;
ALTER TABLE amc_service_visits ENABLE ROW LEVEL SECURITY;

-- amc_contracts: Sales sees own (via created_by), Admin sees all
CREATE POLICY amc_contracts_sales_own ON amc_contracts
  FOR ALL
  TO authenticated
  USING (
    get_my_role() = 'sales'
    AND created_by = auth.uid()
  )
  WITH CHECK (
    get_my_role() = 'sales'
    AND created_by = auth.uid()
  );

CREATE POLICY amc_contracts_admin_all ON amc_contracts
  FOR ALL
  TO authenticated
  USING (get_my_role() = 'admin')
  WITH CHECK (get_my_role() = 'admin');

-- amc_service_visits: Sales sees visits for own contracts, Admin sees all
CREATE POLICY amc_visits_sales_own ON amc_service_visits
  FOR ALL
  TO authenticated
  USING (
    get_my_role() = 'sales'
    AND amc_contract_id IN (
      SELECT id FROM amc_contracts WHERE created_by = auth.uid()
    )
  )
  WITH CHECK (
    get_my_role() = 'sales'
    AND amc_contract_id IN (
      SELECT id FROM amc_contracts WHERE created_by = auth.uid()
    )
  );

CREATE POLICY amc_visits_admin_all ON amc_service_visits
  FOR ALL
  TO authenticated
  USING (get_my_role() = 'admin')
  WITH CHECK (get_my_role() = 'admin');

-- Extend audit log RLS: allow reading AMC audit entries
-- The existing insert policy (performed_by = auth.uid()) still works
-- The existing admin read policy already allows reading all
-- Sales need to also read AMC audit entries for their own contracts:
CREATE POLICY audit_log_sales_amc_read ON step_audit_log
  FOR SELECT
  TO authenticated
  USING (
    get_my_role() = 'sales'
    AND amc_contract_id IS NOT NULL
    AND amc_contract_id IN (
      SELECT id FROM amc_contracts WHERE created_by = auth.uid()
    )
  );

-- ============================================================
-- UPDATE DASHBOARD STATS RPC
-- ============================================================

DROP FUNCTION IF EXISTS get_dashboard_stats(text);
CREATE OR REPLACE FUNCTION get_dashboard_stats(time_filter TEXT DEFAULT 'month')
RETURNS JSON AS $$
DECLARE
  start_date TIMESTAMPTZ;
  result JSON;
BEGIN
  start_date := CASE time_filter
    WHEN 'today' THEN DATE_TRUNC('day', NOW())
    WHEN 'week'  THEN DATE_TRUNC('week', NOW())
    WHEN 'month' THEN DATE_TRUNC('month', NOW())
    WHEN 'year'  THEN DATE_TRUNC('year', NOW())
    ELSE DATE_TRUNC('month', NOW())
  END;

  SELECT JSON_BUILD_OBJECT(
    'new_customers', (SELECT COUNT(*) FROM customers WHERE created_at >= start_date AND deleted_at IS NULL),
    'new_pipelines', (SELECT COUNT(*) FROM sales_pipelines WHERE created_at >= start_date AND deleted_at IS NULL),
    'confirmed_quotations', (SELECT COUNT(*) FROM quotations WHERE confirmed_at >= start_date AND status = 'confirmed' AND deleted_at IS NULL),
    'completed_pipelines', (SELECT COUNT(*) FROM sales_pipelines WHERE updated_at >= start_date AND status = 'completed' AND deleted_at IS NULL),
    'pipeline_by_step', (
      SELECT JSON_OBJECT_AGG(current_step, cnt)
      FROM (
        SELECT current_step, COUNT(*) AS cnt
        FROM sales_pipelines
        WHERE deleted_at IS NULL AND status != 'cancelled'
        GROUP BY current_step
      ) sub
    ),
    'amc_expiring_soon', (SELECT COUNT(*) FROM amc_contracts WHERE status = 'expiring_soon'),
    'active_amcs', (SELECT COUNT(*) FROM amc_contracts WHERE status = 'active'),
    'total_pipelines', (SELECT COUNT(*) FROM sales_pipelines WHERE deleted_at IS NULL),
    'in_progress', (SELECT COUNT(*) FROM sales_pipelines WHERE status = 'in_progress' AND deleted_at IS NULL),
    'completed', (SELECT COUNT(*) FROM sales_pipelines WHERE status = 'completed' AND deleted_at IS NULL),
    'total_customers', (SELECT COUNT(*) FROM customers WHERE deleted_at IS NULL),
    'factory_queue', (SELECT COUNT(*) FROM sales_pipelines WHERE current_step = 'factory_order' AND status = 'in_progress' AND deleted_at IS NULL),
    'purchase_queue', (SELECT COUNT(*) FROM sales_pipelines WHERE current_step = 'purchase_order' AND status = 'in_progress' AND deleted_at IS NULL)
  ) INTO result;

  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- SEED: Default AMC PDF template
-- ============================================================

INSERT INTO pdf_templates (document_type, template_config, is_active)
VALUES (
  'amc_contract',
  '{
    "company_name": "IZYHEAT",
    "company_address": "IZYHEAT Office, India",
    "company_phone": "+91 99999 99999",
    "company_email": "info@izyheat.com",
    "company_gst": "27AAAAA1111A1Z1",
    "footer_text": "This is a computer-generated AMC agreement.",
    "terms_default": "1. The AMC covers preventive maintenance visits as per the schedule.\n2. Spare parts and consumables are charged separately.\n3. The contract is non-transferable.\n4. Service calls outside the scheduled visits will be charged additionally.\n5. The customer shall provide access to the equipment during scheduled visits.\n6. Renewal is subject to mutual agreement and revised pricing."
  }'::jsonb,
  TRUE
)
ON CONFLICT (document_type) DO NOTHING;
