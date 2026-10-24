-- supabase/migrations/004_fcm_tokens.sql
-- Table to store Firebase Cloud Messaging (FCM) device push tokens

CREATE TABLE IF NOT EXISTS public.fcm_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  token TEXT NOT NULL UNIQUE,
  platform TEXT NOT NULL DEFAULT 'android',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for fast lookups
CREATE INDEX IF NOT EXISTS idx_fcm_tokens_user_id ON public.fcm_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_fcm_tokens_token ON public.fcm_tokens(token);

-- Enable Row Level Security
ALTER TABLE public.fcm_tokens ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if re-run
DROP POLICY IF EXISTS "Users can select own fcm tokens" ON public.fcm_tokens;
DROP POLICY IF EXISTS "Users can insert own fcm tokens" ON public.fcm_tokens;
DROP POLICY IF EXISTS "Users can update own fcm tokens" ON public.fcm_tokens;
DROP POLICY IF EXISTS "Users can delete own fcm tokens" ON public.fcm_tokens;
DROP POLICY IF EXISTS "Service role can manage all fcm tokens" ON public.fcm_tokens;

-- RLS Policies:
-- 1. Users can view their own tokens
CREATE POLICY "Users can select own fcm tokens"
  ON public.fcm_tokens
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- 2. Users can insert their own tokens
CREATE POLICY "Users can insert own fcm tokens"
  ON public.fcm_tokens
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- 3. Users can update their own tokens
CREATE POLICY "Users can update own fcm tokens"
  ON public.fcm_tokens
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- 4. Users can delete their own tokens
CREATE POLICY "Users can delete own fcm tokens"
  ON public.fcm_tokens
  FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- 5. Service role has full access
CREATE POLICY "Service role can manage all fcm tokens"
  ON public.fcm_tokens
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- Optional: Automated Postgres pg_net trigger function for sending push notifications
-- Note: You can either enable this trigger or configure a Database Webhook in the Supabase Dashboard
-- (Dashboard -> Database -> Webhooks -> Add Webhook on notifications INSERT -> Edge Function send_fcm)

CREATE OR REPLACE FUNCTION public.handle_new_notification_push()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  project_url TEXT;
  anon_key TEXT;
  payload JSONB;
BEGIN
  -- Construct payload matching Database Webhook structure
  payload := jsonb_build_object(
    'type', 'INSERT',
    'table', 'notifications',
    'schema', 'public',
    'record', to_jsonb(NEW)
  );

  -- If pg_net extension is available, dispatch async HTTP POST to send_fcm
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net') THEN
    BEGIN
      PERFORM net.http_post(
        url := current_setting('app.settings.supabase_url', true) || '/functions/v1/send_fcm',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true)
        ),
        body := payload
      );
    EXCEPTION WHEN OTHERS THEN
      -- Silently catch so notification insertion in client never fails if edge function is unreachable
      RAISE WARNING 'send_fcm pg_net dispatch failed: %', SQLERRM;
    END;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_push_on_insert ON public.notifications;
CREATE TRIGGER trg_notify_push_on_insert
  AFTER INSERT ON public.notifications
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_notification_push();

