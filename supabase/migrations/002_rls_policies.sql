-- ============================================================
-- IZYHEAT Sales App — Migration 002: RLS Policies
-- ============================================================

-- Enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales_pipelines ENABLE ROW LEVEL SECURITY;
ALTER TABLE quotations ENABLE ROW LEVEL SECURITY;
ALTER TABLE boqs ENABLE ROW LEVEL SECURITY;
ALTER TABLE factory_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE step_audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE pdf_templates ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- HELPER FUNCTION: Get current user role
-- ============================================================

CREATE OR REPLACE FUNCTION get_my_role()
RETURNS user_role AS $$
  SELECT role FROM profiles WHERE id = auth.uid() AND deleted_at IS NULL LIMIT 1;
$$ LANGUAGE SQL SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION is_active_user()
RETURNS BOOLEAN AS $$
  SELECT COALESCE(is_active, FALSE) FROM profiles WHERE id = auth.uid() AND deleted_at IS NULL LIMIT 1;
$$ LANGUAGE SQL SECURITY DEFINER STABLE;

-- ============================================================
-- TABLE: profiles
-- ============================================================

-- Admin: full access
CREATE POLICY profiles_admin_all ON profiles
  FOR ALL
  TO authenticated
  USING (get_my_role() = 'admin')
  WITH CHECK (get_my_role() = 'admin');

-- All authenticated users: read their own profile
CREATE POLICY profiles_own_select ON profiles
  FOR SELECT
  TO authenticated
  USING (id = auth.uid());

-- All authenticated users: update their own FCM token
CREATE POLICY profiles_own_fcm_update ON profiles
  FOR UPDATE
  TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- ============================================================
-- TABLE: products
-- ============================================================

-- All authenticated users: read active products
CREATE POLICY products_read ON products
  FOR SELECT
  TO authenticated
  USING (is_active = TRUE AND deleted_at IS NULL);

-- Admin only: insert/update/delete
CREATE POLICY products_admin_write ON products
  FOR ALL
  TO authenticated
  USING (get_my_role() = 'admin')
  WITH CHECK (get_my_role() = 'admin');

-- ============================================================
-- TABLE: customers
-- ============================================================

-- Sales: read/write own customers
CREATE POLICY customers_sales_own ON customers
  FOR ALL
  TO authenticated
  USING (
    get_my_role() = 'sales'
    AND created_by = auth.uid()
    AND deleted_at IS NULL
  )
  WITH CHECK (
    get_my_role() = 'sales'
    AND created_by = auth.uid()
  );

-- Admin: read/write all customers
CREATE POLICY customers_admin_all ON customers
  FOR ALL
  TO authenticated
  USING (get_my_role() = 'admin' AND deleted_at IS NULL)
  WITH CHECK (get_my_role() = 'admin');

-- ============================================================
-- TABLE: sales_pipelines
-- ============================================================

-- Sales: own pipelines only
CREATE POLICY pipelines_sales_own ON sales_pipelines
  FOR ALL
  TO authenticated
  USING (
    get_my_role() = 'sales'
    AND created_by = auth.uid()
    AND deleted_at IS NULL
  )
  WITH CHECK (
    get_my_role() = 'sales'
    AND created_by = auth.uid()
  );

-- Admin: all pipelines
CREATE POLICY pipelines_admin_all ON sales_pipelines
  FOR ALL
  TO authenticated
  USING (get_my_role() = 'admin' AND deleted_at IS NULL)
  WITH CHECK (get_my_role() = 'admin');

-- Factory: read pipelines at factory_order or purchase_order step
CREATE POLICY pipelines_factory_read ON sales_pipelines
  FOR SELECT
  TO authenticated
  USING (
    get_my_role() = 'factory'
    AND current_step IN ('factory_order', 'purchase_order', 'completed')
    AND deleted_at IS NULL
  );

-- Purchase: read pipelines at purchase_order step
CREATE POLICY pipelines_purchase_read ON sales_pipelines
  FOR SELECT
  TO authenticated
  USING (
    get_my_role() = 'purchase'
    AND current_step IN ('purchase_order', 'completed')
    AND deleted_at IS NULL
  );

-- ============================================================
-- TABLE: quotations
-- ============================================================

-- Sales: quotations for own pipelines
CREATE POLICY quotations_sales_own ON quotations
  FOR ALL
  TO authenticated
  USING (
    get_my_role() = 'sales'
    AND pipeline_id IN (
      SELECT id FROM sales_pipelines WHERE created_by = auth.uid() AND deleted_at IS NULL
    )
    AND deleted_at IS NULL
  )
  WITH CHECK (
    get_my_role() = 'sales'
    AND pipeline_id IN (
      SELECT id FROM sales_pipelines WHERE created_by = auth.uid() AND deleted_at IS NULL
    )
  );

-- Admin: all quotations
CREATE POLICY quotations_admin_all ON quotations
  FOR ALL
  TO authenticated
  USING (get_my_role() = 'admin' AND deleted_at IS NULL)
  WITH CHECK (get_my_role() = 'admin');

-- Factory & Purchase: NO access to quotations (no policy = no access)

-- ============================================================
-- TABLE: boqs
-- ============================================================

-- Sales: BOQs for own pipelines
CREATE POLICY boqs_sales_own ON boqs
  FOR ALL
  TO authenticated
  USING (
    get_my_role() = 'sales'
    AND pipeline_id IN (
      SELECT id FROM sales_pipelines WHERE created_by = auth.uid() AND deleted_at IS NULL
    )
    AND deleted_at IS NULL
  )
  WITH CHECK (
    get_my_role() = 'sales'
    AND pipeline_id IN (
      SELECT id FROM sales_pipelines WHERE created_by = auth.uid() AND deleted_at IS NULL
    )
  );

-- Admin: all BOQs
CREATE POLICY boqs_admin_all ON boqs
  FOR ALL
  TO authenticated
  USING (get_my_role() = 'admin' AND deleted_at IS NULL)
  WITH CHECK (get_my_role() = 'admin');

-- Factory & Purchase: NO access to BOQs

-- ============================================================
-- TABLE: factory_orders
-- ============================================================

-- Sales: factory orders for own pipelines (read only after submission)
CREATE POLICY factory_orders_sales_own ON factory_orders
  FOR ALL
  TO authenticated
  USING (
    get_my_role() = 'sales'
    AND pipeline_id IN (
      SELECT id FROM sales_pipelines WHERE created_by = auth.uid() AND deleted_at IS NULL
    )
    AND deleted_at IS NULL
  )
  WITH CHECK (
    get_my_role() = 'sales'
    AND pipeline_id IN (
      SELECT id FROM sales_pipelines WHERE created_by = auth.uid() AND deleted_at IS NULL
    )
  );

-- Admin: all factory orders
CREATE POLICY factory_orders_admin_all ON factory_orders
  FOR ALL
  TO authenticated
  USING (get_my_role() = 'admin' AND deleted_at IS NULL)
  WITH CHECK (get_my_role() = 'admin');

-- Factory: full access to factory orders
CREATE POLICY factory_orders_factory_all ON factory_orders
  FOR ALL
  TO authenticated
  USING (get_my_role() = 'factory' AND deleted_at IS NULL)
  WITH CHECK (get_my_role() = 'factory');

-- ============================================================
-- TABLE: purchase_orders
-- ============================================================

-- Sales: read own purchase orders (view only)
CREATE POLICY purchase_orders_sales_read ON purchase_orders
  FOR SELECT
  TO authenticated
  USING (
    get_my_role() = 'sales'
    AND pipeline_id IN (
      SELECT id FROM sales_pipelines WHERE created_by = auth.uid() AND deleted_at IS NULL
    )
    AND deleted_at IS NULL
  );

-- Admin: all purchase orders
CREATE POLICY purchase_orders_admin_all ON purchase_orders
  FOR ALL
  TO authenticated
  USING (get_my_role() = 'admin' AND deleted_at IS NULL)
  WITH CHECK (get_my_role() = 'admin');

-- Purchase: full access to purchase orders
CREATE POLICY purchase_orders_purchase_all ON purchase_orders
  FOR ALL
  TO authenticated
  USING (get_my_role() = 'purchase' AND deleted_at IS NULL)
  WITH CHECK (get_my_role() = 'purchase');

-- ============================================================
-- TABLE: step_audit_log
-- ============================================================

-- All authenticated users can insert audit log entries
CREATE POLICY audit_log_insert ON step_audit_log
  FOR INSERT
  TO authenticated
  WITH CHECK (performed_by = auth.uid());

-- Sales: read audit logs for own pipelines
CREATE POLICY audit_log_sales_read ON step_audit_log
  FOR SELECT
  TO authenticated
  USING (
    get_my_role() = 'sales'
    AND pipeline_id IN (
      SELECT id FROM sales_pipelines WHERE created_by = auth.uid() AND deleted_at IS NULL
    )
  );

-- Admin: read all audit logs
CREATE POLICY audit_log_admin_read ON step_audit_log
  FOR SELECT
  TO authenticated
  USING (get_my_role() = 'admin');

-- Factory: read audit logs for factory step pipelines
CREATE POLICY audit_log_factory_read ON step_audit_log
  FOR SELECT
  TO authenticated
  USING (
    get_my_role() = 'factory'
    AND pipeline_id IN (
      SELECT id FROM sales_pipelines
      WHERE current_step IN ('factory_order', 'purchase_order', 'completed') AND deleted_at IS NULL
    )
  );

-- ============================================================
-- TABLE: notifications
-- ============================================================

-- Each user reads/updates only their own notifications
CREATE POLICY notifications_own ON notifications
  FOR ALL
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Admin can read all notifications
CREATE POLICY notifications_admin_read ON notifications
  FOR SELECT
  TO authenticated
  USING (get_my_role() = 'admin');

-- System can insert notifications for any user (via Edge Functions with service role)

-- ============================================================
-- TABLE: pdf_templates
-- ============================================================

-- All authenticated users: read active templates
CREATE POLICY pdf_templates_read ON pdf_templates
  FOR SELECT
  TO authenticated
  USING (is_active = TRUE);

-- Admin only: write
CREATE POLICY pdf_templates_admin_write ON pdf_templates
  FOR ALL
  TO authenticated
  USING (get_my_role() = 'admin')
  WITH CHECK (get_my_role() = 'admin');

-- ============================================================
-- STORAGE BUCKETS (run in Supabase dashboard or CLI)
-- ============================================================
-- NOTE: Run these via Supabase Dashboard > Storage > New Bucket
-- or via the Supabase CLI after linking the project.
--
-- Buckets needed:
-- 1. 'pdfs'         - RLS: authenticated read if they own the pipeline
-- 2. 'logos'        - RLS: public read (company branding), admin write
-- 3. 'attachments'  - RLS: authenticated read/write for own records
