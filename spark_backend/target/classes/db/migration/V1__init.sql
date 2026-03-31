create extension if not exists "pgcrypto";

create table if not exists spark_events (
  id uuid primary key default gen_random_uuid(),
  host_user_id varchar(128) not null,
  category varchar(32) not null,
  title varchar(180) not null,
  note varchar(300),
  location_name varchar(180) not null,
  latitude double precision not null,
  longitude double precision not null,
  starts_at timestamptz not null,
  ends_at timestamptz,
  max_spots integer not null check (max_spots > 0),
  status varchar(16) not null default 'ACTIVE',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists spark_participants (
  id bigserial primary key,
  spark_id uuid not null references spark_events(id) on delete cascade,
  user_id varchar(128) not null,
  joined_at timestamptz not null default now(),
  status varchar(16) not null default 'JOINED',
  unique (spark_id, user_id)
);

create index if not exists idx_spark_events_status_starts_at
  on spark_events(status, starts_at);

create index if not exists idx_spark_participants_spark_id_status
  on spark_participants(spark_id, status);
