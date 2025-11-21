-- Realtime schema initialization
CREATE SCHEMA IF NOT EXISTS _realtime;

-- Grant permissions for realtime
GRANT USAGE ON SCHEMA _realtime TO postgres;

-- Create realtime schema permissions
ALTER DEFAULT PRIVILEGES IN SCHEMA _realtime GRANT ALL ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES IN SCHEMA _realtime GRANT ALL ON FUNCTIONS TO postgres;
ALTER DEFAULT PRIVILEGES IN SCHEMA _realtime GRANT ALL ON SEQUENCES TO postgres;

-- Enable realtime on specific tables (example)
-- Users can enable this on their own tables via the Studio UI
-- ALTER PUBLICATION supabase_realtime ADD TABLE your_table_name;
