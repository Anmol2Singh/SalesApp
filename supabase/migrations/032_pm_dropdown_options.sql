-- ==============================================================================
-- Migration 032: Project Manager Dropdown Options for Payment Types & Particulars
-- ==============================================================================

CREATE TABLE IF NOT EXISTS pm_dropdown_options (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  category TEXT NOT NULL, -- 'payment_type' or 'particulars'
  label TEXT NOT NULL,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT uq_pm_dropdown_category_label UNIQUE (category, label)
);

-- RLS
ALTER TABLE pm_dropdown_options ENABLE ROW LEVEL SECURITY;

CREATE POLICY "pm_dropdown_options_select" ON pm_dropdown_options
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "pm_dropdown_options_insert" ON pm_dropdown_options
  FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "pm_dropdown_options_update" ON pm_dropdown_options
  FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "pm_dropdown_options_delete" ON pm_dropdown_options
  FOR DELETE TO authenticated USING (true);

-- Seed Payment Types
INSERT INTO pm_dropdown_options (category, label, sort_order) VALUES
  ('payment_type', 'Cash', 1),
  ('payment_type', 'Cheque', 2),
  ('payment_type', 'Online', 3),
  ('payment_type', 'Advance', 4),
  ('payment_type', 'Final Settlement', 5),
  ('payment_type', 'RTGS / NEFT', 6),
  ('payment_type', 'UPI', 7)
ON CONFLICT (category, label) DO NOTHING;

-- Seed Particulars
INSERT INTO pm_dropdown_options (category, label, sort_order) VALUES
  ('particulars', 'Bill', 1),
  ('particulars', 'System work', 2),
  ('particulars', 'Advance', 3),
  ('particulars', 'Material Supply', 4),
  ('particulars', 'Installation Charges', 5),
  ('particulars', 'Transport / Freight', 6),
  ('particulars', 'Other', 7)
ON CONFLICT (category, label) DO NOTHING;
