create table if not exists notification_preferences (
    user_id varchar(128) primary key,
    notify_join boolean not null default true,
    notify_leave_host boolean not null default true,
    notify_filling_fast boolean not null default true,
    notify_starts_15 boolean not null default true,
    notify_starts_60 boolean not null default false,
    notify_new_nearby boolean not null default true,
    interest_categories varchar(180) not null default 'sports,study,ride,events',
    radius_km integer not null default 5,
    updated_at timestamptz not null default now()
);

create table if not exists user_notifications (
    id uuid primary key,
    recipient_user_id varchar(128) not null,
    spark_id uuid,
    actor_user_id varchar(128),
    type varchar(40) not null,
    title varchar(180) not null,
    body varchar(300) not null,
    batch_count integer not null default 1,
    dedupe_key varchar(180),
    created_at timestamptz not null default now(),
    read_at timestamptz
);

create unique index if not exists uk_user_notifications_dedupe_key
    on user_notifications (dedupe_key)
    where dedupe_key is not null;

create index if not exists ix_user_notifications_recipient_created
    on user_notifications (recipient_user_id, created_at desc);

create index if not exists ix_user_notifications_spark_type
    on user_notifications (spark_id, type);
