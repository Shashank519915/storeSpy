-- RIP schema foundation + PostGIS
-- Ticket: RIP-1-041

CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE SCHEMA IF NOT EXISTS identity;
CREATE SCHEMA IF NOT EXISTS retail;
CREATE SCHEMA IF NOT EXISTS twin;

COMMENT ON SCHEMA identity IS 'Users, tenants, RBAC';
COMMENT ON SCHEMA retail IS 'Stores and inventory';
COMMENT ON SCHEMA twin IS 'Digital twin layouts and spatial objects';
