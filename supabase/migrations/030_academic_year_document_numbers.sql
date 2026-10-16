-- supabase/migrations/030_academic_year_document_numbers.sql
-- Migration 030: Switch all document numbering to academic / financial year format (e.g. 26-27)
-- Automatically rolls over at 1 April each year.

-- 1. Helper function to compute current financial year code (e.g. '26-27', '27-28')
CREATE OR REPLACE FUNCTION get_current_fy_code(d TIMESTAMPTZ DEFAULT NOW())
RETURNS TEXT AS $$
DECLARE
  m INT := EXTRACT(MONTH FROM d);
  y INT := EXTRACT(YEAR FROM d);
  start_y INT;
  end_y INT;
BEGIN
  IF m >= 4 THEN
    start_y := y % 100;
    end_y := (y + 1) % 100;
  ELSE
    start_y := (y - 1) % 100;
    end_y := y % 100;
  END IF;
  RETURN LPAD(start_y::TEXT, 2, '0') || '-' || LPAD(end_y::TEXT, 2, '0');
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- 2. Update Quotations sequence generator
CREATE OR REPLACE FUNCTION generate_quotation_number()
RETURNS TRIGGER AS $$
DECLARE
  fy_str TEXT := get_current_fy_code(NOW());
  seq_num  INT;
BEGIN
  seq_num := NEXTVAL('quotation_seq');
  NEW.quotation_number := 'IZY/QT/' || fy_str || '/' || LPAD(seq_num::TEXT, 4, '0');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. Update BOQs sequence generator
CREATE OR REPLACE FUNCTION generate_boq_number()
RETURNS TRIGGER AS $$
DECLARE
  fy_str TEXT := get_current_fy_code(NOW());
  seq_num  INT;
BEGIN
  seq_num := NEXTVAL('boq_seq');
  NEW.boq_number := 'IZY/BOQ/' || fy_str || '/' || LPAD(seq_num::TEXT, 4, '0');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4. Update Factory Orders sequence generator
CREATE OR REPLACE FUNCTION generate_factory_order_number()
RETURNS TRIGGER AS $$
DECLARE
  fy_str TEXT := get_current_fy_code(NOW());
  seq_num  INT;
BEGIN
  seq_num := NEXTVAL('factory_order_seq');
  NEW.order_number := 'IZY/FO/' || fy_str || '/' || LPAD(seq_num::TEXT, 4, '0');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 5. Update Purchase Orders sequence generator
CREATE OR REPLACE FUNCTION generate_po_number()
RETURNS TRIGGER AS $$
DECLARE
  fy_str TEXT := get_current_fy_code(NOW());
  seq_num  INT;
BEGIN
  seq_num := NEXTVAL('po_seq');
  NEW.po_number := 'IZY/PO/' || fy_str || '/' || LPAD(seq_num::TEXT, 4, '0');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 6. Update AMC Contracts sequence generator (if exists)
CREATE OR REPLACE FUNCTION generate_amc_number()
RETURNS TRIGGER AS $$
DECLARE
  fy_str TEXT := get_current_fy_code(NOW());
  seq_num INT;
BEGIN
  IF EXISTS (SELECT 1 FROM pg_sequences WHERE sequencename = 'amc_seq') THEN
    seq_num := NEXTVAL('amc_seq');
  ELSE
    seq_num := 1;
  END IF;
  NEW.amc_number := 'IZY/AMC/' || fy_str || '/' || LPAD(seq_num::TEXT, 4, '0');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 7. Migrate existing 2026 document numbers to 26-27
DO $$
BEGIN
  UPDATE quotations 
  SET quotation_number = REPLACE(quotation_number, '/2026/', '/26-27/')
  WHERE quotation_number LIKE '%/2026/%';

  UPDATE boqs 
  SET boq_number = REPLACE(boq_number, '/2026/', '/26-27/')
  WHERE boq_number LIKE '%/2026/%';

  UPDATE factory_orders 
  SET order_number = REPLACE(order_number, '/2026/', '/26-27/')
  WHERE order_number LIKE '%/2026/%';

  UPDATE purchase_orders 
  SET po_number = REPLACE(po_number, '/2026/', '/26-27/')
  WHERE po_number LIKE '%/2026/%';

  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'amc_contracts') THEN
    UPDATE amc_contracts 
    SET amc_number = REPLACE(amc_number, '/2026/', '/26-27/')
    WHERE amc_number LIKE '%/2026/%';
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'sales_orders') THEN
    UPDATE sales_orders 
    SET sales_order_number = REPLACE(sales_order_number, '/2026/', '/26-27/')
    WHERE sales_order_number LIKE '%/2026/%';
  END IF;
END $$;
