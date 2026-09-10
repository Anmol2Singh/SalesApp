-- ============================================================
-- IZYHEAT Sales App — Migration 005: Sales Head & Manufacturing Items
-- ============================================================

-- 1. Alter Enums (Adding new values)
ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'sales_head';
ALTER TYPE quotation_status ADD VALUE IF NOT EXISTS 'pending_approval';

-- 2. Create manufacturing_items Table
CREATE TABLE IF NOT EXISTS manufacturing_items (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name        TEXT NOT NULL UNIQUE,
  description TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. Add items column to factory_orders
ALTER TABLE factory_orders ADD COLUMN IF NOT EXISTS items JSONB NOT NULL DEFAULT '[]';

-- 4. Enable RLS on manufacturing_items
ALTER TABLE manufacturing_items ENABLE ROW LEVEL SECURITY;

-- 5. RLS Policies for manufacturing_items
DROP POLICY IF EXISTS "Allow all authenticated users to read manufacturing items" ON manufacturing_items;
CREATE POLICY "Allow all authenticated users to read manufacturing items"
  ON manufacturing_items FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Allow factory, sales_head, and admin to insert manufacturing items" ON manufacturing_items;
CREATE POLICY "Allow factory, sales_head, and admin to insert manufacturing items"
  ON manufacturing_items FOR INSERT TO authenticated 
  WITH CHECK (
    (SELECT role FROM profiles WHERE id = auth.uid()) IN ('factory', 'admin', 'sales_head')
  );

-- 6. Add RLS policies for sales_head on existing tables

-- Profiles: allow sales_head to read all profiles
DROP POLICY IF EXISTS profiles_sales_head_select ON profiles;
CREATE POLICY profiles_sales_head_select ON profiles
  FOR SELECT TO authenticated
  USING (get_my_role() = 'sales_head');

-- Customers: allow sales_head to see and modify all customers (similar to admin)
DROP POLICY IF EXISTS customers_sales_head_all ON customers;
CREATE POLICY customers_sales_head_all ON customers
  FOR ALL TO authenticated
  USING (get_my_role() = 'sales_head' AND deleted_at IS NULL)
  WITH CHECK (get_my_role() = 'sales_head');

-- Sales Pipelines: allow sales_head to see and modify all pipelines
DROP POLICY IF EXISTS pipelines_sales_head_all ON sales_pipelines;
CREATE POLICY pipelines_sales_head_all ON sales_pipelines
  FOR ALL TO authenticated
  USING (get_my_role() = 'sales_head' AND deleted_at IS NULL)
  WITH CHECK (get_my_role() = 'sales_head');

-- Quotations: allow sales_head to see and modify all quotations
DROP POLICY IF EXISTS quotations_sales_head_all ON quotations;
CREATE POLICY quotations_sales_head_all ON quotations
  FOR ALL TO authenticated
  USING (get_my_role() = 'sales_head' AND deleted_at IS NULL)
  WITH CHECK (get_my_role() = 'sales_head');

-- BOQs: allow sales_head to see and modify all BOQs
DROP POLICY IF EXISTS boqs_sales_head_all ON boqs;
CREATE POLICY boqs_sales_head_all ON boqs
  FOR ALL TO authenticated
  USING (get_my_role() = 'sales_head' AND deleted_at IS NULL)
  WITH CHECK (get_my_role() = 'sales_head');

-- Factory Orders: allow sales_head to see all factory orders
DROP POLICY IF EXISTS factory_orders_sales_head_select ON factory_orders;
CREATE POLICY factory_orders_sales_head_select ON factory_orders
  FOR SELECT TO authenticated
  USING (get_my_role() = 'sales_head' AND deleted_at IS NULL);

-- Purchase Orders: allow sales_head to see all purchase orders
DROP POLICY IF EXISTS purchase_orders_sales_head_select ON purchase_orders;
CREATE POLICY purchase_orders_sales_head_select ON purchase_orders
  FOR SELECT TO authenticated
  USING (get_my_role() = 'sales_head' AND deleted_at IS NULL);
