create table if not exists user_device_tokens (
    token varchar(255) primary key,
    user_id varchar(128) not null,
    platform varchar(16) not null,
    active boolean not null default true,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index if not exists ix_user_device_tokens_user_active
    on user_device_tokens (user_id, active);
