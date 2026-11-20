-- 002: accounts, doctor profile, patient profile (personal + health + consent)

CREATE TABLE users (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name              varchar(150) NOT NULL,
    email             varchar(255) NOT NULL,
    phone             varchar(30),
    password          varchar(255) NOT NULL,
    role              varchar(20)  NOT NULL DEFAULT 'patient',
    locale            varchar(2)   NOT NULL DEFAULT 'ar',
    email_verified_at timestamptz,
    is_active         boolean      NOT NULL DEFAULT true,
    last_login_at     timestamptz,
    remember_token    varchar(100),
    created_at        timestamptz  NOT NULL DEFAULT now(),
    updated_at        timestamptz  NOT NULL DEFAULT now(),
    CONSTRAINT users_role_check   CHECK (role IN ('patient', 'doctor')),
    CONSTRAINT users_locale_check CHECK (locale IN ('ar', 'en')),
    CONSTRAINT users_email_format CHECK (position('@' IN email) > 1)
);
-- case-insensitive uniqueness without needing the citext extension
CREATE UNIQUE INDEX users_email_lower_unique ON users (lower(email));
CREATE INDEX users_role_index  ON users (role);
CREATE INDEX users_phone_index ON users (phone);
CREATE INDEX users_name_trgm   ON users USING gin (name gin_trgm_ops);
CREATE INDEX users_email_trgm  ON users USING gin (email gin_trgm_ops);
CREATE INDEX users_phone_trgm  ON users USING gin (phone gin_trgm_ops);

CREATE TABLE doctor_profiles (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             uuid NOT NULL UNIQUE REFERENCES users (id) ON DELETE CASCADE,
    title_ar            varchar(150),
    title_en            varchar(150),
    specialization_ar   varchar(255),
    specialization_en   varchar(255),
    bio_ar              text,
    bio_en              text,
    years_experience    smallint,
    photo_path          varchar(500),               -- public asset (doctor's public photo)
    credentials         jsonb NOT NULL DEFAULT '[]'::jsonb,
    contact_email       varchar(255),
    contact_phone       varchar(30),
    whatsapp_number     varchar(30),
    address_ar          varchar(500),
    address_en          varchar(500),
    social_links        jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT doctor_profiles_years_check CHECK (years_experience IS NULL OR years_experience BETWEEN 0 AND 80)
);

CREATE TABLE patient_profiles (
    id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id                  uuid NOT NULL UNIQUE REFERENCES users (id) ON DELETE CASCADE,
    primary_doctor_id        uuid REFERENCES users (id) ON DELETE SET NULL,
    date_of_birth            date,
    gender                   varchar(10),
    city                     varchar(100),
    country                  varchar(100),
    height_cm                numeric(4,1),
    target_weight_kg         numeric(5,1),
    goal                     varchar(30),
    activity_level           varchar(20),
    -- sensitive free text: encrypted by the application (Eloquent "encrypted" cast), hence text
    medical_conditions       text,
    allergies                text,
    medications              text,
    dietary_preferences      text,
    notes                    text,
    emergency_contact_name   varchar(150),
    emergency_contact_phone  varchar(30),
    health_completed_at      timestamptz,
    consent_version          varchar(20),
    privacy_accepted_at      timestamptz,
    health_consent_at        timestamptz,
    created_at               timestamptz NOT NULL DEFAULT now(),
    updated_at               timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT patient_gender_check   CHECK (gender IS NULL OR gender IN ('male', 'female')),
    CONSTRAINT patient_goal_check     CHECK (goal IS NULL OR goal IN
        ('lose_weight', 'gain_weight', 'maintain', 'muscle_gain', 'medical_condition', 'other')),
    CONSTRAINT patient_activity_check CHECK (activity_level IS NULL OR activity_level IN
        ('sedentary', 'light', 'moderate', 'active', 'very_active')),
    CONSTRAINT patient_height_check   CHECK (height_cm IS NULL OR height_cm BETWEEN 50 AND 250),
    CONSTRAINT patient_target_check   CHECK (target_weight_kg IS NULL OR target_weight_kg BETWEEN 20 AND 400),
    CONSTRAINT patient_dob_check      CHECK (date_of_birth IS NULL OR date_of_birth <= CURRENT_DATE),
    -- a health profile cannot be marked complete without recorded health-data consent
    CONSTRAINT patient_health_needs_consent CHECK (health_completed_at IS NULL OR health_consent_at IS NOT NULL)
);
CREATE INDEX patient_profiles_doctor_index ON patient_profiles (primary_doctor_id);
