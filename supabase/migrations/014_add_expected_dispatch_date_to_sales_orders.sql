-- ============================================================
-- Migration 014: Add expected_dispatch_date to sales_orders
-- ============================================================

ALTER TABLE sales_orders ADD COLUMN IF NOT EXISTS expected_dispatch_date TIMESTAMPTZ;
