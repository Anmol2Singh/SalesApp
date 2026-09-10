-- ============================================================
-- IZYHEAT Sales App — Migration 007: Customer Bookings, Invoices & Activity Log
-- ============================================================

-- Rename fcm_token to push_token in profiles
ALTER TABLE profiles RENAME COLUMN fcm_token TO push_token;

-- Alter default of theme_preference in profiles and customer_profiles to 'light'
ALTER TABLE profiles ALTER COLUMN theme_preference SET DEFAULT 'light';
ALTER TABLE customer_profiles ALTER COLUMN theme_preference SET DEFAULT 'light';

-- Update existing profiles to default theme_preference if needed
UPDATE profiles SET theme_preference = 'light' WHERE theme_preference = 'system' OR theme_preference IS NULL;
UPDATE customer_profiles SET theme_preference = 'light' WHERE theme_preference = 'system' OR theme_preference IS NULL;

-- Create bookings table
CREATE TABLE IF NOT EXISTS bookings (
  id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  customer_id             UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  device_id               UUID NOT NULL REFERENCES amc_contracts(id) ON DELETE CASCADE,
  issue_category          TEXT NOT NULL,
  notes                   TEXT,
  photo_urls              JSONB DEFAULT '[]'::jsonb,
  problem_code            TEXT NOT NULL UNIQUE,
  warranty_covered        BOOLEAN DEFAULT FALSE,
  scheduled_date          DATE NOT NULL,
  scheduled_slot          TEXT NOT NULL,
  location                JSONB NOT NULL, -- {"latitude": 28.59, "longitude": 77.04, "address": "Delhi"}
  assigned_technician_id  UUID REFERENCES profiles(id) ON DELETE SET NULL,
  status                  TEXT NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'in_progress', 'completed', 'cancelled')),
  created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_bookings_customer_id ON bookings(customer_id);
CREATE INDEX IF NOT EXISTS idx_bookings_assigned_technician_id ON bookings(assigned_technician_id);
CREATE INDEX IF NOT EXISTS idx_bookings_status ON bookings(status);

-- Auto-generate Booking Problem Code: IZY-<CAT>-YYYYMMDD-NNNN
DROP SEQUENCE IF EXISTS booking_seq CASCADE;
CREATE SEQUENCE booking_seq;

CREATE OR REPLACE FUNCTION generate_booking_problem_code()
RETURNS TRIGGER AS $$
DECLARE
  date_str TEXT := TO_CHAR(NOW(), 'YYYYMMDD');
  cat_str TEXT;
  seq_num INT;
BEGIN
  cat_str := COALESCE(NEW.issue_category, 'GEN');
  -- Clean category string: uppercase alphanumeric up to 4 chars
  cat_str := UPPER(REGEXP_REPLACE(cat_str, '[^a-zA-Z0-9]', ''));
  IF LENGTH(cat_str) > 4 THEN
    cat_str := SUBSTR(cat_str, 1, 4);
  ELSIF LENGTH(cat_str) = 0 THEN
    cat_str := 'GEN';
  END IF;
  
  seq_num := NEXTVAL('booking_seq');
  NEW.problem_code := 'IZY-' || cat_str || '-' || date_str || '-' || LPAD(seq_num::TEXT, 4, '0');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_booking_problem_code ON bookings;
CREATE TRIGGER set_booking_problem_code
  BEFORE INSERT ON bookings
  FOR EACH ROW
  WHEN (NEW.problem_code IS NULL OR NEW.problem_code = '')
  EXECUTE FUNCTION generate_booking_problem_code();

-- Create invoices table
CREATE TABLE IF NOT EXISTS invoices (
  id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  customer_id             UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  related_booking_id      UUID REFERENCES bookings(id) ON DELETE SET NULL,
  amc_id                  UUID REFERENCES amc_contracts(id) ON DELETE SET NULL,
  amount                  NUMERIC(15, 2) NOT NULL,
  status                  TEXT NOT NULL DEFAULT 'unpaid' CHECK (status IN ('paid', 'unpaid')),
  payment_gateway_ref     TEXT,
  pdf_url                 TEXT,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_invoices_customer_id ON invoices(customer_id);
CREATE INDEX IF NOT EXISTS idx_invoices_status ON invoices(status);

-- Create activity_log table
CREATE TABLE IF NOT EXISTS activity_log (
  id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  customer_id             UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  event_type              TEXT NOT NULL,
  title                   TEXT NOT NULL,
  body                    TEXT NOT NULL,
  related_booking_id      UUID REFERENCES bookings(id) ON DELETE CASCADE,
  related_invoice_id      UUID REFERENCES invoices(id) ON DELETE CASCADE,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_activity_log_customer_id ON activity_log(customer_id);

-- Enable RLS on bookings, invoices, activity_log
ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_log ENABLE ROW LEVEL SECURITY;

-- Policies for bookings
DROP POLICY IF EXISTS bookings_select_own ON bookings;
CREATE POLICY bookings_select_own ON bookings
  FOR SELECT TO authenticated USING (customer_id = auth.uid() OR get_my_role() IN ('admin', 'sales_head') OR assigned_technician_id = auth.uid());

DROP POLICY IF EXISTS bookings_insert_own ON bookings;
CREATE POLICY bookings_insert_own ON bookings
  FOR INSERT TO authenticated WITH CHECK (customer_id = auth.uid());

DROP POLICY IF EXISTS bookings_update_own ON bookings;
CREATE POLICY bookings_update_own ON bookings
  FOR UPDATE TO authenticated USING (customer_id = auth.uid() OR get_my_role() IN ('admin', 'sales_head') OR assigned_technician_id = auth.uid());

-- Policies for invoices
DROP POLICY IF EXISTS invoices_select_own ON invoices;
CREATE POLICY invoices_select_own ON invoices
  FOR SELECT TO authenticated USING (customer_id = auth.uid() OR get_my_role() IN ('admin', 'sales_head'));

DROP POLICY IF EXISTS invoices_insert_admin ON invoices;
CREATE POLICY invoices_insert_admin ON invoices
  FOR INSERT TO authenticated WITH CHECK (get_my_role() IN ('admin', 'sales_head'));

DROP POLICY IF EXISTS invoices_update_own ON invoices;
CREATE POLICY invoices_update_own ON invoices
  FOR UPDATE TO authenticated USING (customer_id = auth.uid() OR get_my_role() IN ('admin', 'sales_head'));

-- Policies for activity_log
DROP POLICY IF EXISTS activity_log_select_own ON activity_log;
CREATE POLICY activity_log_select_own ON activity_log
  FOR SELECT TO authenticated USING (customer_id = auth.uid() OR get_my_role() IN ('admin', 'sales_head'));

DROP POLICY IF EXISTS activity_log_insert_own ON activity_log;
CREATE POLICY activity_log_insert_own ON activity_log
  FOR INSERT TO authenticated WITH CHECK (customer_id = auth.uid() OR get_my_role() IN ('admin', 'sales_head'));

-- Redefine get_dashboard_stats function
DROP FUNCTION IF EXISTS get_dashboard_stats(text);
CREATE OR REPLACE FUNCTION get_dashboard_stats(time_filter TEXT DEFAULT 'month')
RETURNS JSON AS $$
DECLARE
  start_date TIMESTAMPTZ;
  active_deals_count INT;
  revenue_in_pipeline_val NUMERIC;
  amc_needs_attention_count INT;
  awaiting_fulfillment_count INT;
  trend_data JSONB;
BEGIN
  -- Determine start_date based on time_filter
  start_date := CASE time_filter
    WHEN 'today' THEN DATE_TRUNC('day', NOW())
    WHEN 'week'  THEN DATE_TRUNC('week', NOW())
    WHEN 'month' THEN DATE_TRUNC('month', NOW())
    WHEN 'year'  THEN DATE_TRUNC('year', NOW())
    ELSE DATE_TRUNC('month', NOW())
  END;

  -- 1. active_deals = in_progress + on_hold pipeline counts combined
  SELECT COUNT(*) INTO active_deals_count
  FROM sales_pipelines
  WHERE status IN ('in_progress', 'on_hold')
    AND deleted_at IS NULL;

  -- 2. revenue_in_pipeline = sum of quotations.grand_total for all non-completed pipelines
  SELECT COALESCE(SUM(q.grand_total), 0) INTO revenue_in_pipeline_val
  FROM sales_pipelines p
  JOIN quotations q ON q.pipeline_id = p.id
  WHERE p.status IN ('in_progress', 'on_hold')
    AND p.deleted_at IS NULL
    AND q.deleted_at IS NULL;

  -- 3. amc_needs_attention = expiring_soon contracts + missed visits combined
  SELECT 
    (SELECT COUNT(*) FROM amc_contracts WHERE status = 'expiring_soon') +
    (SELECT COUNT(*) FROM amc_service_visits WHERE status = 'missed')
  INTO amc_needs_attention_count;

  -- 4. awaiting_fulfillment = pipelines currently at factory_order or purchase_order step combined
  SELECT COUNT(*) INTO awaiting_fulfillment_count
  FROM sales_pipelines
  WHERE current_step IN ('factory_order', 'purchase_order')
    AND status IN ('in_progress', 'on_hold')
    AND deleted_at IS NULL;

  -- 5. trend data: list of last 7 days/weeks/months with created/completed counts
  IF time_filter = 'today' OR time_filter = 'week' THEN
    -- Last 7 days
    SELECT JSON_AGG(ROW_TO_JSON(t)) INTO trend_data
    FROM (
      SELECT 
        TO_CHAR(d, 'YYYY-MM-DD') AS date,
        (SELECT COUNT(*) FROM sales_pipelines WHERE DATE_TRUNC('day', created_at) = d AND deleted_at IS NULL) AS created,
        (SELECT COUNT(*) FROM sales_pipelines WHERE DATE_TRUNC('day', updated_at) = d AND status = 'completed' AND deleted_at IS NULL) AS completed
      FROM GENERATE_SERIES(CURRENT_DATE - INTERVAL '6 days', CURRENT_DATE, INTERVAL '1 day') d
    ) t;
  ELSIF time_filter = 'month' THEN
    -- Last 4 weeks
    SELECT JSON_AGG(ROW_TO_JSON(t)) INTO trend_data
    FROM (
      SELECT 
        'Week ' || row_number() OVER () AS date,
        (SELECT COUNT(*) FROM sales_pipelines WHERE created_at >= w.w_start AND created_at < w.w_start + INTERVAL '7 days' AND deleted_at IS NULL) AS created,
        (SELECT COUNT(*) FROM sales_pipelines WHERE updated_at >= w.w_start AND updated_at < w.w_start + INTERVAL '7 days' AND status = 'completed' AND deleted_at IS NULL) AS completed
      FROM (
        SELECT GENERATE_SERIES(DATE_TRUNC('week', CURRENT_DATE - INTERVAL '3 weeks'), DATE_TRUNC('week', CURRENT_DATE), INTERVAL '1 week') AS w_start
      ) w
    ) t;
  ELSE
    -- Last 12 months (of current year)
    SELECT JSON_AGG(ROW_TO_JSON(t)) INTO trend_data
    FROM (
      SELECT 
        TO_CHAR(m, 'Mon') AS date,
        (SELECT COUNT(*) FROM sales_pipelines WHERE DATE_TRUNC('month', created_at) = m AND deleted_at IS NULL) AS created,
        (SELECT COUNT(*) FROM sales_pipelines WHERE DATE_TRUNC('month', updated_at) = m AND status = 'completed' AND deleted_at IS NULL) AS completed
      FROM GENERATE_SERIES(DATE_TRUNC('year', CURRENT_DATE), DATE_TRUNC('month', CURRENT_DATE), INTERVAL '1 month') m
    ) t;
  END IF;

  RETURN JSON_BUILD_OBJECT(
    'active_deals', active_deals_count,
    'revenue_in_pipeline', revenue_in_pipeline_val,
    'amc_needs_attention', amc_needs_attention_count,
    'awaiting_fulfillment', awaiting_fulfillment_count,
    'trend', COALESCE(trend_data, '[]'::jsonb)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
