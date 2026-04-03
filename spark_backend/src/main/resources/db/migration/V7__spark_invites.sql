create table if not exists spark_invites (
  id uuid primary key default gen_random_uuid(),
  spark_id uuid not null references spark_events(id) on delete cascade,
  from_user_id varchar(128) not null,
  to_user_id varchar(128) not null,
  status varchar(16) not null default 'PENDING',
  invited_at timestamptz not null default now(),
  acted_at timestamptz,
  updated_at timestamptz not null default now(),
  constraint uk_spark_invites_spark_to_user unique (spark_id, to_user_id),
  constraint chk_spark_invites_status check (status in ('PENDING', 'IN', 'MAYBE', 'DECLINED'))
);

create index if not exists idx_spark_invites_spark_id on spark_invites(spark_id);
create index if not exists idx_spark_invites_to_user_status on spark_invites(to_user_id, status);

