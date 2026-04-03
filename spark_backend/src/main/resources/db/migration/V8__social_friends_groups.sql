create table if not exists friend_requests (
    id uuid primary key,
    from_user_id varchar(128) not null,
    to_user_id varchar(128) not null,
    status varchar(16) not null default 'PENDING',
    created_at timestamptz not null default now(),
    responded_at timestamptz,
    updated_at timestamptz not null default now(),
    constraint uk_friend_requests_from_to unique (from_user_id, to_user_id)
);

create index if not exists idx_friend_requests_to_status on friend_requests (to_user_id, status);
create index if not exists idx_friend_requests_from_status on friend_requests (from_user_id, status);

create table if not exists spark_groups (
    id uuid primary key,
    owner_user_id varchar(128) not null,
    name varchar(140) not null,
    description varchar(280),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists spark_group_members (
    id uuid primary key,
    group_id uuid not null references spark_groups(id) on delete cascade,
    user_id varchar(128) not null,
    role varchar(16) not null default 'MEMBER',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint uk_group_members_group_user unique (group_id, user_id)
);

create index if not exists idx_group_members_user on spark_group_members (user_id);

create table if not exists spark_group_invites (
    id uuid primary key,
    group_id uuid not null references spark_groups(id) on delete cascade,
    inviter_user_id varchar(128) not null,
    invitee_user_id varchar(128) not null,
    status varchar(16) not null default 'PENDING',
    created_at timestamptz not null default now(),
    acted_at timestamptz,
    updated_at timestamptz not null default now(),
    constraint uk_group_invites_group_user unique (group_id, invitee_user_id)
);

create index if not exists idx_group_invites_invitee_status on spark_group_invites (invitee_user_id, status);
