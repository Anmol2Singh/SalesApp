-- Migration: 038_add_quotation_rejection_reason.sql
-- Description: Add rejection_reason column to quotations table so rejection feedback is preserved and visible.

ALTER TABLE public.quotations 
  ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

COMMENT ON COLUMN public.quotations.rejection_reason IS 'Reason specified by approver when rejecting a quotation.';

