-- ============================================================================
-- Rollback Migration: 026_qg_noc_rollback.sql
-- Description: Clean, safe teardown of all objects created by 026_qg_noc.sql.
-- ============================================================================

-- 1. Drop storage policies
DROP POLICY IF EXISTS "qg_noc_storage_insert" ON storage.objects;
DROP POLICY IF EXISTS "qg_noc_storage_select" ON storage.objects;

-- 2. Drop RPC function
DROP FUNCTION IF EXISTS public.qg_finalize_noc(UUID, JSONB, TEXT, TEXT);

-- 3. Delete seeded text blocks
DELETE FROM public.qg_text_blocks WHERE key LIKE 'noc_%';

-- 4. Drop tables and indexes
DROP TABLE IF EXISTS public.qg_noc_profiles CASCADE;
DROP TABLE IF EXISTS public.qg_noc_counters CASCADE;
DROP TABLE IF EXISTS public.qg_noc_documents CASCADE;
