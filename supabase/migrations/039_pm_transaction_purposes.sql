-- 039_pm_transaction_purposes.sql
-- Manage Transaction Purpose / Tag list for Daily Transactions

CREATE TABLE IF NOT EXISTS pm_transaction_purposes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE pm_transaction_purposes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS pm_transaction_purposes_select ON pm_transaction_purposes;
CREATE POLICY pm_transaction_purposes_select ON pm_transaction_purposes
  FOR SELECT TO authenticated
  USING (is_active_user());

DROP POLICY IF EXISTS pm_transaction_purposes_insert ON pm_transaction_purposes;
CREATE POLICY pm_transaction_purposes_insert ON pm_transaction_purposes
  FOR INSERT TO authenticated
  WITH CHECK (is_active_user());

DROP POLICY IF EXISTS pm_transaction_purposes_update ON pm_transaction_purposes;
CREATE POLICY pm_transaction_purposes_update ON pm_transaction_purposes
  FOR UPDATE TO authenticated
  USING (is_active_user())
  WITH CHECK (is_active_user());

DROP POLICY IF EXISTS pm_transaction_purposes_delete ON pm_transaction_purposes;
CREATE POLICY pm_transaction_purposes_delete ON pm_transaction_purposes
  FOR DELETE TO authenticated
  USING (is_active_user());

-- Default common transaction purposes
INSERT INTO pm_transaction_purposes (name, sort_order)
VALUES
  ('Advance Payment', 1),
  ('Final Payment', 2),
  ('Material Purchase', 3),
  ('Transport / Freight', 4),
  ('Labour / Installation', 5),
  ('Site Expenses', 6),
  ('Office Expense', 7),
  ('Salary / Wages', 8),
  ('Vendor Payment', 9),
  ('Customer Receipt', 10),
  ('Refund', 11),
  ('Miscellaneous', 12)
ON CONFLICT (name) DO NOTHING;

-- Also seed any transaction names already recorded in pm_daily_transactions
INSERT INTO pm_transaction_purposes (name, sort_order)
SELECT DISTINCT trim(transaction_name), 99
FROM pm_daily_transactions
WHERE transaction_name IS NOT NULL AND trim(transaction_name) != ''
ON CONFLICT (name) DO NOTHING;

