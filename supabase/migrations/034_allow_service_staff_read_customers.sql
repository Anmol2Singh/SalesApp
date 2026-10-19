-- Migration 034: Allow Complaint / Installation staff, Technicians, and Managers to SELECT all customers
-- This ensures that users with service_head, installation, technician, or manager roles
-- can view customers for booking complaints, scheduling installations, and service workflows,
-- while pure sales users remain restricted to their own assigned/created customers.

DROP POLICY IF EXISTS customers_service_staff_read ON customers;

CREATE POLICY customers_service_staff_read ON customers
  FOR SELECT
  TO authenticated
  USING (
    get_my_role() IN ('service_head', 'installation', 'technician', 'manager')
    OR EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
        AND (
          role::text IN ('service_head', 'installation', 'technician', 'manager')
          OR (roles IS NOT NULL AND roles && ARRAY['service_head', 'installation', 'technician', 'manager']::text[])
        )
    )
  );
