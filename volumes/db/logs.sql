-- Analytics and logging schema
CREATE SCHEMA IF NOT EXISTS _analytics;

-- Grant permissions for analytics
GRANT USAGE ON SCHEMA _analytics TO supabase_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA _analytics GRANT ALL ON TABLES TO supabase_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA _analytics GRANT ALL ON FUNCTIONS TO supabase_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA _analytics GRANT ALL ON SEQUENCES TO supabase_admin;
