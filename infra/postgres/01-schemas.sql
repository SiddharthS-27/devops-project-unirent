-- Runs once, when the postgres volume is first created.
-- One schema per owner; each owner's Alembic migrations create the tables.

CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE SCHEMA IF NOT EXISTS security;  -- Siddharth
CREATE SCHEMA IF NOT EXISTS core;      -- Rammohan
CREATE SCHEMA IF NOT EXISTS payments;  -- Siddharth
CREATE SCHEMA IF NOT EXISTS workers;   -- Sasvat
