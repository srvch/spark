create table if not exists safety_alerts (
    id uuid primary key,
    user_id varchar(128) not null,
    spark_id uuid,
    location_name varchar(180) not null,
    note varchar(500),
    status varchar(20) not null default 'OPEN',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index if not exists ix_safety_alerts_user_created
    on safety_alerts (user_id, created_at desc);

create index if not exists ix_safety_alerts_spark_created
    on safety_alerts (spark_id, created_at desc);
