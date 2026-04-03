-- ─────────────────────────────────────────────────────────────────────────────
-- V9: Social enhancements + new feature columns
-- Covers: availability, block/report, friend-request message,
--         group archive, recurring sparks, user bio/interests,
--         in-app notification centre
-- ─────────────────────────────────────────────────────────────────────────────

-- 1. app_users: availability status, bio, interests
alter table app_users
    add column if not exists availability_status varchar(20) not null default 'NONE',
    add column if not exists bio                 varchar(280),
    add column if not exists interests           text;          -- stored as comma-separated values

-- 2. friend_requests: optional message on send
alter table friend_requests
    add column if not exists message varchar(280);

-- 3. spark_groups: archive support
alter table spark_groups
    add column if not exists archived    boolean     not null default false,
    add column if not exists archived_at timestamptz;

create index if not exists idx_spark_groups_archived on spark_groups (archived);

-- 4. user_blocks
create table if not exists user_blocks (
    id              uuid        primary key default gen_random_uuid(),
    blocker_user_id varchar(128) not null,
    blocked_user_id varchar(128) not null,
    created_at      timestamptz  not null default now(),
    constraint uk_user_blocks_blocker_blocked unique (blocker_user_id, blocked_user_id)
);

create index if not exists idx_user_blocks_blocker on user_blocks (blocker_user_id);
create index if not exists idx_user_blocks_blocked on user_blocks (blocked_user_id);

-- 5. user_reports
create table if not exists user_reports (
    id               uuid        primary key default gen_random_uuid(),
    reporter_user_id varchar(128) not null,
    reported_user_id varchar(128) not null,
    reason           varchar(500),
    created_at       timestamptz  not null default now()
);

create index if not exists idx_user_reports_reporter on user_reports (reporter_user_id);
create index if not exists idx_user_reports_reported on user_reports (reported_user_id);

-- 6. spark_events: recurring spark support
alter table spark_events
    add column if not exists recurrence_type     varchar(20),   -- NULL | DAILY | WEEKLY
    add column if not exists recurrence_end_date date,
    add column if not exists parent_spark_id     uuid references spark_events(id) on delete set null;

create index if not exists idx_spark_events_parent on spark_events (parent_spark_id);

-- 7. app_notifications: unified in-app notification centre
create table if not exists app_notifications (
    id           uuid        primary key default gen_random_uuid(),
    user_id      varchar(128) not null,
    type         varchar(40)  not null,   -- FRIEND_REQUEST | RSVP | GROUP_INVITE | NUDGE | SYSTEM
    title        varchar(140) not null,
    body         varchar(280),
    reference_id varchar(128),            -- spark_id, friend_request_id, group_id, etc.
    is_read      boolean      not null default false,
    created_at   timestamptz  not null default now()
);

create index if not exists idx_app_notifications_user_read    on app_notifications (user_id, is_read);
create index if not exists idx_app_notifications_user_created on app_notifications (user_id, created_at desc);
