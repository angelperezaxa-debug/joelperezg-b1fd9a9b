REVOKE EXECUTE ON FUNCTION public.set_account_links_updated_at() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.handle_new_user_account_link() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.set_account_deletion_requests_updated_at() FROM PUBLIC, anon, authenticated;