-- ============================================================================
-- Rollback Script for Migration 024_qg_schema.sql & 025_qg_catalog_seed.sql
-- Description: Completely removes all additive qg_ database objects and the
--              quotation-generator storage bucket if needed.
--              Does NOT touch ANY core table, function, trigger, or bucket.
-- ============================================================================

-- 1. Drop RPCs and helper functions
DROP FUNCTION IF EXISTS qg_finalize_proposal(UUID, JSONB, TEXT, TEXT);
DROP FUNCTION IF EXISTS qg_is_staff_user();
DROP FUNCTION IF EXISTS qg_is_admin_or_manager();

-- 2. Drop Storage Policies & Bucket
DROP POLICY IF EXISTS "Staff can read quotation-generator bucket" ON storage.objects;
DROP POLICY IF EXISTS "Staff can upload to proposals folder" ON storage.objects;
DELETE FROM storage.buckets WHERE id = 'quotation-generator';

-- 3. Drop Tables (all prefixed qg_)
DROP TABLE IF EXISTS qg_proposals CASCADE;
DROP TABLE IF EXISTS qg_catalog CASCADE;
DROP TABLE IF EXISTS qg_categories CASCADE;
DROP TABLE IF EXISTS qg_spec_templates CASCADE;
DROP TABLE IF EXISTS qg_text_blocks CASCADE;
DROP TABLE IF EXISTS qg_item_aliases CASCADE;
DROP TABLE IF EXISTS qg_settings CASCADE;
