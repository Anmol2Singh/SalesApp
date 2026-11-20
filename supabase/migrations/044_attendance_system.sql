-- supabase/migrations/044_attendance_system.sql
-- Migration 044: Complete Employee Attendance Management System

-- ============================================================================
-- 1. ENUMS & TYPES
-- ============================================================================

DO $$ BEGIN
  CREATE TYPE attendance_status AS ENUM ('present', 'late', 'half_day', 'absent', 'on_leave', 'holiday', 'weekly_off');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE attendance_event_type AS ENUM ('check_in', 'check_out', 'break_start', 'break_end');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE correction_status AS ENUM ('pending', 'approved', 'rejected');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE attendance_role AS ENUM ('admin', 'manager', 'employee');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- ============================================================================
-- 2. TABLES
-- ============================================================================

-- A. Departments
CREATE TABLE IF NOT EXISTS departments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  code TEXT NOT NULL UNIQUE,
  description TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- B. Office Locations & Geofence
CREATE TABLE IF NOT EXISTS office_locations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  address TEXT NOT NULL,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  geofence_radius_meters INTEGER NOT NULL DEFAULT 150,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- C. Shifts
CREATE TABLE IF NOT EXISTS employee_shifts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  start_time TIME NOT NULL DEFAULT '09:00:00',
  end_time TIME NOT NULL DEFAULT '18:00:00',
  break_duration_minutes INTEGER NOT NULL DEFAULT 60,
  grace_period_minutes INTEGER NOT NULL DEFAULT 15,
  required_hours NUMERIC(4,2) NOT NULL DEFAULT 8.00,
  allow_overtime BOOLEAN NOT NULL DEFAULT true,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- D. Employee Profiles (Links 1:1 to auth.users / profiles)
CREATE TABLE IF NOT EXISTS employee_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  employee_code TEXT UNIQUE,
  designation TEXT,
  department_id UUID REFERENCES departments(id) ON DELETE SET NULL,
  reporting_manager_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  attendance_role attendance_role NOT NULL DEFAULT 'employee',
  office_location_id UUID REFERENCES office_locations(id) ON DELETE SET NULL,
  shift_id UUID REFERENCES employee_shifts(id) ON DELETE SET NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,
  joining_date DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- E. Manager Assignments (Manager to Employee oversight)
CREATE TABLE IF NOT EXISTS manager_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  manager_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  employee_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  department_id UUID REFERENCES departments(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(manager_id, employee_id)
);

-- F. Attendance Records (Daily consolidated log per employee)
CREATE TABLE IF NOT EXISTS attendance_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  attendance_date DATE NOT NULL,
  shift_id UUID REFERENCES employee_shifts(id) ON DELETE SET NULL,
  office_location_id UUID REFERENCES office_locations(id) ON DELETE SET NULL,
  check_in_time TIMESTAMPTZ,
  check_out_time TIMESTAMPTZ,
  check_in_lat DOUBLE PRECISION,
  check_in_lng DOUBLE PRECISION,
  check_out_lat DOUBLE PRECISION,
  check_out_lng DOUBLE PRECISION,
  check_in_accuracy DOUBLE PRECISION,
  check_out_accuracy DOUBLE PRECISION,
  check_in_distance_meters DOUBLE PRECISION,
  check_out_distance_meters DOUBLE PRECISION,
  total_working_minutes INTEGER NOT NULL DEFAULT 0,
  overtime_minutes INTEGER NOT NULL DEFAULT 0,
  status attendance_status NOT NULL DEFAULT 'present',
  is_late BOOLEAN NOT NULL DEFAULT false,
  is_early_departure BOOLEAN NOT NULL DEFAULT false,
  check_in_address TEXT,
  check_out_address TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(employee_id, attendance_date)
);

-- G. Attendance Events (Immutable audit log of all events)
CREATE TABLE IF NOT EXISTS attendance_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  attendance_record_id UUID REFERENCES attendance_records(id) ON DELETE CASCADE,
  employee_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  event_type attendance_event_type NOT NULL,
  event_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  accuracy DOUBLE PRECISION,
  distance_meters DOUBLE PRECISION,
  office_location_id UUID REFERENCES office_locations(id) ON DELETE SET NULL,
  device_info TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- H. Attendance Settings
CREATE TABLE IF NOT EXISTS attendance_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  grace_period_minutes INTEGER NOT NULL DEFAULT 15,
  half_day_threshold_hours NUMERIC(4,2) NOT NULL DEFAULT 4.5,
  full_day_threshold_hours NUMERIC(4,2) NOT NULL DEFAULT 8.0,
  max_gps_accuracy_meters INTEGER NOT NULL DEFAULT 150,
  require_geofence_for_checkout BOOLEAN NOT NULL DEFAULT false,
  allow_correction_requests BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- I. Attendance Correction Requests
CREATE TABLE IF NOT EXISTS attendance_correction_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  attendance_record_id UUID REFERENCES attendance_records(id) ON DELETE SET NULL,
  employee_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  requested_date DATE NOT NULL,
  requested_check_in TIMESTAMPTZ,
  requested_check_out TIMESTAMPTZ,
  reason TEXT NOT NULL,
  status correction_status NOT NULL DEFAULT 'pending',
  reviewed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  reviewed_at TIMESTAMPTZ,
  reviewer_comment TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- J. Attendance Audit Logs
CREATE TABLE IF NOT EXISTS attendance_audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  action TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id UUID,
  details JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- K. Company Holidays
CREATE TABLE IF NOT EXISTS holidays (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  date DATE NOT NULL,
  description TEXT,
  is_optional BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- 3. INDEXES
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_attendance_records_emp_date ON attendance_records(employee_id, attendance_date);
CREATE INDEX IF NOT EXISTS idx_attendance_records_status ON attendance_records(status);
CREATE INDEX IF NOT EXISTS idx_attendance_records_date ON attendance_records(attendance_date);
CREATE INDEX IF NOT EXISTS idx_attendance_events_rec_id ON attendance_events(attendance_record_id);
CREATE INDEX IF NOT EXISTS idx_attendance_events_emp_time ON attendance_events(employee_id, event_time);
CREATE INDEX IF NOT EXISTS idx_manager_assignments_mgr ON manager_assignments(manager_id);
CREATE INDEX IF NOT EXISTS idx_manager_assignments_emp ON manager_assignments(employee_id);
CREATE INDEX IF NOT EXISTS idx_employee_profiles_dept ON employee_profiles(department_id);
CREATE INDEX IF NOT EXISTS idx_correction_requests_emp ON attendance_correction_requests(employee_id);
CREATE INDEX IF NOT EXISTS idx_correction_requests_status ON attendance_correction_requests(status);

-- ============================================================================
-- 4. GEOLOCATION & AUTHORIZATION FUNCTIONS
-- ============================================================================

-- Haversine formula to compute distance between two GPS coordinates in meters
CREATE OR REPLACE FUNCTION calculate_haversine_distance(
  lat1 DOUBLE PRECISION,
  lon1 DOUBLE PRECISION,
  lat2 DOUBLE PRECISION,
  lon2 DOUBLE PRECISION
)
RETURNS DOUBLE PRECISION AS $$
DECLARE
  r CONSTANT DOUBLE PRECISION := 6371000.0; -- Earth radius in meters
  dlat DOUBLE PRECISION := RADIANS(lat2 - lat1);
  dlon DOUBLE PRECISION := RADIANS(lon2 - lon1);
  a DOUBLE PRECISION;
  c DOUBLE PRECISION;
BEGIN
  IF lat1 IS NULL OR lon1 IS NULL OR lat2 IS NULL OR lon2 IS NULL THEN
    RETURN 999999.0;
  END IF;
  a := SIN(dlat / 2.0) * SIN(dlat / 2.0) +
       COS(RADIANS(lat1)) * COS(RADIANS(lat2)) *
       SIN(dlon / 2.0) * SIN(dlon / 2.0);
  c := 2.0 * ATAN2(SQRT(a), SQRT(1.0 - a));
  RETURN r * c;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Helper to determine active attendance role for a user
CREATE OR REPLACE FUNCTION get_user_attendance_role(p_user_id UUID)
RETURNS TEXT AS $$
DECLARE
  v_role TEXT;
  v_p_role TEXT;
  v_p_roles TEXT[];
BEGIN
  IF p_user_id IS NULL THEN
    RETURN 'employee';
  END IF;

  -- 1. Check profiles table for global admin or manager
  SELECT role::TEXT, roles INTO v_p_role, v_p_roles FROM profiles WHERE id = p_user_id;
  IF v_p_role = 'admin' OR 'admin' = ANY(v_p_roles) THEN
    RETURN 'admin';
  END IF;

  -- 2. Check employee_profiles for attendance-specific role
  SELECT attendance_role::TEXT INTO v_role FROM employee_profiles WHERE id = p_user_id;
  IF v_role IS NOT NULL THEN
    RETURN v_role;
  END IF;

  -- 3. If manager or service_head in profiles, treat as manager
  IF v_p_role IN ('manager', 'service_head') OR 'manager' = ANY(v_p_roles) OR 'service_head' = ANY(v_p_roles) THEN
    RETURN 'manager';
  END IF;

  RETURN 'employee';
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Check if user is a manager of an employee
CREATE OR REPLACE FUNCTION is_manager_of(p_manager_id UUID, p_employee_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  IF p_manager_id IS NULL OR p_employee_id IS NULL THEN
    RETURN false;
  END IF;
  RETURN EXISTS (
    SELECT 1 FROM manager_assignments 
    WHERE manager_id = p_manager_id AND employee_id = p_employee_id
  ) OR EXISTS (
    SELECT 1 FROM employee_profiles
    WHERE id = p_employee_id AND reporting_manager_id = p_manager_id
  );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Validate geofence against target office
CREATE OR REPLACE FUNCTION validate_attendance_geofence(
  p_office_id UUID,
  p_lat DOUBLE PRECISION,
  p_lng DOUBLE PRECISION,
  p_accuracy DOUBLE PRECISION DEFAULT NULL
)
RETURNS TABLE (
  is_valid BOOLEAN,
  distance_meters DOUBLE PRECISION,
  radius_meters INTEGER,
  office_name TEXT,
  error_message TEXT
) AS $$
DECLARE
  v_office RECORD;
  v_dist DOUBLE PRECISION;
  v_max_acc INTEGER := 150;
BEGIN
  SELECT * INTO v_office FROM office_locations WHERE id = p_office_id AND is_active = true;
  IF NOT FOUND THEN
    RETURN QUERY SELECT false, 999999.0::DOUBLE PRECISION, 0, ''::TEXT, 'Office location is inactive or invalid'::TEXT;
    RETURN;
  END IF;

  -- Check GPS accuracy
  SELECT max_gps_accuracy_meters INTO v_max_acc FROM attendance_settings LIMIT 1;
  IF p_accuracy IS NOT NULL AND p_accuracy > v_max_acc THEN
    RETURN QUERY SELECT false, 999999.0::DOUBLE PRECISION, v_office.geofence_radius_meters, v_office.name,
      ('GPS signal accuracy is too weak (' || ROUND(p_accuracy::NUMERIC, 1) || 'm). Please move to open space.')::TEXT;
    RETURN;
  END IF;

  -- Calculate distance
  v_dist := calculate_haversine_distance(p_lat, p_lng, v_office.latitude, v_office.longitude);

  IF v_dist <= v_office.geofence_radius_meters THEN
    RETURN QUERY SELECT true, v_dist, v_office.geofence_radius_meters, v_office.name, NULL::TEXT;
  ELSE
    RETURN QUERY SELECT false, v_dist, v_office.geofence_radius_meters, v_office.name,
      ('You are ' || ROUND((v_dist - v_office.geofence_radius_meters)::NUMERIC, 0) || 'm outside ' || v_office.name || ' geofence.')::TEXT;
  END IF;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- ============================================================================
-- 5. SECURE TRANSACTIONAL PROCEDURES (Callable from Flutter RPC)
-- ============================================================================

-- Check In Procedure
CREATE OR REPLACE FUNCTION submit_attendance_check_in(
  p_office_id UUID,
  p_lat DOUBLE PRECISION,
  p_lng DOUBLE PRECISION,
  p_accuracy DOUBLE PRECISION DEFAULT 10.0,
  p_address TEXT DEFAULT '',
  p_device_info TEXT DEFAULT ''
)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_today DATE := CURRENT_DATE;
  v_now TIMESTAMPTZ := NOW();
  v_geo RECORD;
  v_emp RECORD;
  v_shift RECORD;
  v_rec RECORD;
  v_rec_id UUID;
  v_is_late BOOLEAN := false;
  v_status attendance_status := 'present';
  v_grace_mins INTEGER := 15;
  v_shift_start TIME := '09:00:00';
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Unauthorized: User not authenticated');
  END IF;

  -- 1. Check if employee already checked in today
  SELECT * INTO v_rec FROM attendance_records WHERE employee_id = v_user_id AND attendance_date = v_today;
  IF FOUND AND v_rec.check_in_time IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Already checked in for today at ' || to_char(v_rec.check_in_time, 'HH12:MI AM'));
  END IF;

  -- 2. Fetch employee profile & shift
  SELECT * INTO v_emp FROM employee_profiles WHERE id = v_user_id;
  IF FOUND AND v_emp.shift_id IS NOT NULL THEN
    SELECT * INTO v_shift FROM employee_shifts WHERE id = v_emp.shift_id;
    IF FOUND THEN
      v_grace_mins := v_shift.grace_period_minutes;
      v_shift_start := v_shift.start_time;
    END IF;
  END IF;

  -- 3. Validate Geofence
  SELECT * INTO v_geo FROM validate_attendance_geofence(p_office_id, p_lat, p_lng, p_accuracy);
  IF NOT v_geo.is_valid THEN
    RETURN jsonb_build_object('success', false, 'message', v_geo.error_message, 'distance', v_geo.distance_meters);
  END IF;

  -- 4. Check Late Arrival
  IF (v_now::TIME) > (v_shift_start + (v_grace_mins || ' minutes')::INTERVAL) THEN
    v_is_late := true;
    v_status := 'late';
  END IF;

  -- 5. Upsert attendance record
  INSERT INTO attendance_records (
    employee_id,
    attendance_date,
    shift_id,
    office_location_id,
    check_in_time,
    check_in_lat,
    check_in_lng,
    check_in_accuracy,
    check_in_distance_meters,
    check_in_address,
    is_late,
    status
  ) VALUES (
    v_user_id,
    v_today,
    v_emp.shift_id,
    p_office_id,
    v_now,
    p_lat,
    p_lng,
    p_accuracy,
    v_geo.distance_meters,
    p_address,
    v_is_late,
    v_status
  )
  ON CONFLICT (employee_id, attendance_date) DO UPDATE SET
    check_in_time = EXCLUDED.check_in_time,
    check_in_lat = EXCLUDED.check_in_lat,
    check_in_lng = EXCLUDED.check_in_lng,
    check_in_accuracy = EXCLUDED.check_in_accuracy,
    check_in_distance_meters = EXCLUDED.check_in_distance_meters,
    check_in_address = EXCLUDED.check_in_address,
    is_late = EXCLUDED.is_late,
    status = EXCLUDED.status,
    office_location_id = EXCLUDED.office_location_id,
    updated_at = NOW()
  RETURNING id INTO v_rec_id;

  -- 6. Insert audit event
  INSERT INTO attendance_events (
    attendance_record_id,
    employee_id,
    event_type,
    event_time,
    latitude,
    longitude,
    accuracy,
    distance_meters,
    office_location_id,
    device_info
  ) VALUES (
    v_rec_id,
    v_user_id,
    'check_in',
    v_now,
    p_lat,
    p_lng,
    p_accuracy,
    v_geo.distance_meters,
    p_office_id,
    p_device_info
  );

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Check-in successful' || CASE WHEN v_is_late THEN ' (Marked as Late)' ELSE '' END,
    'record_id', v_rec_id,
    'check_in_time', v_now,
    'status', v_status,
    'distance_meters', v_geo.distance_meters
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Check Out Procedure
CREATE OR REPLACE FUNCTION submit_attendance_check_out(
  p_lat DOUBLE PRECISION,
  p_lng DOUBLE PRECISION,
  p_accuracy DOUBLE PRECISION DEFAULT 10.0,
  p_address TEXT DEFAULT '',
  p_device_info TEXT DEFAULT ''
)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_today DATE := CURRENT_DATE;
  v_now TIMESTAMPTZ := NOW();
  v_rec RECORD;
  v_emp RECORD;
  v_shift RECORD;
  v_dist DOUBLE PRECISION := 0.0;
  v_total_mins INTEGER := 0;
  v_overtime_mins INTEGER := 0;
  v_req_hours NUMERIC(4,2) := 8.0;
  v_status attendance_status;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Unauthorized: User not authenticated');
  END IF;

  -- 1. Fetch active check-in for today
  SELECT * INTO v_rec FROM attendance_records WHERE employee_id = v_user_id AND attendance_date = v_today;
  IF NOT FOUND OR v_rec.check_in_time IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'No active check-in found for today. Please check in first.');
  END IF;

  IF v_rec.check_out_time IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Already checked out today at ' || to_char(v_rec.check_out_time, 'HH12:MI AM'));
  END IF;

  -- 2. Calculate duration
  v_total_mins := EXTRACT(EPOCH FROM (v_now - v_rec.check_in_time)) / 60;
  IF v_total_mins < 0 THEN v_total_mins := 0; END IF;

  -- 3. Calculate overtime & status based on shift
  v_status := v_rec.status;
  SELECT * INTO v_emp FROM employee_profiles WHERE id = v_user_id;
  IF FOUND AND v_emp.shift_id IS NOT NULL THEN
    SELECT * INTO v_shift FROM employee_shifts WHERE id = v_emp.shift_id;
    IF FOUND THEN
      v_req_hours := v_shift.required_hours;
    END IF;
  END IF;

  IF v_total_mins > (v_req_hours * 60) AND (v_shift.allow_overtime IS NOT FALSE) THEN
    v_overtime_mins := v_total_mins - (v_req_hours * 60);
  END IF;

  -- If working duration < 4 hours, mark half day unless already on leave
  IF v_total_mins < 240 AND v_status != 'on_leave' THEN
    v_status := 'half_day';
  END IF;

  -- 4. Calculate distance from office if office is assigned
  IF v_rec.office_location_id IS NOT NULL THEN
    SELECT calculate_haversine_distance(p_lat, p_lng, latitude, longitude) INTO v_dist
    FROM office_locations WHERE id = v_rec.office_location_id;
  END IF;

  -- 5. Update record
  UPDATE attendance_records SET
    check_out_time = v_now,
    check_out_lat = p_lat,
    check_out_lng = p_lng,
    check_out_accuracy = p_accuracy,
    check_out_distance_meters = v_dist,
    check_out_address = p_address,
    total_working_minutes = v_total_mins,
    overtime_minutes = v_overtime_mins,
    status = v_status,
    updated_at = NOW()
  WHERE id = v_rec.id;

  -- 6. Insert checkout event
  INSERT INTO attendance_events (
    attendance_record_id,
    employee_id,
    event_type,
    event_time,
    latitude,
    longitude,
    accuracy,
    distance_meters,
    office_location_id,
    device_info
  ) VALUES (
    v_rec.id,
    v_user_id,
    'check_out',
    v_now,
    p_lat,
    p_lng,
    p_accuracy,
    v_dist,
    v_rec.office_location_id,
    p_device_info
  );

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Check-out successful. Total hours: ' || (v_total_mins / 60)::TEXT || 'h ' || (v_total_mins % 60)::TEXT || 'm',
    'record_id', v_rec.id,
    'check_out_time', v_now,
    'total_working_minutes', v_total_mins,
    'overtime_minutes', v_overtime_mins
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 6. ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================

ALTER TABLE departments ENABLE ROW LEVEL SECURITY;
ALTER TABLE office_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE employee_shifts ENABLE ROW LEVEL SECURITY;
ALTER TABLE employee_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE manager_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance_correction_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance_audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE holidays ENABLE ROW LEVEL SECURITY;

-- 1. Departments Policies
DROP POLICY IF EXISTS "Departments read for authenticated" ON departments;
CREATE POLICY "Departments read for authenticated" ON departments
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Departments manage for admin" ON departments;
CREATE POLICY "Departments manage for admin" ON departments
  FOR ALL TO authenticated
  USING (get_user_attendance_role(auth.uid()) = 'admin');

-- 2. Office Locations Policies
DROP POLICY IF EXISTS "Office locations read for authenticated" ON office_locations;
CREATE POLICY "Office locations read for authenticated" ON office_locations
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Office locations manage for admin" ON office_locations;
CREATE POLICY "Office locations manage for admin" ON office_locations
  FOR ALL TO authenticated
  USING (get_user_attendance_role(auth.uid()) = 'admin');

-- 3. Shifts Policies
DROP POLICY IF EXISTS "Shifts read for authenticated" ON employee_shifts;
CREATE POLICY "Shifts read for authenticated" ON employee_shifts
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Shifts manage for admin" ON employee_shifts;
CREATE POLICY "Shifts manage for admin" ON employee_shifts
  FOR ALL TO authenticated
  USING (get_user_attendance_role(auth.uid()) = 'admin');

-- 4. Employee Profiles Policies
DROP POLICY IF EXISTS "Employee profiles read" ON employee_profiles;
CREATE POLICY "Employee profiles read" ON employee_profiles
  FOR SELECT TO authenticated
  USING (
    id = auth.uid() OR
    get_user_attendance_role(auth.uid()) = 'admin' OR
    is_manager_of(auth.uid(), id)
  );

DROP POLICY IF EXISTS "Employee profiles manage for admin" ON employee_profiles;
CREATE POLICY "Employee profiles manage for admin" ON employee_profiles
  FOR ALL TO authenticated
  USING (get_user_attendance_role(auth.uid()) = 'admin');

-- 5. Manager Assignments Policies
DROP POLICY IF EXISTS "Manager assignments read" ON manager_assignments;
CREATE POLICY "Manager assignments read" ON manager_assignments
  FOR SELECT TO authenticated
  USING (
    manager_id = auth.uid() OR
    employee_id = auth.uid() OR
    get_user_attendance_role(auth.uid()) = 'admin'
  );

DROP POLICY IF EXISTS "Manager assignments manage for admin" ON manager_assignments;
CREATE POLICY "Manager assignments manage for admin" ON manager_assignments
  FOR ALL TO authenticated
  USING (get_user_attendance_role(auth.uid()) = 'admin');

-- 6. Attendance Records Policies
DROP POLICY IF EXISTS "Attendance records read" ON attendance_records;
CREATE POLICY "Attendance records read" ON attendance_records
  FOR SELECT TO authenticated
  USING (
    employee_id = auth.uid() OR
    get_user_attendance_role(auth.uid()) = 'admin' OR
    is_manager_of(auth.uid(), employee_id)
  );

DROP POLICY IF EXISTS "Attendance records insert/update for self or admin" ON attendance_records;
CREATE POLICY "Attendance records insert/update for self or admin" ON attendance_records
  FOR ALL TO authenticated
  USING (
    employee_id = auth.uid() OR
    get_user_attendance_role(auth.uid()) = 'admin'
  );

-- 7. Attendance Events Policies
DROP POLICY IF EXISTS "Attendance events read" ON attendance_events;
CREATE POLICY "Attendance events read" ON attendance_events
  FOR SELECT TO authenticated
  USING (
    employee_id = auth.uid() OR
    get_user_attendance_role(auth.uid()) = 'admin' OR
    is_manager_of(auth.uid(), employee_id)
  );

DROP POLICY IF EXISTS "Attendance events insert for self" ON attendance_events;
CREATE POLICY "Attendance events insert for self" ON attendance_events
  FOR INSERT TO authenticated
  WITH CHECK (employee_id = auth.uid() OR get_user_attendance_role(auth.uid()) = 'admin');

-- 8. Attendance Settings Policies
DROP POLICY IF EXISTS "Attendance settings read for authenticated" ON attendance_settings;
CREATE POLICY "Attendance settings read for authenticated" ON attendance_settings
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Attendance settings manage for admin" ON attendance_settings;
CREATE POLICY "Attendance settings manage for admin" ON attendance_settings
  FOR ALL TO authenticated
  USING (get_user_attendance_role(auth.uid()) = 'admin');

-- 9. Correction Requests Policies
DROP POLICY IF EXISTS "Correction requests read" ON attendance_correction_requests;
CREATE POLICY "Correction requests read" ON attendance_correction_requests
  FOR SELECT TO authenticated
  USING (
    employee_id = auth.uid() OR
    get_user_attendance_role(auth.uid()) = 'admin' OR
    is_manager_of(auth.uid(), employee_id)
  );

DROP POLICY IF EXISTS "Correction requests create for self" ON attendance_correction_requests;
CREATE POLICY "Correction requests create for self" ON attendance_correction_requests
  FOR INSERT TO authenticated
  WITH CHECK (employee_id = auth.uid());

DROP POLICY IF EXISTS "Correction requests update for manager or admin" ON attendance_correction_requests;
CREATE POLICY "Correction requests update for manager or admin" ON attendance_correction_requests
  FOR UPDATE TO authenticated
  USING (
    get_user_attendance_role(auth.uid()) = 'admin' OR
    is_manager_of(auth.uid(), employee_id)
  );

-- 10. Audit Logs Policies
DROP POLICY IF EXISTS "Audit logs read for admin" ON attendance_audit_logs;
CREATE POLICY "Audit logs read for admin" ON attendance_audit_logs
  FOR SELECT TO authenticated
  USING (get_user_attendance_role(auth.uid()) = 'admin');

DROP POLICY IF EXISTS "Audit logs insert for authenticated" ON attendance_audit_logs;
CREATE POLICY "Audit logs insert for authenticated" ON attendance_audit_logs
  FOR INSERT TO authenticated
  WITH CHECK (actor_id = auth.uid());

-- 11. Holidays Policies
DROP POLICY IF EXISTS "Holidays read for authenticated" ON holidays;
CREATE POLICY "Holidays read for authenticated" ON holidays
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Holidays manage for admin" ON holidays;
CREATE POLICY "Holidays manage for admin" ON holidays
  FOR ALL TO authenticated
  USING (get_user_attendance_role(auth.uid()) = 'admin');

-- ============================================================================
-- 7. INITIAL SEED DATA & AUTO-ENROLLMENT
-- ============================================================================

-- 1. Default Departments
INSERT INTO departments (name, code, description) VALUES
  ('Administration & Executive', 'ADMIN', 'Core administrative and company executive leadership'),
  ('Sales & Marketing', 'SALES', 'Business development, client relations and sales force'),
  ('Field Service & Installation', 'SERVICE', 'Technical field operations, site installations and equipment servicing'),
  ('Factory & Production', 'FACTORY', 'Solar water heater manufacturing, heat pump assembly and testing'),
  ('Procurement & Inventory', 'PURCHASE', 'Material requisition, vendor procurement and warehouse supply chain')
ON CONFLICT (code) DO NOTHING;

-- 2. Default Office Location (Pune Head Office)
INSERT INTO office_locations (name, address, latitude, longitude, geofence_radius_meters, is_active)
SELECT 'Insiya Solar Industry - HQ', 'Kuwaiti Mosque Rd, Dhaka 1212 / Pune Office', 18.5204, 73.8567, 250, true
WHERE NOT EXISTS (SELECT 1 FROM office_locations LIMIT 1);

-- 3. Default General Day Shift
INSERT INTO employee_shifts (name, start_time, end_time, break_duration_minutes, grace_period_minutes, required_hours, allow_overtime)
SELECT 'General Day Shift (9 AM - 6 PM)', '09:00:00', '18:00:00', 60, 15, 8.00, true
WHERE NOT EXISTS (SELECT 1 FROM employee_shifts LIMIT 1);

-- 4. Default Attendance Settings
INSERT INTO attendance_settings (grace_period_minutes, half_day_threshold_hours, full_day_threshold_hours, max_gps_accuracy_meters, require_geofence_for_checkout)
SELECT 15, 4.5, 8.0, 150, false
WHERE NOT EXISTS (SELECT 1 FROM attendance_settings LIMIT 1);

-- 5. Auto-Enroll Existing Profiles into employee_profiles
DO $$
DECLARE
  v_default_office UUID;
  v_default_shift UUID;
  v_admin_dept UUID;
  v_sales_dept UUID;
  v_service_dept UUID;
  v_factory_dept UUID;
  v_purchase_dept UUID;
  p RECORD;
  v_code TEXT;
  v_seq INT := 1001;
  v_att_role attendance_role;
  v_target_dept UUID;
  v_desig TEXT;
BEGIN
  SELECT id INTO v_default_office FROM office_locations LIMIT 1;
  SELECT id INTO v_default_shift FROM employee_shifts LIMIT 1;
  SELECT id INTO v_admin_dept FROM departments WHERE code = 'ADMIN' LIMIT 1;
  SELECT id INTO v_sales_dept FROM departments WHERE code = 'SALES' LIMIT 1;
  SELECT id INTO v_service_dept FROM departments WHERE code = 'SERVICE' LIMIT 1;
  SELECT id INTO v_factory_dept FROM departments WHERE code = 'FACTORY' LIMIT 1;
  SELECT id INTO v_purchase_dept FROM departments WHERE code = 'PURCHASE' LIMIT 1;

  FOR p IN SELECT id, full_name, email, role::TEXT as main_role, roles FROM profiles ORDER BY created_at ASC LOOP
    v_code := 'EMP-' || v_seq;
    v_seq := v_seq + 1;

    -- Determine attendance role and department
    IF p.main_role = 'admin' OR 'admin' = ANY(p.roles) THEN
      v_att_role := 'admin';
      v_target_dept := v_admin_dept;
      v_desig := 'Director / Administrator';
    ELSIF p.main_role IN ('manager', 'service_head') OR 'manager' = ANY(p.roles) OR 'service_head' = ANY(p.roles) THEN
      v_att_role := 'manager';
      v_target_dept := CASE WHEN p.main_role = 'service_head' THEN v_service_dept ELSE v_admin_dept END;
      v_desig := CASE WHEN p.main_role = 'service_head' THEN 'Service Head' ELSE 'Operations Manager' END;
    ELSIF p.main_role = 'technician' OR 'technician' = ANY(p.roles) THEN
      v_att_role := 'employee';
      v_target_dept := v_service_dept;
      v_desig := 'Field Service Technician';
    ELSIF p.main_role IN ('sales', 'sales_head') OR 'sales' = ANY(p.roles) OR 'sales_head' = ANY(p.roles) THEN
      v_att_role := CASE WHEN p.main_role = 'sales_head' THEN 'manager'::attendance_role ELSE 'employee'::attendance_role END;
      v_target_dept := v_sales_dept;
      v_desig := CASE WHEN p.main_role = 'sales_head' THEN 'Sales Head' ELSE 'Sales Executive' END;
    ELSIF p.main_role = 'factory' OR 'factory' = ANY(p.roles) THEN
      v_att_role := 'employee';
      v_target_dept := v_factory_dept;
      v_desig := 'Production Specialist';
    ELSIF p.main_role = 'purchase' OR 'purchase' = ANY(p.roles) THEN
      v_att_role := 'employee';
      v_target_dept := v_purchase_dept;
      v_desig := 'Procurement Officer';
    ELSE
      v_att_role := 'employee';
      v_target_dept := v_admin_dept;
      v_desig := 'Executive Staff';
    END IF;

    INSERT INTO employee_profiles (
      id,
      employee_code,
      designation,
      department_id,
      attendance_role,
      office_location_id,
      shift_id,
      is_active
    ) VALUES (
      p.id,
      v_code,
      v_desig,
      v_target_dept,
      v_att_role,
      v_default_office,
      v_default_shift,
      true
    )
    ON CONFLICT (id) DO UPDATE SET
      designation = COALESCE(employee_profiles.designation, EXCLUDED.designation),
      department_id = COALESCE(employee_profiles.department_id, EXCLUDED.department_id),
      attendance_role = EXCLUDED.attendance_role,
      office_location_id = COALESCE(employee_profiles.office_location_id, EXCLUDED.office_location_id),
      shift_id = COALESCE(employee_profiles.shift_id, EXCLUDED.shift_id);
  END LOOP;
END $$;
