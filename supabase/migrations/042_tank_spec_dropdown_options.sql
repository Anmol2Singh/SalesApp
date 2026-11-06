-- ==============================================================================
-- Migration 042: Tank Specification Dropdown Options (Material, Insulation, Shell & Dish Thickness)
-- ==============================================================================

CREATE TABLE IF NOT EXISTS tank_spec_dropdown_options (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  category TEXT NOT NULL, -- 'tank_material', 'insulation_type', 'shell_thickness', 'dish_thickness'
  label TEXT NOT NULL,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT uq_tank_spec_category_label UNIQUE (category, label)
);

-- RLS
ALTER TABLE tank_spec_dropdown_options ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "tank_spec_dropdown_options_select" ON tank_spec_dropdown_options;
CREATE POLICY "tank_spec_dropdown_options_select" ON tank_spec_dropdown_options
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "tank_spec_dropdown_options_insert" ON tank_spec_dropdown_options;
CREATE POLICY "tank_spec_dropdown_options_insert" ON tank_spec_dropdown_options
  FOR INSERT TO authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "tank_spec_dropdown_options_update" ON tank_spec_dropdown_options;
CREATE POLICY "tank_spec_dropdown_options_update" ON tank_spec_dropdown_options
  FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "tank_spec_dropdown_options_delete" ON tank_spec_dropdown_options;
CREATE POLICY "tank_spec_dropdown_options_delete" ON tank_spec_dropdown_options
  FOR DELETE TO authenticated USING (true);

-- Seed initial values for all 4 dropdown categories
INSERT INTO tank_spec_dropdown_options (category, label, sort_order) VALUES
  ('tank_material', 'GI', 1),
  ('tank_material', 'MS', 2),
  ('tank_material', 'Enamel', 3),
  ('tank_material', 'SS', 4),

  ('insulation_type', 'Puff', 1),
  ('insulation_type', 'Rockwool', 2),
  ('insulation_type', 'Custom', 3),

  ('shell_thickness', '2mm', 1),
  ('shell_thickness', '3mm', 2),
  ('shell_thickness', '4mm', 3),
  ('shell_thickness', '5mm', 4),
  ('shell_thickness', '6mm', 5),

  ('dish_thickness', '2mm', 1),
  ('dish_thickness', '3mm', 2),
  ('dish_thickness', '4mm', 3),
  ('dish_thickness', '5mm', 4),
  ('dish_thickness', '6mm', 5)
ON CONFLICT (category, label) DO NOTHING;

