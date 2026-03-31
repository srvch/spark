create table if not exists app_users (
  id uuid primary key default gen_random_uuid(),
  phone_number varchar(20) not null unique,
  display_name varchar(120) not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_app_users_phone
  on app_users(phone_number);
