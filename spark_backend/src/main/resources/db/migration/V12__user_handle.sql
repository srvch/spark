ALTER TABLE app_users
    ADD COLUMN IF NOT EXISTS handle VARCHAR(32);

CREATE UNIQUE INDEX IF NOT EXISTS ux_app_users_handle_lower
    ON app_users (LOWER(handle))
    WHERE handle IS NOT NULL;
