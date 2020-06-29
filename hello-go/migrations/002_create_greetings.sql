-- This is a sample migration.

create table greetings(
  uuid uuid not null default uuid_generate_v4(),
  first_name varchar not null,
  text varchar not null,
  created_at timestamptz not null default NOW()
);

create index greetings_created_at ON greetings (created_at);


---- create above / drop below ----

drop table greetings;
