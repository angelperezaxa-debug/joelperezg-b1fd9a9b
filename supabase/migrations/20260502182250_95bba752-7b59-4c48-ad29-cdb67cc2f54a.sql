DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.rooms; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.room_players; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.room_actions; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.room_chat; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.room_text_chat; EXCEPTION WHEN duplicate_object THEN NULL; END $$;

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
  id           BIGSERIAL PRIMARY KEY,
  flag_id      BIGINT NOT NULL,
  room_id      UUID NOT NULL,
  target_seat  SMALLINT NOT NULL,
  target_device_id   TEXT NOT NULL,
  reporter_device_id TEXT NOT NULL,
  message_id   BIGINT,
  message_text TEXT,
  reason       TEXT,
  decision     TEXT NOT NULL CHECK (decision IN ('approved','dismissed','pending')),
  moderator_tag TEXT NOT NULL,
  flag_created_at TIMESTAMPTZ NOT NULL,
  flag_expires_at TIMESTAMPTZ NOT NULL,
  decided_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
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