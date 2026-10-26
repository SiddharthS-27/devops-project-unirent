-- Runs once, when the postgres volume is first created.
-- One schema per owner; each owner's Alembic migrations create the tables.
-- The restricted app user and the no-UPDATE/DELETE grants on the ledger and audit tables come in week 2.

CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE SCHEMA IF NOT EXISTS security;  -- Siddharth
CREATE SCHEMA IF NOT EXISTS core;      -- Rammohan
CREATE SCHEMA IF NOT EXISTS payments;  -- Siddharth
CREATE SCHEMA IF NOT EXISTS workers;   -- Sasvat
