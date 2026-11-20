-- 006: diet plans, progress tracking, patient health files

CREATE TABLE diet_plans (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id            uuid NOT NULL REFERENCES users (id) ON DELETE RESTRICT,
    doctor_id             uuid NOT NULL REFERENCES users (id) ON DELETE RESTRICT,
    appointment_id        uuid REFERENCES appointments (id) ON DELETE SET NULL,
    title                 varchar(200) NOT NULL,
    start_date            date NOT NULL,
    end_date              date NOT NULL,
    target_calories       integer,
    general_instructions  text,
    notes                 text,
    status                varchar(15) NOT NULL DEFAULT 'draft',
    published_at          timestamptz,
    archived_at           timestamptz,
    created_at            timestamptz NOT NULL DEFAULT now(),
    updated_at            timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT diet_plans_status_check CHECK (status IN ('draft', 'published', 'archived')),
    CONSTRAINT diet_plans_dates_check  CHECK (end_date >= start_date),
    CONSTRAINT diet_plans_calories_check CHECK (target_calories IS NULL OR target_calories BETWEEN 500 AND 10000),
    CONSTRAINT diet_plans_published_needs_date CHECK (status = 'draft' OR published_at IS NOT NULL),
    CONSTRAINT diet_plans_archived_needs_date  CHECK (status <> 'archived' OR archived_at IS NOT NULL)
);
CREATE INDEX diet_plans_patient_index ON diet_plans (patient_id, status, start_date DESC);
CREATE INDEX diet_plans_doctor_index  ON diet_plans (doctor_id, status);

CREATE TABLE diet_meals (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    diet_plan_id uuid NOT NULL REFERENCES diet_plans (id) ON DELETE CASCADE,
    day_of_week  smallint,                -- NULL = every day; 0 = Sunday ... 6 = Saturday
    name         varchar(150) NOT NULL,   -- e.g. Breakfast, Snack
    meal_time    time,
    sort_order   integer NOT NULL DEFAULT 0,
    notes        text,
    created_at   timestamptz NOT NULL DEFAULT now(),
    updated_at   timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT diet_meals_day_check CHECK (day_of_week IS NULL OR day_of_week BETWEEN 0 AND 6)
);
CREATE INDEX diet_meals_plan_index ON diet_meals (diet_plan_id, day_of_week, sort_order);

CREATE TABLE meal_items (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    diet_meal_id uuid NOT NULL REFERENCES diet_meals (id) ON DELETE CASCADE,
    food_name    varchar(200) NOT NULL,
    quantity     numeric(8,2),
    unit         varchar(40),             -- g, ml, cup, piece, spoon ...
    calories     numeric(7,1),
    protein_g    numeric(6,1),
    carbs_g      numeric(6,1),
    fat_g        numeric(6,1),
    alternatives text,
    notes        text,
    sort_order   integer NOT NULL DEFAULT 0,
    created_at   timestamptz NOT NULL DEFAULT now(),
    updated_at   timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT meal_items_quantity_check CHECK (quantity IS NULL OR quantity > 0),
    CONSTRAINT meal_items_macros_check CHECK (
        coalesce(calories, 0) >= 0 AND coalesce(protein_g, 0) >= 0 AND
        coalesce(carbs_g, 0) >= 0 AND coalesce(fat_g, 0) >= 0)
);
CREATE INDEX meal_items_meal_index ON meal_items (diet_meal_id, sort_order);

CREATE TABLE progress_records (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id   uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    recorded_on  date NOT NULL,
    weight_kg    numeric(5,2),
    body_fat_pct numeric(4,1),
    waist_cm     numeric(5,1),
    hips_cm      numeric(5,1),
    chest_cm     numeric(5,1),
    arm_cm       numeric(5,1),
    thigh_cm     numeric(5,1),
    notes        text,
    created_by   uuid REFERENCES users (id) ON DELETE SET NULL,
    created_at   timestamptz NOT NULL DEFAULT now(),
    updated_at   timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT progress_one_per_day UNIQUE (patient_id, recorded_on),
    CONSTRAINT progress_not_future  CHECK (recorded_on <= CURRENT_DATE + 1),
    CONSTRAINT progress_has_value   CHECK (
        weight_kg IS NOT NULL OR body_fat_pct IS NOT NULL OR waist_cm IS NOT NULL OR hips_cm IS NOT NULL OR
        chest_cm IS NOT NULL OR arm_cm IS NOT NULL OR thigh_cm IS NOT NULL),
    CONSTRAINT progress_weight_check CHECK (weight_kg IS NULL OR weight_kg BETWEEN 20 AND 400),
    CONSTRAINT progress_fat_check    CHECK (body_fat_pct IS NULL OR body_fat_pct BETWEEN 2 AND 80),
    CONSTRAINT progress_girth_check  CHECK (
        coalesce(waist_cm, 1) > 0 AND coalesce(hips_cm, 1) > 0 AND coalesce(chest_cm, 1) > 0 AND
        coalesce(arm_cm, 1) > 0 AND coalesce(thigh_cm, 1) > 0)
);
CREATE INDEX progress_patient_date_index ON progress_records (patient_id, recorded_on DESC);

CREATE TABLE patient_files (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id    uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    uploaded_by   uuid REFERENCES users (id) ON DELETE SET NULL,
    category      varchar(20) NOT NULL DEFAULT 'other',
    description   varchar(300),
    disk          varchar(20) NOT NULL DEFAULT 'private',
    storage_path  varchar(500) NOT NULL UNIQUE,
    original_name varchar(255) NOT NULL,
    mime_type     varchar(100) NOT NULL,
    size_bytes    integer NOT NULL,
    sha256        char(64) NOT NULL,
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT patient_files_disk_private CHECK (disk = 'private'),
    CONSTRAINT patient_files_category_check CHECK (category IN ('lab_result', 'medical_report', 'prescription', 'other')),
    CONSTRAINT patient_files_mime_check CHECK (mime_type IN ('image/jpeg', 'image/png', 'image/webp', 'application/pdf')),
    CONSTRAINT patient_files_size_check CHECK (size_bytes > 0 AND size_bytes <= 10485760)
);
CREATE INDEX patient_files_patient_index ON patient_files (patient_id, created_at DESC);
