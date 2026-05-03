DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['rooms','room_players','room_actions','room_chat','room_text_chat','player_profiles'] LOOP
    BEGIN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
    EXCEPTION WHEN duplicate_object THEN NULL; WHEN others THEN NULL;
    END;
  END LOOP;
END $$;