-- ============================================================================
--  AnimeWatcher — Import-ready schema (shared hosts: Alwaysdata, etc.)
--
--  Use this file on hosts where the database ALREADY EXISTS and the MySQL user
--  cannot create databases (no global CREATE privilege). It contains the tables
--  only — no `CREATE DATABASE` / `USE`, which would fail on such hosts.
--
--  Import it INTO the already-selected database (e.g. `animewatcher_db`):
--    - phpMyAdmin: pick the DB in the left sidebar, then Import → choose file.
--    - CLI:  mysql -h mysql-<account>.alwaysdata.net -u <user> -p <db> < schema.import.sql
--
--  For a local install with full privileges, use ../schema.sql instead (it also
--  creates the database).
-- ============================================================================

-- ----------------------------------------------------------------------------
--  users
--  `password` stores a password_hash() digest (bcrypt/argon), never plaintext.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
    id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    name        VARCHAR(100)    NOT NULL,
    email       VARCHAR(191)    NOT NULL,
    password    VARCHAR(255)    NOT NULL,
    created_at  TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_users_email (email)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci;

-- ----------------------------------------------------------------------------
--  favorites (denormalized display metadata: title + cover_image)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS favorites (
    id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_id      BIGINT UNSIGNED NOT NULL,
    anime_id     VARCHAR(64)     NOT NULL,
    title        VARCHAR(255)    NULL,
    cover_image  VARCHAR(512)    NULL,
    created_at   TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_favorites_user_anime (user_id, anime_id),
    KEY idx_favorites_user (user_id),
    CONSTRAINT fk_favorites_user
        FOREIGN KEY (user_id) REFERENCES users (id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci;

-- ----------------------------------------------------------------------------
--  watch_history (resume position per user/anime/episode, UPSERTed)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS watch_history (
    id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_id        BIGINT UNSIGNED NOT NULL,
    anime_id       VARCHAR(64)     NOT NULL,
    episode_id     VARCHAR(64)     NOT NULL,
    playback_time  INT UNSIGNED    NOT NULL DEFAULT 0,  -- seconds into the episode
    updated_at     TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP
                                   ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_history_user_anime_episode (user_id, anime_id, episode_id),
    KEY idx_history_user (user_id),
    CONSTRAINT fk_history_user
        FOREIGN KEY (user_id) REFERENCES users (id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci;
