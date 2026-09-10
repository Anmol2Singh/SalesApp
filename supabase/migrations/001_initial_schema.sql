-- ============================================================
-- IZYHEAT Sales App — Migration 001: Initial Schema
-- ============================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- ============================================================
-- ENUMS
-- ============================================================

CREATE TYPE user_role AS ENUM ('admin', 'sales', 'factory', 'purchase');

CREATE TYPE pipeline_step AS ENUM (
  'quotation',
  'boq',
  'factory_order',
  'purchase_order',
  'completed'
);

CREATE TYPE pipeline_status AS ENUM (
  'in_progress',
  'completed',
  'on_hold',
  'cancelled'
);

CREATE TYPE quotation_status AS ENUM ('draft', 'confirmed');
CREATE TYPE boq_status AS ENUM ('draft', 'submitted');
CREATE TYPE factory_order_status AS ENUM ('pending', 'in_production', 'completed');
CREATE TYPE purchase_order_status AS ENUM ('pending', 'ordered', 'received');

CREATE TYPE audit_action AS ENUM (
  'created',
  'updated',
  'confirmed',
  'pdf_generated',
  'status_changed'
);

CREATE TYPE notification_type AS ENUM (
  'step_unlocked',
  'assigned',
  'reminder',
  'admin_alert'
);

CREATE TYPE document_type AS ENUM (
  'quotation',
  'boq',
  'factory_order',
  'purchase_order'
);

-- ============================================================
-- AUTO-UPDATE TRIGGER FUNCTION
-- ============================================================

CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- TABLE: profiles (extends auth.users)
-- ============================================================

CREATE TABLE profiles (
  id           UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name    TEXT NOT NULL,
  email        TEXT NOT NULL UNIQUE,
  phone        TEXT,
  role         user_role NOT NULL DEFAULT 'sales',
  is_active    BOOLEAN NOT NULL DEFAULT TRUE,
  fcm_token    TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at   TIMESTAMPTZ
);

CREATE TRIGGER profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Auto-create profile row when auth user is created
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (id, full_name, email, role)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', 'New User'),
    NEW.email,
    COALESCE((NEW.raw_user_meta_data->>'role')::user_role, 'sales')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ============================================================
-- TABLE: products
-- ============================================================

CREATE TABLE products (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name          TEXT NOT NULL,
  category      TEXT,
  base_specs    JSONB NOT NULL DEFAULT '{}',
  is_active     BOOLEAN NOT NULL DEFAULT TRUE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at    TIMESTAMPTZ
);

CREATE TRIGGER products_updated_at
  BEFORE UPDATE ON products
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- TABLE: customers
-- ============================================================

CREATE TABLE customers (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  company_name    TEXT NOT NULL,
  contact_person  TEXT,
  phone           TEXT,
  email           TEXT,
  address         TEXT,
  gst_number      TEXT,
  created_by      UUID NOT NULL REFERENCES profiles(id),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at      TIMESTAMPTZ
);

CREATE INDEX idx_customers_created_by ON customers(created_by);
CREATE INDEX idx_customers_company_name_trgm ON customers USING GIN (company_name gin_trgm_ops);
CREATE INDEX idx_customers_phone ON customers(phone);
CREATE INDEX idx_customers_email ON customers(email);

CREATE TRIGGER customers_updated_at
  BEFORE UPDATE ON customers
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- TABLE: sales_pipelines
-- ============================================================

CREATE TABLE sales_pipelines (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  customer_id   UUID NOT NULL REFERENCES customers(id),
  product_id    UUID NOT NULL REFERENCES products(id),
  created_by    UUID NOT NULL REFERENCES profiles(id),
  current_step  pipeline_step NOT NULL DEFAULT 'quotation',
  status        pipeline_status NOT NULL DEFAULT 'in_progress',
  notes         TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at    TIMESTAMPTZ
);

CREATE INDEX idx_pipelines_created_by ON sales_pipelines(created_by);
CREATE INDEX idx_pipelines_customer_id ON sales_pipelines(customer_id);
CREATE INDEX idx_pipelines_current_step ON sales_pipelines(current_step);
CREATE INDEX idx_pipelines_status ON sales_pipelines(status);

CREATE TRIGGER pipelines_updated_at
  BEFORE UPDATE ON sales_pipelines
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- TABLE: quotations
-- ============================================================

CREATE TABLE quotations (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  pipeline_id       UUID NOT NULL UNIQUE REFERENCES sales_pipelines(id),
  quotation_number  TEXT NOT NULL UNIQUE,
  product_id        UUID NOT NULL REFERENCES products(id),
  line_items        JSONB NOT NULL DEFAULT '[]',
  product_specs     JSONB NOT NULL DEFAULT '{}',
  subtotal          NUMERIC(15,2) NOT NULL DEFAULT 0,
  cgst_rate         NUMERIC(5,2) NOT NULL DEFAULT 9,
  sgst_rate         NUMERIC(5,2) NOT NULL DEFAULT 9,
  cgst_amount       NUMERIC(15,2) NOT NULL DEFAULT 0,
  sgst_amount       NUMERIC(15,2) NOT NULL DEFAULT 0,
  grand_total       NUMERIC(15,2) NOT NULL DEFAULT 0,
  terms_text        TEXT,
  pdf_url           TEXT,
  confirmed_by      UUID REFERENCES profiles(id),
  confirmed_at      TIMESTAMPTZ,
  status            quotation_status NOT NULL DEFAULT 'draft',
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at        TIMESTAMPTZ
);

CREATE INDEX idx_quotations_pipeline_id ON quotations(pipeline_id);
CREATE INDEX idx_quotations_status ON quotations(status);

CREATE TRIGGER quotations_updated_at
  BEFORE UPDATE ON quotations
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Auto-generate quotation number: IZY/QT/YYYY/NNNN
CREATE SEQUENCE quotation_seq;

CREATE OR REPLACE FUNCTION generate_quotation_number()
RETURNS TRIGGER AS $$
DECLARE
  year_str TEXT := TO_CHAR(NOW(), 'YYYY');
  seq_num  INT;
BEGIN
  seq_num := NEXTVAL('quotation_seq');
  NEW.quotation_number := 'IZY/QT/' || year_str || '/' || LPAD(seq_num::TEXT, 4, '0');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_quotation_number
  BEFORE INSERT ON quotations
  FOR EACH ROW
  WHEN (NEW.quotation_number IS NULL OR NEW.quotation_number = '')
  EXECUTE FUNCTION generate_quotation_number();

-- ============================================================
-- TABLE: boqs
-- ============================================================

CREATE TABLE boqs (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  pipeline_id UUID NOT NULL UNIQUE REFERENCES sales_pipelines(id),
  boq_number  TEXT NOT NULL UNIQUE,
  items       JSONB NOT NULL DEFAULT '[]',
  extra_fields JSONB NOT NULL DEFAULT '{}',
  pdf_url     TEXT,
  status      boq_status NOT NULL DEFAULT 'draft',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at  TIMESTAMPTZ
);

CREATE INDEX idx_boqs_pipeline_id ON boqs(pipeline_id);

CREATE TRIGGER boqs_updated_at
  BEFORE UPDATE ON boqs
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE SEQUENCE boq_seq;

CREATE OR REPLACE FUNCTION generate_boq_number()
RETURNS TRIGGER AS $$
DECLARE
  year_str TEXT := TO_CHAR(NOW(), 'YYYY');
  seq_num  INT;
BEGIN
  seq_num := NEXTVAL('boq_seq');
  NEW.boq_number := 'IZY/BOQ/' || year_str || '/' || LPAD(seq_num::TEXT, 4, '0');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_boq_number
  BEFORE INSERT ON boqs
  FOR EACH ROW
  WHEN (NEW.boq_number IS NULL OR NEW.boq_number = '')
  EXECUTE FUNCTION generate_boq_number();

-- ============================================================
-- TABLE: factory_orders
-- ============================================================

CREATE TABLE factory_orders (
  id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  pipeline_id             UUID NOT NULL UNIQUE REFERENCES sales_pipelines(id),
  order_number            TEXT NOT NULL UNIQUE,
  production_specs        JSONB NOT NULL DEFAULT '{}',
  expected_completion_date DATE,
  assigned_factory_staff  UUID REFERENCES profiles(id),
  pdf_url                 TEXT,
  status                  factory_order_status NOT NULL DEFAULT 'pending',
  factory_notes           TEXT,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at              TIMESTAMPTZ
);

CREATE INDEX idx_factory_orders_pipeline_id ON factory_orders(pipeline_id);
CREATE INDEX idx_factory_orders_status ON factory_orders(status);
CREATE INDEX idx_factory_orders_assigned ON factory_orders(assigned_factory_staff);

CREATE TRIGGER factory_orders_updated_at
  BEFORE UPDATE ON factory_orders
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE SEQUENCE factory_order_seq;

CREATE OR REPLACE FUNCTION generate_factory_order_number()
RETURNS TRIGGER AS $$
DECLARE
  year_str TEXT := TO_CHAR(NOW(), 'YYYY');
  seq_num  INT;
BEGIN
  seq_num := NEXTVAL('factory_order_seq');
  NEW.order_number := 'IZY/FO/' || year_str || '/' || LPAD(seq_num::TEXT, 4, '0');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_factory_order_number
  BEFORE INSERT ON factory_orders
  FOR EACH ROW
  WHEN (NEW.order_number IS NULL OR NEW.order_number = '')
  EXECUTE FUNCTION generate_factory_order_number();

-- ============================================================
-- TABLE: purchase_orders
-- ============================================================

CREATE TABLE purchase_orders (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  pipeline_id     UUID NOT NULL UNIQUE REFERENCES sales_pipelines(id),
  po_number       TEXT NOT NULL UNIQUE,
  vendor_details  JSONB NOT NULL DEFAULT '{}',
  items           JSONB NOT NULL DEFAULT '[]',
  total_amount    NUMERIC(15,2) NOT NULL DEFAULT 0,
  pdf_url         TEXT,
  status          purchase_order_status NOT NULL DEFAULT 'pending',
  purchase_notes  TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at      TIMESTAMPTZ
);

CREATE INDEX idx_purchase_orders_pipeline_id ON purchase_orders(pipeline_id);
CREATE INDEX idx_purchase_orders_status ON purchase_orders(status);

CREATE TRIGGER purchase_orders_updated_at
  BEFORE UPDATE ON purchase_orders
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE SEQUENCE po_seq;

CREATE OR REPLACE FUNCTION generate_po_number()
RETURNS TRIGGER AS $$
DECLARE
  year_str TEXT := TO_CHAR(NOW(), 'YYYY');
  seq_num  INT;
BEGIN
  seq_num := NEXTVAL('po_seq');
  NEW.po_number := 'IZY/PO/' || year_str || '/' || LPAD(seq_num::TEXT, 4, '0');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_po_number
  BEFORE INSERT ON purchase_orders
  FOR EACH ROW
  WHEN (NEW.po_number IS NULL OR NEW.po_number = '')
  EXECUTE FUNCTION generate_po_number();

-- ============================================================
-- TABLE: step_audit_log
-- ============================================================

CREATE TABLE step_audit_log (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  pipeline_id  UUID NOT NULL REFERENCES sales_pipelines(id),
  step_name    TEXT NOT NULL,
  action       audit_action NOT NULL,
  performed_by UUID NOT NULL REFERENCES profiles(id),
  performed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  notes        TEXT
);

CREATE INDEX idx_audit_log_pipeline_id ON step_audit_log(pipeline_id);
CREATE INDEX idx_audit_log_performed_at ON step_audit_log(performed_at DESC);
CREATE INDEX idx_audit_log_performed_by ON step_audit_log(performed_by);

-- ============================================================
-- TABLE: notifications
-- ============================================================

CREATE TABLE notifications (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id             UUID NOT NULL REFERENCES profiles(id),
  title               TEXT NOT NULL,
  body                TEXT NOT NULL,
  type                notification_type NOT NULL,
  related_pipeline_id UUID REFERENCES sales_pipelines(id),
  is_read             BOOLEAN NOT NULL DEFAULT FALSE,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_is_read ON notifications(user_id, is_read);

-- ============================================================
-- TABLE: pdf_templates
-- ============================================================

CREATE TABLE pdf_templates (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  document_type   document_type NOT NULL UNIQUE,
  template_config JSONB NOT NULL DEFAULT '{}',
  is_active       BOOLEAN NOT NULL DEFAULT TRUE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER pdf_templates_updated_at
  BEFORE UPDATE ON pdf_templates
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- ANALYTICS VIEWS
-- ============================================================

-- Pipeline funnel (count per step)
CREATE VIEW pipeline_funnel AS
SELECT
  current_step,
  COUNT(*) AS count
FROM sales_pipelines
WHERE status != 'cancelled' AND deleted_at IS NULL
GROUP BY current_step;

-- Salesperson leaderboard
CREATE VIEW sales_leaderboard AS
SELECT
  p.id AS salesperson_id,
  p.full_name,
  COUNT(DISTINCT sp.id) FILTER (WHERE sp.current_step = 'completed' OR sp.status = 'completed') AS completed_pipelines,
  COUNT(DISTINCT q.id) FILTER (WHERE q.status = 'confirmed') AS confirmed_quotations,
  COUNT(DISTINCT sp.id) AS total_pipelines
FROM profiles p
LEFT JOIN sales_pipelines sp ON sp.created_by = p.id AND sp.deleted_at IS NULL
LEFT JOIN quotations q ON q.pipeline_id = sp.id AND q.deleted_at IS NULL
WHERE p.role = 'sales' AND p.deleted_at IS NULL
GROUP BY p.id, p.full_name;

-- ============================================================
-- RPC: Fuzzy customer search
-- ============================================================

CREATE OR REPLACE FUNCTION search_customers(search_term TEXT, requesting_user_id UUID)
RETURNS TABLE (
  id UUID,
  company_name TEXT,
  contact_person TEXT,
  phone TEXT,
  email TEXT,
  similarity_score REAL
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    c.id,
    c.company_name,
    c.contact_person,
    c.phone,
    c.email,
    GREATEST(
      similarity(c.company_name, search_term),
      CASE WHEN c.phone = search_term THEN 1.0 ELSE 0.0 END,
      CASE WHEN c.email = search_term THEN 1.0 ELSE 0.0 END
    ) AS similarity_score
  FROM customers c
  WHERE
    c.deleted_at IS NULL
    AND (
      c.company_name ILIKE '%' || search_term || '%'
      OR similarity(c.company_name, search_term) > 0.2
      OR c.phone = search_term
      OR c.email ILIKE search_term
    )
  ORDER BY similarity_score DESC
  LIMIT 20;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- RPC: Dashboard stats (admin)
-- ============================================================

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
    )
  ) INTO result;

  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
