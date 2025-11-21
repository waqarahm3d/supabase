-- Create the roles required for Supabase

-- Authenticator role for PostgREST
CREATE ROLE authenticator NOINHERIT LOGIN PASSWORD 'POSTGRES_PASSWORD_PLACEHOLDER';

-- Anon role for anonymous access
CREATE ROLE anon NOLOGIN;
GRANT anon TO authenticator;

-- Authenticated role for logged-in users
CREATE ROLE authenticated NOLOGIN;
GRANT authenticated TO authenticator;

-- Service role for admin/service access
CREATE ROLE service_role NOLOGIN;
GRANT service_role TO authenticator;

-- Supabase admin role
CREATE ROLE supabase_admin LOGIN PASSWORD 'POSTGRES_PASSWORD_PLACEHOLDER';

-- Auth admin role
CREATE ROLE supabase_auth_admin NOLOGIN;
GRANT supabase_auth_admin TO supabase_admin;

-- Storage admin role
CREATE ROLE supabase_storage_admin NOLOGIN;
GRANT supabase_storage_admin TO supabase_admin;

-- Grant necessary permissions
GRANT ALL ON DATABASE postgres TO supabase_admin;
GRANT ALL ON SCHEMA public TO supabase_admin;
GRANT ALL ON ALL TABLES IN SCHEMA public TO supabase_admin;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO supabase_admin;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO supabase_admin;

-- Grant usage on public schema
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO anon, authenticated, service_role;
