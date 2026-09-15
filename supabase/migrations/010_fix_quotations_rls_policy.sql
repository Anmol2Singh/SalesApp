-- ============================================================
-- MIGRATION 010: Fix quotations RLS policy for Sales & CRM Leads
-- ============================================================

DROP POLICY IF EXISTS quotations_sales_own ON quotations;

CREATE POLICY quotations_sales_own ON quotations
  FOR ALL
  TO authenticated
  USING (
    (
      (get_my_role())::text IN ('sales', 'manager')
      OR EXISTS (
        SELECT 1 FROM profiles 
        WHERE id = auth.uid() 
          AND (
            (role)::text IN ('sales', 'manager')
            OR (roles IS NOT NULL AND roles && ARRAY['sales', 'manager']::text[])
          )
      )
    )
    AND (
      -- Quotation linked to a CRM lead
      (lead_id IS NOT NULL)
      OR
      -- Quotation linked to a pipeline created by or assigned to this user
      (
        pipeline_id IN (
          SELECT sp.id FROM sales_pipelines sp
          LEFT JOIN customers c ON c.id = sp.customer_id
          WHERE (sp.created_by = auth.uid() OR c.assigned_to = auth.uid() OR c.created_by = auth.uid())
            AND sp.deleted_at IS NULL
        )
      )
      OR
      -- Standalone / unlinked draft quotations
      (pipeline_id IS NULL AND lead_id IS NULL)
    )
    AND deleted_at IS NULL
  )
  WITH CHECK (
    (
      (get_my_role())::text IN ('sales', 'manager')
      OR EXISTS (
        SELECT 1 FROM profiles 
        WHERE id = auth.uid() 
          AND (
            (role)::text IN ('sales', 'manager')
            OR (roles IS NOT NULL AND roles && ARRAY['sales', 'manager']::text[])
          )
      )
    )
    AND (
      -- Quotation linked to a CRM lead
      (lead_id IS NOT NULL)
      OR
      -- Quotation linked to a pipeline created by or assigned to this user
      (
        pipeline_id IN (
          SELECT sp.id FROM sales_pipelines sp
          LEFT JOIN customers c ON c.id = sp.customer_id
          WHERE (sp.created_by = auth.uid() OR c.assigned_to = auth.uid() OR c.created_by = auth.uid())
            AND sp.deleted_at IS NULL
        )
      )
      OR
      -- Standalone / unlinked draft quotations
      (pipeline_id IS NULL AND lead_id IS NULL)
    )
  );
