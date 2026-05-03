-- Tabla que vincula auth.users <-> device_id del juego
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
CREATE POLICY "account_links_self_select"
  ON public.account_links FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "account_links_self_update" ON public.account_links;
CREATE POLICY "account_links_self_update"
  ON public.account_links FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "account_links_no_client_insert" ON public.account_links;
CREATE POLICY "account_links_no_client_insert"
  ON public.account_links FOR INSERT
  TO anon, authenticated
  WITH CHECK (false);

DROP POLICY IF EXISTS "account_links_no_client_delete" ON public.account_links;
CREATE POLICY "account_links_no_client_delete"
  ON public.account_links FOR DELETE
  TO anon, authenticated
  USING (false);

-- updated_at trigger
CREATE OR REPLACE FUNCTION public.set_account_links_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_account_links_updated_at ON public.account_links;
CREATE TRIGGER trg_account_links_updated_at
BEFORE UPDATE ON public.account_links
FOR EACH ROW
EXECUTE FUNCTION public.set_account_links_updated_at();

-- Auto-crear vínculo al registrarse (toma device_id de raw_user_meta_data si lo manda la app)
CREATE OR REPLACE FUNCTION public.handle_new_user_account_link()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.account_links (user_id, email, device_id)
  VALUES (
    NEW.id,
    NEW.email,
    NULLIF(NEW.raw_user_meta_data->>'device_id', '')
  )
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created_account_link ON auth.users;
CREATE TRIGGER on_auth_user_created_account_link
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.handle_new_user_account_link();