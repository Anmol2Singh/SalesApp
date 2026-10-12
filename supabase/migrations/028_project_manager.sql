-- ==============================================================================
-- IZYHEAT Sales App — Migration 028: Project Manager Module
-- ==============================================================================

-- 1. Additive columns to existing customers table (safe & idempotent)
ALTER TABLE customers ADD COLUMN IF NOT EXISTS party_print_name TEXT;
ALTER TABLE customers ADD COLUMN IF NOT EXISTS firm_name TEXT;

-- 2. Projects table (namespaced: pm_projects)
-- Every project links to the EXISTING customers table via customer_id (FK)
CREATE TABLE IF NOT EXISTS pm_projects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  id_no INTEGER UNIQUE NOT NULL,
  customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
  pipeline_id UUID REFERENCES sales_pipelines(id) ON DELETE SET NULL,
  order_type TEXT NOT NULL,
  site_name TEXT NOT NULL,
  address TEXT,
  hp_type TEXT,
  hp_qty INTEGER DEFAULT 0,
  tank_type TEXT,
  tank_qty INTEGER DEFAULT 0,
  gl INTEGER DEFAULT 0,
  sales_m_value NUMERIC(14, 2) DEFAULT 0,
  m_outward_value NUMERIC(14, 2) DEFAULT 0,
  m_balance NUMERIC(14, 2) DEFAULT 0,
  order_value NUMERIC(14, 2) DEFAULT 0,
  extra_work_value NUMERIC(14, 2) DEFAULT 0,
  payment_received NUMERIC(14, 2) DEFAULT 0,
  work_remark TEXT,
  salesman_name TEXT,
  company_id TEXT NOT NULL DEFAULT 'insiya-solar',
  created_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Purchases table (namespaced: pm_purchases for Purchase Mode)
CREATE TABLE IF NOT EXISTS pm_purchases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  id_no INTEGER NOT NULL,
  order_type TEXT NOT NULL,
  site_name TEXT NOT NULL, -- Official Vendor Name
  party_print_name TEXT,
  mobile_number TEXT,
  address TEXT, -- Vendor Address
  firm_name TEXT,
  quotation_value NUMERIC(14, 2) DEFAULT 0,
  payment_paid NUMERIC(14, 2) DEFAULT 0,
  balance NUMERIC(14, 2) DEFAULT 0,
  company_id TEXT NOT NULL DEFAULT 'insiya-solar',
  created_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- Universal compatibility columns
  order_value NUMERIC(14, 2) DEFAULT 0,
  extra_work_value NUMERIC(14, 2) DEFAULT 0,
  payment_received NUMERIC(14, 2) DEFAULT 0,
  salesman_name TEXT,
  work_remark TEXT
);

-- 4. Payment terms table
CREATE TABLE IF NOT EXISTS pm_payment_terms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES pm_projects(id) ON DELETE CASCADE,
  payment_term TEXT NOT NULL,
  term_percentage NUMERIC(5, 2) DEFAULT 0,
  amount NUMERIC(14, 2) DEFAULT 0,
  received_amount NUMERIC(14, 2) DEFAULT 0,
  pending_amount NUMERIC(14, 2) DEFAULT 0,
  remark TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. Financial Ledger Entries (Sales mode)
CREATE TABLE IF NOT EXISTS pm_ledger_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES pm_projects(id) ON DELETE CASCADE,
  sr_no INTEGER NOT NULL,
  date DATE NOT NULL,
  payment_type TEXT,
  reference_number TEXT,
  invoice_no TEXT,
  particulars TEXT,
  bill_submitted BOOLEAN DEFAULT FALSE,
  payment_receipt BOOLEAN DEFAULT FALSE,
  sales_m_value NUMERIC(14, 2) DEFAULT 0,
  m_outward_value NUMERIC(14, 2) DEFAULT 0,
  order_value NUMERIC(14, 2) DEFAULT 0,
  extra_work_value NUMERIC(14, 2) DEFAULT 0,
  payment_received NUMERIC(14, 2) DEFAULT 0,
  work_remark TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. Purchase Ledger Entries (Purchase mode)
CREATE TABLE IF NOT EXISTS pm_purchase_ledger_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  purchase_id UUID NOT NULL REFERENCES pm_purchases(id) ON DELETE CASCADE,
  sr_no INTEGER NOT NULL,
  date DATE NOT NULL,
  payment_type TEXT,
  reference_number TEXT,
  invoice_no TEXT,
  particulars TEXT,
  bill_received BOOLEAN DEFAULT FALSE,
  payment_bill BOOLEAN DEFAULT FALSE,
  quotation_value NUMERIC(14, 2) DEFAULT 0,
  payment_paid NUMERIC(14, 2) DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- Universal compatibility columns
  project_id UUID REFERENCES pm_purchases(id) ON DELETE CASCADE,
  bill_submitted BOOLEAN DEFAULT FALSE,
  payment_receipt BOOLEAN DEFAULT FALSE,
  order_value NUMERIC(14, 2) DEFAULT 0,
  extra_work_value NUMERIC(14, 2) DEFAULT 0,
  payment_received NUMERIC(14, 2) DEFAULT 0,
  sales_m_value NUMERIC(14, 2) DEFAULT 0,
  m_outward_value NUMERIC(14, 2) DEFAULT 0,
  work_remark TEXT
);

-- 7. Direct Project Expenses
CREATE TABLE IF NOT EXISTS pm_expenses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES pm_projects(id) ON DELETE CASCADE,
  sr_no INTEGER NOT NULL,
  date DATE NOT NULL,
  particular TEXT,
  expense NUMERIC(14, 2) DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 8. Calling Records
CREATE TABLE IF NOT EXISTS pm_calling_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID REFERENCES pm_projects(id) ON DELETE CASCADE,
  purchase_id UUID REFERENCES pm_purchases(id) ON DELETE CASCADE,
  sr_no INTEGER DEFAULT 1,
  date DATE NOT NULL,
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT chk_pm_calling_parent CHECK (
    (project_id IS NOT NULL AND purchase_id IS NULL) OR
    (project_id IS NULL AND purchase_id IS NOT NULL)
  )
);

-- 9. SWH Technical Checklist
CREATE TABLE IF NOT EXISTS pm_swh_checklist (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES pm_projects(id) ON DELETE CASCADE,
  sr_no INTEGER DEFAULT 1,
  item_name TEXT NOT NULL,
  req_qty NUMERIC(12, 2) DEFAULT 0,
  customer_scope BOOLEAN DEFAULT FALSE,
  our_scope BOOLEAN DEFAULT FALSE,
  dispatch_qty NUMERIC(12, 2) DEFAULT 0,
  dispatch_yes_no BOOLEAN DEFAULT FALSE,
  installed_qty NUMERIC(12, 2) DEFAULT 0,
  installation_yes_no BOOLEAN DEFAULT FALSE,
  dispatch_balance_qty NUMERIC(12, 2) DEFAULT 0,
  remark TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 10. Work Remarks
CREATE TABLE IF NOT EXISTS pm_work_remarks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES pm_projects(id) ON DELETE CASCADE,
  sr_no INTEGER NOT NULL,
  date DATE NOT NULL,
  remark TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 11. Daily Transactions
CREATE TABLE IF NOT EXISTS pm_daily_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id TEXT NOT NULL DEFAULT 'insiya-solar',
  sr_no INTEGER NOT NULL,
  date DATE NOT NULL DEFAULT CURRENT_DATE,
  firm_name TEXT NOT NULL,
  party_name TEXT NOT NULL,
  payment_mode TEXT NOT NULL,
  transaction_name TEXT NOT NULL,
  entry_nature TEXT NOT NULL CHECK (entry_nature IN ('Purchase', 'Sale', 'Expense')),
  type TEXT NOT NULL CHECK (type IN ('credit', 'debit')),
  debit_amount NUMERIC(14, 2) DEFAULT 0,
  credit_amount NUMERIC(14, 2) DEFAULT 0,
  remark TEXT,
  created_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 12. App Settings table (if not already existing)
CREATE TABLE IF NOT EXISTS pm_app_settings (
  id TEXT PRIMARY KEY,
  value JSONB NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 13. Project Attachments
CREATE TABLE IF NOT EXISTS pm_project_attachments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID REFERENCES pm_projects(id) ON DELETE CASCADE,
  purchase_id UUID REFERENCES pm_purchases(id) ON DELETE CASCADE,
  file_name TEXT NOT NULL,
  file_url TEXT NOT NULL,
  file_size BIGINT,
  uploaded_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==============================================================================
-- PERFORMANCE INDEXES
-- ==============================================================================
CREATE INDEX IF NOT EXISTS idx_pm_projects_customer_id ON pm_projects(customer_id);
CREATE INDEX IF NOT EXISTS idx_pm_projects_pipeline_id ON pm_projects(pipeline_id);
CREATE INDEX IF NOT EXISTS idx_pm_projects_id_no ON pm_projects(id_no);
CREATE INDEX IF NOT EXISTS idx_pm_projects_company_id ON pm_projects(company_id);
CREATE INDEX IF NOT EXISTS idx_pm_projects_created_by ON pm_projects(created_by);

CREATE INDEX IF NOT EXISTS idx_pm_purchases_id_no ON pm_purchases(id_no);
CREATE INDEX IF NOT EXISTS idx_pm_purchases_company_id ON pm_purchases(company_id);

CREATE INDEX IF NOT EXISTS idx_pm_payment_terms_project_id ON pm_payment_terms(project_id);
CREATE INDEX IF NOT EXISTS idx_pm_ledger_entries_project_id ON pm_ledger_entries(project_id);
CREATE INDEX IF NOT EXISTS idx_pm_purchase_ledger_purchase_id ON pm_purchase_ledger_entries(purchase_id);
CREATE INDEX IF NOT EXISTS idx_pm_expenses_project_id ON pm_expenses(project_id);
CREATE INDEX IF NOT EXISTS idx_pm_calling_records_project_id ON pm_calling_records(project_id);
CREATE INDEX IF NOT EXISTS idx_pm_calling_records_purchase_id ON pm_calling_records(purchase_id);
CREATE INDEX IF NOT EXISTS idx_pm_swh_checklist_project_id ON pm_swh_checklist(project_id);
CREATE INDEX IF NOT EXISTS idx_pm_work_remarks_project_id ON pm_work_remarks(project_id);
CREATE INDEX IF NOT EXISTS idx_pm_daily_tx_company_date ON pm_daily_transactions(company_id, date);
CREATE INDEX IF NOT EXISTS idx_pm_daily_tx_firm ON pm_daily_transactions(firm_name);
CREATE INDEX IF NOT EXISTS idx_pm_daily_tx_party ON pm_daily_transactions(party_name);

-- ==============================================================================
-- TRIGGERS: auto-update updated_at
-- ==============================================================================
DROP TRIGGER IF EXISTS trg_pm_projects_updated_at ON pm_projects;
CREATE TRIGGER trg_pm_projects_updated_at
  BEFORE UPDATE ON pm_projects
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS trg_pm_purchases_updated_at ON pm_purchases;
CREATE TRIGGER trg_pm_purchases_updated_at
  BEFORE UPDATE ON pm_purchases
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS trg_pm_payment_terms_updated_at ON pm_payment_terms;
CREATE TRIGGER trg_pm_payment_terms_updated_at
  BEFORE UPDATE ON pm_payment_terms
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS trg_pm_ledger_entries_updated_at ON pm_ledger_entries;
CREATE TRIGGER trg_pm_ledger_entries_updated_at
  BEFORE UPDATE ON pm_ledger_entries
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS trg_pm_purchase_ledger_updated_at ON pm_purchase_ledger_entries;
CREATE TRIGGER trg_pm_purchase_ledger_updated_at
  BEFORE UPDATE ON pm_purchase_ledger_entries
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS trg_pm_swh_checklist_updated_at ON pm_swh_checklist;
CREATE TRIGGER trg_pm_swh_checklist_updated_at
  BEFORE UPDATE ON pm_swh_checklist
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS trg_pm_daily_transactions_updated_at ON pm_daily_transactions;
CREATE TRIGGER trg_pm_daily_transactions_updated_at
  BEFORE UPDATE ON pm_daily_transactions
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ==============================================================================
-- TRIGGERS: Financial Synchronisation & Balance Calculation
-- ==============================================================================

-- 1. Synchronize Purchase compat columns and balance
CREATE OR REPLACE FUNCTION pm_sync_purchase_compat()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.quotation_value IS NOT NULL AND (NEW.order_value IS NULL OR NEW.order_value = 0) THEN
    NEW.order_value := NEW.quotation_value;
  ELSIF NEW.order_value IS NOT NULL AND (NEW.quotation_value IS NULL OR NEW.quotation_value = 0) THEN
    NEW.quotation_value := NEW.order_value;
  END IF;

  IF NEW.payment_paid IS NOT NULL AND (NEW.payment_received IS NULL OR NEW.payment_received = 0) THEN
    NEW.payment_received := NEW.payment_paid;
  ELSIF NEW.payment_received IS NOT NULL AND (NEW.payment_paid IS NULL OR NEW.payment_paid = 0) THEN
    NEW.payment_paid := NEW.payment_received;
  END IF;

  NEW.balance := COALESCE(NEW.quotation_value, NEW.order_value, 0) - COALESCE(NEW.payment_paid, NEW.payment_received, 0);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_pm_sync_purchase_compat ON pm_purchases;
CREATE TRIGGER trg_pm_sync_purchase_compat
  BEFORE INSERT OR UPDATE ON pm_purchases
  FOR EACH ROW EXECUTE FUNCTION pm_sync_purchase_compat();

-- 2. Synchronize Project balance calculation
CREATE OR REPLACE FUNCTION pm_sync_project_balances()
RETURNS TRIGGER AS $$
BEGIN
  NEW.m_balance := COALESCE(NEW.sales_m_value, 0) - COALESCE(NEW.m_outward_value, 0);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_pm_sync_project_balances ON pm_projects;
CREATE TRIGGER trg_pm_sync_project_balances
  BEFORE INSERT OR UPDATE ON pm_projects
  FOR EACH ROW EXECUTE FUNCTION pm_sync_project_balances();

-- ==============================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ==============================================================================
ALTER TABLE pm_projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE pm_purchases ENABLE ROW LEVEL SECURITY;
ALTER TABLE pm_payment_terms ENABLE ROW LEVEL SECURITY;
ALTER TABLE pm_ledger_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE pm_purchase_ledger_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE pm_expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE pm_calling_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE pm_swh_checklist ENABLE ROW LEVEL SECURITY;
ALTER TABLE pm_work_remarks ENABLE ROW LEVEL SECURITY;
ALTER TABLE pm_daily_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE pm_app_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE pm_project_attachments ENABLE ROW LEVEL SECURITY;

-- Helper functions exist in 002_rls_policies.sql: get_my_role(), is_active_user()
-- Admin & Manager: Full access across all pm_* tables
CREATE POLICY pm_projects_admin_all ON pm_projects
  FOR ALL TO authenticated
  USING (get_my_role() IN ('admin', 'manager'))
  WITH CHECK (get_my_role() IN ('admin', 'manager'));

CREATE POLICY pm_purchases_admin_all ON pm_purchases
  FOR ALL TO authenticated
  USING (get_my_role() IN ('admin', 'manager'))
  WITH CHECK (get_my_role() IN ('admin', 'manager'));

CREATE POLICY pm_payment_terms_admin_all ON pm_payment_terms
  FOR ALL TO authenticated
  USING (get_my_role() IN ('admin', 'manager'))
  WITH CHECK (get_my_role() IN ('admin', 'manager'));

CREATE POLICY pm_ledger_entries_admin_all ON pm_ledger_entries
  FOR ALL TO authenticated
  USING (get_my_role() IN ('admin', 'manager'))
  WITH CHECK (get_my_role() IN ('admin', 'manager'));

CREATE POLICY pm_purchase_ledger_admin_all ON pm_purchase_ledger_entries
  FOR ALL TO authenticated
  USING (get_my_role() IN ('admin', 'manager'))
  WITH CHECK (get_my_role() IN ('admin', 'manager'));

CREATE POLICY pm_expenses_admin_all ON pm_expenses
  FOR ALL TO authenticated
  USING (get_my_role() IN ('admin', 'manager'))
  WITH CHECK (get_my_role() IN ('admin', 'manager'));

CREATE POLICY pm_calling_records_admin_all ON pm_calling_records
  FOR ALL TO authenticated
  USING (get_my_role() IN ('admin', 'manager'))
  WITH CHECK (get_my_role() IN ('admin', 'manager'));

CREATE POLICY pm_swh_checklist_admin_all ON pm_swh_checklist
  FOR ALL TO authenticated
  USING (get_my_role() IN ('admin', 'manager'))
  WITH CHECK (get_my_role() IN ('admin', 'manager'));

CREATE POLICY pm_work_remarks_admin_all ON pm_work_remarks
  FOR ALL TO authenticated
  USING (get_my_role() IN ('admin', 'manager'))
  WITH CHECK (get_my_role() IN ('admin', 'manager'));

CREATE POLICY pm_daily_transactions_admin_all ON pm_daily_transactions
  FOR ALL TO authenticated
  USING (get_my_role() IN ('admin', 'manager'))
  WITH CHECK (get_my_role() IN ('admin', 'manager'));

CREATE POLICY pm_app_settings_admin_all ON pm_app_settings
  FOR ALL TO authenticated
  USING (get_my_role() IN ('admin', 'manager'))
  WITH CHECK (get_my_role() IN ('admin', 'manager'));

CREATE POLICY pm_project_attachments_admin_all ON pm_project_attachments
  FOR ALL TO authenticated
  USING (get_my_role() IN ('admin', 'manager'))
  WITH CHECK (get_my_role() IN ('admin', 'manager'));

-- Sales Executives (sales, sales_head):
-- Can read/write projects they created, or linked to customers they own or are assigned to
CREATE POLICY pm_projects_sales_access ON pm_projects
  FOR ALL TO authenticated
  USING (
    get_my_role() IN ('sales', 'sales_head')
    AND (
      created_by = auth.uid()
      OR EXISTS (
        SELECT 1 FROM customers c
        WHERE c.id = pm_projects.customer_id
          AND (c.created_by = auth.uid() OR c.assigned_to = auth.uid() OR get_my_role() = 'sales_head')
      )
    )
  )
  WITH CHECK (
    get_my_role() IN ('sales', 'sales_head')
  );

-- Sales child tables access
CREATE POLICY pm_payment_terms_sales_access ON pm_payment_terms
  FOR ALL TO authenticated
  USING (
    EXISTS (SELECT 1 FROM pm_projects p WHERE p.id = pm_payment_terms.project_id)
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM pm_projects p WHERE p.id = pm_payment_terms.project_id)
  );

CREATE POLICY pm_ledger_entries_sales_access ON pm_ledger_entries
  FOR ALL TO authenticated
  USING (
    EXISTS (SELECT 1 FROM pm_projects p WHERE p.id = pm_ledger_entries.project_id)
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM pm_projects p WHERE p.id = pm_ledger_entries.project_id)
  );

CREATE POLICY pm_expenses_sales_access ON pm_expenses
  FOR ALL TO authenticated
  USING (
    EXISTS (SELECT 1 FROM pm_projects p WHERE p.id = pm_expenses.project_id)
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM pm_projects p WHERE p.id = pm_expenses.project_id)
  );

CREATE POLICY pm_calling_records_sales_access ON pm_calling_records
  FOR ALL TO authenticated
  USING (
    (project_id IS NOT NULL AND EXISTS (SELECT 1 FROM pm_projects p WHERE p.id = pm_calling_records.project_id))
    OR (purchase_id IS NOT NULL AND get_my_role() IN ('admin', 'manager', 'purchase'))
  )
  WITH CHECK (
    (project_id IS NOT NULL AND EXISTS (SELECT 1 FROM pm_projects p WHERE p.id = pm_calling_records.project_id))
    OR (purchase_id IS NOT NULL AND get_my_role() IN ('admin', 'manager', 'purchase'))
  );

CREATE POLICY pm_swh_checklist_sales_access ON pm_swh_checklist
  FOR ALL TO authenticated
  USING (
    EXISTS (SELECT 1 FROM pm_projects p WHERE p.id = pm_swh_checklist.project_id)
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM pm_projects p WHERE p.id = pm_swh_checklist.project_id)
  );

CREATE POLICY pm_work_remarks_sales_access ON pm_work_remarks
  FOR ALL TO authenticated
  USING (
    EXISTS (SELECT 1 FROM pm_projects p WHERE p.id = pm_work_remarks.project_id)
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM pm_projects p WHERE p.id = pm_work_remarks.project_id)
  );

-- Purchase role access
CREATE POLICY pm_purchases_purchase_staff ON pm_purchases
  FOR ALL TO authenticated
  USING (get_my_role() = 'purchase')
  WITH CHECK (get_my_role() = 'purchase');

CREATE POLICY pm_purchase_ledger_purchase_staff ON pm_purchase_ledger_entries
  FOR ALL TO authenticated
  USING (get_my_role() = 'purchase')
  WITH CHECK (get_my_role() = 'purchase');

-- Factory & Service Staff: Read-only access to projects & checklists
CREATE POLICY pm_projects_factory_read ON pm_projects
  FOR SELECT TO authenticated
  USING (get_my_role() IN ('factory', 'service_head', 'installation', 'technician', 'boq'));

CREATE POLICY pm_swh_checklist_factory_all ON pm_swh_checklist
  FOR ALL TO authenticated
  USING (get_my_role() IN ('factory', 'installation', 'technician'))
  WITH CHECK (get_my_role() IN ('factory', 'installation', 'technician'));

-- Daily transactions role access
CREATE POLICY pm_daily_transactions_authenticated ON pm_daily_transactions
  FOR ALL TO authenticated
  USING (is_active_user())
  WITH CHECK (is_active_user());

-- App settings: Read for all active authenticated users, write for admin/manager
CREATE POLICY pm_app_settings_read ON pm_app_settings
  FOR SELECT TO authenticated
  USING (is_active_user());

-- ==============================================================================
-- REALTIME PUBLICATION
-- ==============================================================================
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    BEGIN
      ALTER PUBLICATION supabase_realtime ADD TABLE pm_projects;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
    BEGIN
      ALTER PUBLICATION supabase_realtime ADD TABLE pm_purchases;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
    BEGIN
      ALTER PUBLICATION supabase_realtime ADD TABLE pm_ledger_entries;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
    BEGIN
      ALTER PUBLICATION supabase_realtime ADD TABLE pm_daily_transactions;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
  END IF;
END $$;

-- ==============================================================================
-- STORAGE BUCKET: pm-attachments
-- ==============================================================================
INSERT INTO storage.buckets (id, name, public)
VALUES ('pm-attachments', 'pm-attachments', true)
ON CONFLICT (id) DO NOTHING;

DO $$
BEGIN
  DROP POLICY IF EXISTS "Authenticated users can upload project attachments" ON storage.objects;
  CREATE POLICY "Authenticated users can upload project attachments"
    ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'pm-attachments');

  DROP POLICY IF EXISTS "Public can view project attachments" ON storage.objects;
  CREATE POLICY "Public can view project attachments"
    ON storage.objects FOR SELECT TO public
    USING (bucket_id = 'pm-attachments');

  DROP POLICY IF EXISTS "Authenticated users can delete project attachments" ON storage.objects;
  CREATE POLICY "Authenticated users can delete project attachments"
    ON storage.objects FOR DELETE TO authenticated
    USING (bucket_id = 'pm-attachments');
EXCEPTION WHEN OTHERS THEN NULL;
END $$;
