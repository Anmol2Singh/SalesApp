-- Migration 045: Allow multiple BOQs per pipeline by dropping unique constraint on pipeline_id
-- and ensuring versioning (-v1, -v2, etc.) for BOQ numbers.

-- 1. Drop unique constraint on pipeline_id so multiple BOQ versions can exist per deal
ALTER TABLE public.boqs DROP CONSTRAINT IF EXISTS boqs_pipeline_id_key;

-- 2. Update generate_boq_number to append -v1 to base BOQ numbers by default
CREATE OR REPLACE FUNCTION generate_boq_number()
RETURNS TRIGGER AS $$
DECLARE
  fy_str TEXT := get_current_fy_code(NOW());
  seq_num  INT;
BEGIN
  seq_num := NEXTVAL('boq_seq');
  NEW.boq_number := 'IZY/BOQ/' || fy_str || '/' || LPAD(seq_num::TEXT, 4, '0') || '-v1';
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
