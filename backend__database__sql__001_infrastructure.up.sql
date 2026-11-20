-- EL SHEHAB NUTRITION: Developed & Powered by CODING Systems
-- 001: extensions and Laravel infrastructure tables (sessions, cache, queue)

CREATE EXTENSION IF NOT EXISTS btree_gist;  -- needed for the appointment overlap exclusion constraint
CREATE EXTENSION IF NOT EXISTS pg_trgm;     -- fast ILIKE search on patient name / phone / email

CREATE TABLE password_reset_tokens (
    email      varchar(255) PRIMARY KEY,
    token      varchar(255) NOT NULL,
    created_at timestamptz
);

CREATE TABLE sessions (
    id            varchar(255) PRIMARY KEY,
    user_id       uuid,
    ip_address    varchar(45),
    user_agent    text,
    payload       text NOT NULL,
    last_activity integer NOT NULL
);
CREATE INDEX sessions_user_id_index ON sessions (user_id);
CREATE INDEX sessions_last_activity_index ON sessions (last_activity);

CREATE TABLE cache (
    key        varchar(255) PRIMARY KEY,
    value      text NOT NULL,
    expiration integer NOT NULL
);
CREATE INDEX cache_expiration_index ON cache (expiration);

CREATE TABLE cache_locks (
    key        varchar(255) PRIMARY KEY,
    owner      varchar(255) NOT NULL,
    expiration integer NOT NULL
);
CREATE INDEX cache_locks_expiration_index ON cache_locks (expiration);

CREATE TABLE jobs (
    id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    queue        varchar(255) NOT NULL,
    payload      text NOT NULL,
    attempts     smallint NOT NULL,
    reserved_at  integer,
    available_at integer NOT NULL,
    created_at   integer NOT NULL
);
CREATE INDEX jobs_queue_index ON jobs (queue);

CREATE TABLE job_batches (
    id             varchar(255) PRIMARY KEY,
    name           varchar(255) NOT NULL,
    total_jobs     integer NOT NULL,
    pending_jobs   integer NOT NULL,
    failed_jobs    integer NOT NULL,
    failed_job_ids text NOT NULL,
    options        text,
    cancelled_at   integer,
    created_at     integer NOT NULL,
    finished_at    integer
);

CREATE TABLE failed_jobs (
    id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uuid       varchar(255) NOT NULL UNIQUE,
    connection text NOT NULL,
    queue      text NOT NULL,
    payload    text NOT NULL,
    exception  text NOT NULL,
    failed_at  timestamptz NOT NULL DEFAULT now()
);
