-- 003: public content and catalog (bilingual: *_ar required, *_en optional with Arabic fallback)

CREATE TABLE services (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    slug             varchar(150) NOT NULL UNIQUE,
    name_ar          varchar(200) NOT NULL,
    name_en          varchar(200),
    description_ar   text,
    description_en   text,
    duration_minutes smallint     NOT NULL,
    price            numeric(10,2) NOT NULL,
    currency         char(3)      NOT NULL DEFAULT 'EGP',
    icon             varchar(50),
    is_active        boolean      NOT NULL DEFAULT true,
    sort_order       integer      NOT NULL DEFAULT 0,
    created_at       timestamptz  NOT NULL DEFAULT now(),
    updated_at       timestamptz  NOT NULL DEFAULT now(),
    CONSTRAINT services_duration_check CHECK (duration_minutes BETWEEN 10 AND 240),
    CONSTRAINT services_price_check    CHECK (price >= 0)
);
CREATE INDEX services_active_sort_index ON services (is_active, sort_order);

CREATE TABLE packages (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    slug            varchar(150) NOT NULL UNIQUE,
    name_ar         varchar(200) NOT NULL,
    name_en         varchar(200),
    description_ar  text,
    description_en  text,
    price           numeric(10,2) NOT NULL,
    currency        char(3)      NOT NULL DEFAULT 'EGP',
    sessions_count  smallint     NOT NULL DEFAULT 1,
    validity_days   smallint,
    features_ar     jsonb        NOT NULL DEFAULT '[]'::jsonb,
    features_en     jsonb        NOT NULL DEFAULT '[]'::jsonb,
    is_featured     boolean      NOT NULL DEFAULT false,
    is_active       boolean      NOT NULL DEFAULT true,
    sort_order      integer      NOT NULL DEFAULT 0,
    created_at      timestamptz  NOT NULL DEFAULT now(),
    updated_at      timestamptz  NOT NULL DEFAULT now(),
    CONSTRAINT packages_price_check    CHECK (price >= 0),
    CONSTRAINT packages_sessions_check CHECK (sessions_count BETWEEN 1 AND 100),
    CONSTRAINT packages_validity_check CHECK (validity_days IS NULL OR validity_days > 0),
    CONSTRAINT packages_features_ar_array CHECK (jsonb_typeof(features_ar) = 'array'),
    CONSTRAINT packages_features_en_array CHECK (jsonb_typeof(features_en) = 'array')
);
CREATE INDEX packages_active_sort_index ON packages (is_active, sort_order);

CREATE TABLE faqs (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    question_ar   varchar(500) NOT NULL,
    question_en   varchar(500),
    answer_ar     text         NOT NULL,
    answer_en     text,
    sort_order    integer      NOT NULL DEFAULT 0,
    is_published  boolean      NOT NULL DEFAULT true,
    created_at    timestamptz  NOT NULL DEFAULT now(),
    updated_at    timestamptz  NOT NULL DEFAULT now()
);
CREATE INDEX faqs_published_sort_index ON faqs (is_published, sort_order);

CREATE TABLE articles (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    slug              varchar(200) NOT NULL UNIQUE,
    title_ar          varchar(300) NOT NULL,
    title_en          varchar(300),
    excerpt_ar        varchar(600),
    excerpt_en        varchar(600),
    body_ar           text         NOT NULL,
    body_en           text,
    cover_image_path  varchar(500),
    status            varchar(15)  NOT NULL DEFAULT 'draft',
    published_at      timestamptz,
    author_id         uuid REFERENCES users (id) ON DELETE SET NULL,
    created_at        timestamptz  NOT NULL DEFAULT now(),
    updated_at        timestamptz  NOT NULL DEFAULT now(),
    CONSTRAINT articles_status_check CHECK (status IN ('draft', 'published', 'archived')),
    CONSTRAINT articles_published_needs_date CHECK (status <> 'published' OR published_at IS NOT NULL)
);
CREATE INDEX articles_status_published_index ON articles (status, published_at DESC);

-- Success stories: spec requires EXPLICIT patient consent before publishing text or photos.
CREATE TABLE success_stories (
    id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id              uuid REFERENCES users (id) ON DELETE SET NULL,
    display_name            varchar(150) NOT NULL,           -- e.g. first name or initials
    title_ar                varchar(300) NOT NULL,
    title_en                varchar(300),
    story_ar                text         NOT NULL,
    story_en                text,
    before_photo_path       varchar(500),
    after_photo_path        varchar(500),
    consent_given_at        timestamptz,
    consent_includes_photos boolean      NOT NULL DEFAULT false,
    consent_note            text,                             -- how/where consent was obtained
    is_published            boolean      NOT NULL DEFAULT false,
    published_at            timestamptz,
    sort_order              integer      NOT NULL DEFAULT 0,
    created_at              timestamptz  NOT NULL DEFAULT now(),
    updated_at              timestamptz  NOT NULL DEFAULT now(),
    CONSTRAINT stories_publish_needs_consent CHECK (is_published = false OR consent_given_at IS NOT NULL),
    CONSTRAINT stories_photos_need_consent CHECK (
        (before_photo_path IS NULL AND after_photo_path IS NULL) OR consent_includes_photos = true
    )
);
CREATE INDEX stories_published_index ON success_stories (is_published, sort_order);

CREATE TABLE contact_messages (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name        varchar(150) NOT NULL,
    email       varchar(255),
    phone       varchar(30),
    subject     varchar(200),
    message     text         NOT NULL,
    locale      varchar(2)   NOT NULL DEFAULT 'ar',
    status      varchar(15)  NOT NULL DEFAULT 'new',
    ip_address  inet,
    user_agent  text,
    handled_by  uuid REFERENCES users (id) ON DELETE SET NULL,
    handled_at  timestamptz,
    created_at  timestamptz  NOT NULL DEFAULT now(),
    updated_at  timestamptz  NOT NULL DEFAULT now(),
    CONSTRAINT contact_status_check  CHECK (status IN ('new', 'read', 'replied', 'archived')),
    CONSTRAINT contact_locale_check  CHECK (locale IN ('ar', 'en')),
    CONSTRAINT contact_has_channel   CHECK (email IS NOT NULL OR phone IS NOT NULL)
);
CREATE INDEX contact_status_created_index ON contact_messages (status, created_at DESC);
