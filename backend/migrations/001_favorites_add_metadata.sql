-- ============================================================================
--  Migration 001 — denormalize display metadata into `favorites`
--
--  Adds title + cover_image so GET /favorites can return ready-to-render
--  anime cards without a second catalog/Jikan lookup.
--
--  Run against an existing database:
--     mysql -u root -p anime_watcher < migrations/001_favorites_add_metadata.sql
--
--  (Fresh installs already include these columns via schema.sql.)
-- ============================================================================

USE anime_watcher;

ALTER TABLE favorites
    ADD COLUMN title       VARCHAR(255) NULL AFTER anime_id,
    ADD COLUMN cover_image VARCHAR(512) NULL AFTER title;
