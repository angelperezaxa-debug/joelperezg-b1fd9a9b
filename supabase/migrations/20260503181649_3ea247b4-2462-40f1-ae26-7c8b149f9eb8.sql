-- Batch 0: initial tables, types, RLS for rooms/players/actions/chat/profiles
DO $$ BEGIN
  CREATE TYPE public.room_status AS ENUM ('lobby', 'playing', 'finished', 'abandoned');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE public.seat_kind AS ENUM ('human', 'bot', 'empty');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE TABLE IF NOT EXISTS public.rooms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT NOT NULL UNIQUE,
  status public.room_status NOT NULL DEFAULT 'lobby',
  target_cames INTEGER NOT NULL DEFAULT 2 CHECK (target_cames BETWEEN 1 AND 5),
  initial_mano SMALLINT NOT NULL DEFAULT 0 CHECK (initial_mano BETWEEN 0 AND 3),
  seat_kinds public.seat_kind[] NOT NULL,
  host_device TEXT NOT NULL,
  match_state JSONB,
  bot_intents JSONB NOT NULL DEFAULT '{}'::jsonb,
  turn_started_at timestamptz,
  paused_at timestamptz,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS target_cama integer NOT NULL DEFAULT 12;
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS turn_timeout_sec integer NOT NULL DEFAULT 30;
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS pending_proposal jsonb;
ALTER TABLE public.rooms DROP CONSTRAINT IF EXISTS rooms_target_cama_chk;
ALTER TABLE public.rooms ADD CONSTRAINT rooms_target_cama_chk CHECK (target_cama IN (9, 12));
ALTER TABLE public.rooms DROP CONSTRAINT IF EXISTS rooms_turn_timeout_sec_chk;
ALTER TABLE public.rooms ADD CONSTRAINT rooms_turn_timeout_sec_chk CHECK (turn_timeout_sec IN (15, 30, 45, 60));

CREATE INDEX IF NOT EXISTS rooms_code_idx ON public.rooms (code);
CREATE INDEX IF NOT EXISTS rooms_status_idx ON public.rooms (status);

CREATE TABLE IF NOT EXISTS public.room_players (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
  seat SMALLINT NOT NULL CHECK (seat BETWEEN 0 AND 3),
  device_id TEXT NOT NULL,
  name TEXT NOT NULL CHECK (char_length(name) BETWEEN 1 AND 24),
  is_online BOOLEAN NOT NULL DEFAULT TRUE,
  last_seen TIMESTAMPTZ NOT NULL DEFAULT now(),
  joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (room_id, seat)
);
CREATE INDEX IF NOT EXISTS room_players_room_idx ON public.room_players (room_id);
CREATE INDEX IF NOT EXISTS room_players_device_idx ON public.room_players (device_id);

CREATE TABLE IF NOT EXISTS public.room_actions (
  id BIGSERIAL PRIMARY KEY,
  room_id UUID NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
  seat SMALLINT NOT NULL CHECK (seat BETWEEN 0 AND 3),
  action JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS room_actions_room_idx ON public.room_actions (room_id, id);

CREATE TABLE IF NOT EXISTS public.room_chat (
  id bigserial PRIMARY KEY,
  room_id uuid NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
  seat smallint NOT NULL,
  phrase_id text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS room_chat_room_idx ON public.room_chat(room_id, created_at DESC);

CREATE TABLE IF NOT EXISTS public.room_text_chat (
  id BIGSERIAL PRIMARY KEY,
  room_id UUID NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
  seat SMALLINT NOT NULL CHECK (seat >= 0 AND seat <= 3),
  device_id TEXT NOT NULL,
  text TEXT NOT NULL CHECK (char_length(text) > 0 AND char_length(text) <= 200),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_room_text_chat_room_created ON public.room_text_chat(room_id, created_at DESC);

CREATE TABLE IF NOT EXISTS public.player_profiles (
  device_id text PRIMARY KEY,
  games_played integer NOT NULL DEFAULT 0,
  envit_called integer NOT NULL DEFAULT 0,
  envit_called_bluff integer NOT NULL DEFAULT 0,
  envit_accepted integer NOT NULL DEFAULT 0,
  envit_rejected integer NOT NULL DEFAULT 0,
  truc_called integer NOT NULL DEFAULT 0,
  truc_called_bluff integer NOT NULL DEFAULT 0,
  truc_accepted integer NOT NULL DEFAULT 0,
  truc_rejected integer NOT NULL DEFAULT 0,
  envit_strength_sum integer NOT NULL DEFAULT 0,
  envit_strength_n integer NOT NULL DEFAULT 0,
  truc_strength_sum integer NOT NULL DEFAULT 0,
  truc_strength_n integer NOT NULL DEFAULT 0,
  aggressiveness real NOT NULL DEFAULT 0.5,
  bluff_rate real NOT NULL DEFAULT 0.15,
  accept_threshold real NOT NULL DEFAULT 0.5,
  bot_difficulty text NOT NULL DEFAULT 'conservative' CHECK (bot_difficulty IN ('conservative', 'balanced', 'aggressive')),
  bot_honesty text NOT NULL DEFAULT 'sincero',
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.player_profiles DROP CONSTRAINT IF EXISTS player_profiles_bot_honesty_check;
ALTER TABLE public.player_profiles ADD CONSTRAINT player_profiles_bot_honesty_check CHECK (bot_honesty IN ('sincero', 'pillo', 'mentider'));

ALTER TABLE public.rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.room_players ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.room_actions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.room_chat ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.room_text_chat ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.player_profiles ENABLE ROW LEVEL SECURITY;

DO $$ DECLARE t text; BEGIN
  FOR t IN SELECT unnest(ARRAY['rooms','room_players','room_actions','room_chat','room_text_chat','player_profiles']) LOOP
    EXECUTE format('DROP POLICY IF EXISTS "%I_public_read" ON public.%I', t, t);
    EXECUTE format('CREATE POLICY "%I_public_read" ON public.%I FOR SELECT USING (true)', t, t);
    EXECUTE format('DROP POLICY IF EXISTS "%I_no_client_insert" ON public.%I', t, t);
    EXECUTE format('CREATE POLICY "%I_no_client_insert" ON public.%I FOR INSERT TO anon, authenticated WITH CHECK (false)', t, t);
    EXECUTE format('DROP POLICY IF EXISTS "%I_no_client_update" ON public.%I', t, t);
    EXECUTE format('CREATE POLICY "%I_no_client_update" ON public.%I FOR UPDATE TO anon, authenticated USING (false) WITH CHECK (false)', t, t);
    EXECUTE format('DROP POLICY IF EXISTS "%I_no_client_delete" ON public.%I', t, t);
    EXECUTE format('CREATE POLICY "%I_no_client_delete" ON public.%I FOR DELETE TO anon, authenticated USING (false)', t, t);
  END LOOP;
END $$;