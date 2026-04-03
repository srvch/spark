alter table spark_events
  add column if not exists visibility varchar(16) not null default 'PUBLIC';

update spark_events
set visibility = 'PUBLIC'
where visibility is null;

alter table spark_events
  drop constraint if exists chk_spark_events_visibility;

alter table spark_events
  add constraint chk_spark_events_visibility
    check (visibility in ('PUBLIC', 'CIRCLE', 'INVITE'));

