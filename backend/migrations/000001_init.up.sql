-- Migration 000001: Initial setup
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE TABLE IF NOT EXISTS schema_initialization (
    id SERIAL PRIMARY KEY,
    description TEXT NOT NULL DEFAULT 'Fikir dating app initial schema',
    initialized_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
