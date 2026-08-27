-- ============================================================================
--  AnimeWatcher — MySQL schema
--  Run:  mysql -u root -p < schema.sql
-- ============================================================================

CREATE DATABASE IF NOT EXISTS anime_watcher
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE anime_watcher;

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
--  favorites
--  anime_id is an EXTERNAL catalog id (string/int from the scraping backend),
--  so it is stored as VARCHAR. A user cannot favorite the same anime twice.
--  Deleting a user cascades to their favorites.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS favorites (
    id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_id     BIGINT UNSIGNED NOT NULL,
    anime_id    VARCHAR(64)     NOT NULL,
    created_at  TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
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
--  watch_history
--  Tracks resume position per (user, anime, episode). The UNIQUE key lets us
--  UPSERT the playback_time as the user watches. Deleting a user cascades.
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
