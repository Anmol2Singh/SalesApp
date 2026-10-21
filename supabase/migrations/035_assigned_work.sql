-- ==============================================================================
-- IZYHEAT Sales App — Migration 035: Assigned Work Module
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.assigned_work (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT DEFAULT '',
  task_date DATE NOT NULL DEFAULT CURRENT_DATE,
  due_time TEXT,
  assigned_to_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  assigned_to_user_name TEXT NOT NULL DEFAULT 'Unassigned',
  assigned_to_user_role TEXT,
  assigned_by_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  assigned_by_user_name TEXT NOT NULL DEFAULT 'System',
  assigned_by_user_role TEXT,
  customer_id UUID REFERENCES public.customers(id) ON DELETE SET NULL,
  customer_name TEXT,
  priority TEXT NOT NULL DEFAULT 'medium', -- 'low', 'medium', 'high', 'urgent'
  status TEXT NOT NULL DEFAULT 'pending', -- 'pending', 'in_progress', 'completed', 'cancelled'
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indices for fast calendar range queries & user lookups
CREATE INDEX IF NOT EXISTS idx_assigned_work_task_date ON public.assigned_work(task_date);
CREATE INDEX IF NOT EXISTS idx_assigned_work_assigned_to ON public.assigned_work(assigned_to_user_id);
CREATE INDEX IF NOT EXISTS idx_assigned_work_assigned_by ON public.assigned_work(assigned_by_user_id);
CREATE INDEX IF NOT EXISTS idx_assigned_work_status ON public.assigned_work(status);

-- Enable RLS and permissive policy for authenticated users
ALTER TABLE public.assigned_work ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "assigned_work_all_access" ON public.assigned_work;
CREATE POLICY "assigned_work_all_access" ON public.assigned_work
  FOR ALL
  USING (true)
  WITH CHECK (true);
