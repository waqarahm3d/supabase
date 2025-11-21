-- Webhooks support for Supabase
-- This enables pg_net for HTTP requests from PostgreSQL

-- Create the schema for webhooks
CREATE SCHEMA IF NOT EXISTS supabase_functions;

-- Grant permissions
GRANT USAGE ON SCHEMA supabase_functions TO postgres, anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA supabase_functions GRANT ALL ON TABLES TO postgres, anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA supabase_functions GRANT ALL ON FUNCTIONS TO postgres, anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA supabase_functions GRANT ALL ON SEQUENCES TO postgres, anon, authenticated, service_role;
