CREATE TABLE IF NOT EXISTS public.admin_passwords (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  password_hash TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.admin_passwords ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "admin_passwords_no_client" ON public.admin_passwords;
CREATE POLICY "admin_passwords_no_client" ON public.admin_passwords FOR ALL TO anon, authenticated USING (false) WITH CHECK (false);