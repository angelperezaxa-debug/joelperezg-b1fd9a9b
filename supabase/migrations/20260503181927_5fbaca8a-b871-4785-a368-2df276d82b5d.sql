-- Realtime
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.rooms; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.room_players; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.room_actions; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.room_chat; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.room_text_chat; EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- sala_chat
create table if not exists public.sala_chat (
  id bigserial primary key,
  sala_slug text not null,
  device_id text not null,
  name text not null,
  text text not null check (char_length(text) between 1 and 200),
  created_at timestamptz not null default now()
);
create index if not exists sala_chat_sala_created_idx on public.sala_chat (sala_slug, created_at desc);
alter table public.sala_chat enable row level security;
drop policy if exists sala_chat_public_read on public.sala_chat;
create policy sala_chat_public_read on public.sala_chat for select using (true);
drop policy if exists sala_chat_no_client_insert on public.sala_chat;
create policy sala_chat_no_client_insert on public.sala_chat for insert to anon, authenticated with check (false);
drop policy if exists sala_chat_no_client_update on public.sala_chat;
create policy sala_chat_no_client_update on public.sala_chat for update to anon, authenticated using (false) with check (false);
drop policy if exists sala_chat_no_client_delete on public.sala_chat;
create policy sala_chat_no_client_delete on public.sala_chat for delete to anon, authenticated using (false);
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.sala_chat; EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- room_chat_flags
CREATE TABLE IF NOT EXISTS public.room_chat_flags (
  id BIGSERIAL PRIMARY KEY,
  room_id UUID NOT NULL,
  target_seat SMALLINT NOT NULL,
  target_device_id TEXT NOT NULL,
  reporter_device_id TEXT NOT NULL,
  reason TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'dismissed')),
  decided_at TIMESTAMP WITH TIME ZONE,
  decided_by TEXT,
  message_text TEXT,
  message_id BIGINT,
  UNIQUE (room_id, target_device_id, reporter_device_id)
);
CREATE INDEX IF NOT EXISTS idx_room_chat_flags_room_active ON public.room_chat_flags (room_id, expires_at);
CREATE INDEX IF NOT EXISTS idx_room_chat_flags_target_active ON public.room_chat_flags (room_id, target_device_id, expires_at);
CREATE INDEX IF NOT EXISTS idx_room_chat_flags_status_pending ON public.room_chat_flags (status, created_at DESC) WHERE status = 'pending';

CREATE TABLE IF NOT EXISTS public.chat_flag_audit (
  id BIGSERIAL PRIMARY KEY,
  flag_id BIGINT NOT NULL,
  room_id UUID NOT NULL,
  target_seat SMALLINT NOT NULL,
  target_device_id TEXT NOT NULL,
  reporter_device_id TEXT NOT NULL,
  message_id BIGINT,
  message_text TEXT,
  reason TEXT,
  decision TEXT NOT NULL CHECK (decision IN ('approved','dismissed','pending')),
  moderator_tag TEXT NOT NULL,
  flag_created_at TIMESTAMPTZ NOT NULL,
  flag_expires_at TIMESTAMPTZ NOT NULL,
  decided_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS chat_flag_audit_flag_id_idx ON public.chat_flag_audit (flag_id);
CREATE INDEX IF NOT EXISTS chat_flag_audit_room_id_idx ON public.chat_flag_audit (room_id);
CREATE INDEX IF NOT EXISTS chat_flag_audit_decided_at_idx ON public.chat_flag_audit (decided_at DESC);

ALTER TABLE public.room_chat_flags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_flag_audit ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "room_chat_flags_public_read" ON public.room_chat_flags;
CREATE POLICY "room_chat_flags_public_read" ON public.room_chat_flags FOR SELECT USING (true);
DROP POLICY IF EXISTS "room_chat_flags_no_client_insert" ON public.room_chat_flags;
CREATE POLICY "room_chat_flags_no_client_insert" ON public.room_chat_flags FOR INSERT TO anon, authenticated WITH CHECK (false);
DROP POLICY IF EXISTS "room_chat_flags_no_client_update" ON public.room_chat_flags;
CREATE POLICY "room_chat_flags_no_client_update" ON public.room_chat_flags FOR UPDATE TO anon, authenticated USING (false) WITH CHECK (false);
DROP POLICY IF EXISTS "room_chat_flags_no_client_delete" ON public.room_chat_flags;
CREATE POLICY "room_chat_flags_no_client_delete" ON public.room_chat_flags FOR DELETE TO anon, authenticated USING (false);

DROP POLICY IF EXISTS chat_flag_audit_no_client_select ON public.chat_flag_audit;
CREATE POLICY chat_flag_audit_no_client_select ON public.chat_flag_audit FOR SELECT TO anon, authenticated USING (false);
DROP POLICY IF EXISTS chat_flag_audit_no_client_insert ON public.chat_flag_audit;
CREATE POLICY chat_flag_audit_no_client_insert ON public.chat_flag_audit FOR INSERT TO anon, authenticated WITH CHECK (false);
DROP POLICY IF EXISTS chat_flag_audit_no_client_update ON public.chat_flag_audit;
CREATE POLICY chat_flag_audit_no_client_update ON public.chat_flag_audit FOR UPDATE TO anon, authenticated USING (false) WITH CHECK (false);
DROP POLICY IF EXISTS chat_flag_audit_no_client_delete ON public.chat_flag_audit;
CREATE POLICY chat_flag_audit_no_client_delete ON public.chat_flag_audit FOR DELETE TO anon, authenticated USING (false);

DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.room_chat_flags; EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- account_deletion_requests
CREATE TABLE IF NOT EXISTS public.account_deletion_requests (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  email text NOT NULL,
  reason text,
  status text NOT NULL DEFAULT 'pending',
  device_id text,
  ip_masked text,
  user_agent text,
  admin_notes text,
  processed_at timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT account_deletion_requests_status_chk
    CHECK (status IN ('pending', 'in_progress', 'completed', 'rejected')),
  CONSTRAINT account_deletion_requests_email_len_chk
    CHECK (char_length(email) BETWEEN 5 AND 254),
  CONSTRAINT account_deletion_requests_reason_len_chk
    CHECK (reason IS NULL OR char_length(reason) <= 1000)
);
ALTER TABLE public.account_deletion_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anyone_can_create_deletion_request" ON public.account_deletion_requests;
CREATE POLICY "anyone_can_create_deletion_request"
  ON public.account_deletion_requests
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (
    char_length(email) BETWEEN 5 AND 254
    AND email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'
    AND (reason IS NULL OR char_length(reason) <= 1000)
    AND status = 'pending'
    AND processed_at IS NULL
    AND admin_notes IS NULL
  );

DROP POLICY IF EXISTS "no_client_select_deletion_request" ON public.account_deletion_requests;
CREATE POLICY "no_client_select_deletion_request" ON public.account_deletion_requests FOR SELECT TO anon, authenticated USING (false);
DROP POLICY IF EXISTS "no_client_update_deletion_request" ON public.account_deletion_requests;
CREATE POLICY "no_client_update_deletion_request" ON public.account_deletion_requests FOR UPDATE TO anon, authenticated USING (false) WITH CHECK (false);
DROP POLICY IF EXISTS "no_client_delete_deletion_request" ON public.account_deletion_requests;
CREATE POLICY "no_client_delete_deletion_request" ON public.account_deletion_requests FOR DELETE TO anon, authenticated USING (false);

CREATE INDEX IF NOT EXISTS idx_account_deletion_requests_email ON public.account_deletion_requests (email);
CREATE INDEX IF NOT EXISTS idx_account_deletion_requests_status_created ON public.account_deletion_requests (status, created_at DESC);

CREATE OR REPLACE FUNCTION public.set_account_deletion_requests_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = public AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$;

DROP TRIGGER IF EXISTS trg_account_deletion_requests_updated_at ON public.account_deletion_requests;
CREATE TRIGGER trg_account_deletion_requests_updated_at
BEFORE UPDATE ON public.account_deletion_requests
FOR EACH ROW EXECUTE FUNCTION public.set_account_deletion_requests_updated_at();

-- admin_passwords
CREATE TABLE IF NOT EXISTS public.admin_passwords (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  password_hash TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.admin_passwords ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "admin_passwords_no_client" ON public.admin_passwords;
CREATE POLICY "admin_passwords_no_client" ON public.admin_passwords FOR ALL TO anon, authenticated USING (false) WITH CHECK (false);

-- account_links
CREATE TABLE IF NOT EXISTS public.account_links (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  device_id TEXT,
  email TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS account_links_device_idx ON public.account_links(device_id);
CREATE INDEX IF NOT EXISTS account_links_email_idx ON public.account_links(email);
ALTER TABLE public.account_links ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "account_links_self_select" ON public.account_links;
CREATE POLICY "account_links_self_select" ON public.account_links FOR SELECT TO authenticated USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "account_links_self_update" ON public.account_links;
CREATE POLICY "account_links_self_update" ON public.account_links FOR UPDATE TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "account_links_no_client_insert" ON public.account_links;
CREATE POLICY "account_links_no_client_insert" ON public.account_links FOR INSERT TO anon, authenticated WITH CHECK (false);
DROP POLICY IF EXISTS "account_links_no_client_delete" ON public.account_links;
CREATE POLICY "account_links_no_client_delete" ON public.account_links FOR DELETE TO anon, authenticated USING (false);

CREATE OR REPLACE FUNCTION public.set_account_links_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = public AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$;
DROP TRIGGER IF EXISTS trg_account_links_updated_at ON public.account_links;
CREATE TRIGGER trg_account_links_updated_at
BEFORE UPDATE ON public.account_links
FOR EACH ROW EXECUTE FUNCTION public.set_account_links_updated_at();

CREATE OR REPLACE FUNCTION public.handle_new_user_account_link()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.account_links (user_id, email, device_id)
  VALUES (NEW.id, NEW.email, NULLIF(NEW.raw_user_meta_data->>'device_id', ''))
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS on_auth_user_created_account_link ON auth.users;
CREATE TRIGGER on_auth_user_created_account_link
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user_account_link();

REVOKE EXECUTE ON FUNCTION public.set_account_links_updated_at() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.handle_new_user_account_link() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.set_account_deletion_requests_updated_at() FROM PUBLIC, anon, authenticated;