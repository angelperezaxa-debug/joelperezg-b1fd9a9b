-- batch 0: migrations 2-7 (re-applies idempotent base, adds account_links and helpers)
-- ===== 20260502182142 (idempotent, mostly base re-create) =====
DO $$ BEGIN
  CREATE TYPE public.room_status AS ENUM ('lobby', 'playing', 'finished', 'abandoned');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE public.seat_kind AS ENUM ('human', 'bot', 'empty');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
-- (base tables already created in previous migration)