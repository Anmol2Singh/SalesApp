-- supabase/migrations/043_deal_id_and_auto_generator.sql
-- Migration 043: Add human-readable deal_id column to sales_pipelines and auto-sequence generator

-- 1. Add deal_id column to sales_pipelines if not exists
ALTER TABLE sales_pipelines ADD COLUMN IF NOT EXISTS deal_id TEXT;

-- 2. Create sequence for deal IDs
CREATE SEQUENCE IF NOT EXISTS deal_seq START WITH 38;

-- 3. Function to automatically generate human-readable deal ID (e.g. DEAL-26-27-0038)
CREATE OR REPLACE FUNCTION generate_deal_id()
RETURNS TRIGGER AS $$
DECLARE
  fy_str TEXT;
  seq_num INT;
  d TIMESTAMPTZ := COALESCE(NEW.created_at, NOW());
  m INT := EXTRACT(MONTH FROM d);
  y INT := EXTRACT(YEAR FROM d);
  start_y INT;
  end_y INT;
BEGIN
  IF NEW.deal_id IS NULL OR NEW.deal_id = '' THEN
    IF m >= 4 THEN
      start_y := y % 100;
      end_y := (y + 1) % 100;
    ELSE
      start_y := (y - 1) % 100;
      end_y := y % 100;
    END IF;
    fy_str := LPAD(start_y::TEXT, 2, '0') || '-' || LPAD(end_y::TEXT, 2, '0');
    seq_num := NEXTVAL('deal_seq');
    NEW.deal_id := 'DEAL-' || fy_str || '-' || LPAD(seq_num::TEXT, 4, '0');
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4. Trigger on BEFORE INSERT
DROP TRIGGER IF EXISTS trg_generate_deal_id ON sales_pipelines;
CREATE TRIGGER trg_generate_deal_id
BEFORE INSERT ON sales_pipelines
FOR EACH ROW
EXECUTE FUNCTION generate_deal_id();

-- 5. Create unique index for fast lookups and searches
CREATE UNIQUE INDEX IF NOT EXISTS idx_sales_pipelines_deal_id ON sales_pipelines(deal_id);
