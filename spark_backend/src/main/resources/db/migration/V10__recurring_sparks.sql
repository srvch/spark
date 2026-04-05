-- V10: Recurring spark support columns + template linkage
-- Columns for recurrence were referenced in V9 but not fully mapped in the entity.

ALTER TABLE spark_events
    ADD COLUMN IF NOT EXISTS recurrence_type         VARCHAR(16),          -- NULL | DAILY | WEEKLY
    ADD COLUMN IF NOT EXISTS recurrence_day_of_week  INTEGER,              -- 1=Mon … 7=Sun (WEEKLY only)
    ADD COLUMN IF NOT EXISTS recurrence_time         VARCHAR(8),           -- HH:mm e.g. "18:30"
    ADD COLUMN IF NOT EXISTS recurrence_end_date     DATE,                 -- optional hard stop
    ADD COLUMN IF NOT EXISTS template_id             UUID REFERENCES spark_events(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS last_spawned_at         TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_spark_events_recurrence
    ON spark_events (recurrence_type, status)
    WHERE recurrence_type IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_spark_events_template
    ON spark_events (template_id)
    WHERE template_id IS NOT NULL;

-- Pre-compute next_occurs_at to speed up the scheduler query
ALTER TABLE spark_events
    ADD COLUMN IF NOT EXISTS next_occurs_at TIMESTAMPTZ;
