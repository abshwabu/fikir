-- PostgreSQL initialization script for Fikir
-- Automatically executed when the Postgres container starts for the first time

\connect fikir;

CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
