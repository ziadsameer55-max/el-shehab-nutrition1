-- 004: doctor availability and appointments (with database-level double-booking prevention)

CREATE TABLE working_hours (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    doctor_id   uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    weekday     smallint NOT NULL,          -- 0 = Sunday ... 6 = Saturday (clinic local time)
    start_time  time NOT NULL,
    end_time    time NOT NULL,
    is_active   boolean NOT NULL DEFAULT true,
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT working_hours_weekday_check CHECK (weekday BETWEEN 0 AND 6),
    CONSTRAINT working_hours_order_check   CHECK (end_time > start_time),
    CONSTRAINT working_hours_unique UNIQUE (doctor_id, weekday, start_time)
);

-- vacations / days off / one-off blocks
CREATE TABLE time_off (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    doctor_id   uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    starts_at   timestamptz NOT NULL,
    ends_at     timestamptz NOT NULL,
    reason      varchar(255),
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT time_off_order_check CHECK (ends_at > starts_at)
);
CREATE INDEX time_off_range_index ON time_off (doctor_id, starts_at, ends_at);

CREATE TABLE appointments (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id          uuid NOT NULL REFERENCES users (id)    ON DELETE RESTRICT,
    doctor_id           uuid NOT NULL REFERENCES users (id)    ON DELETE RESTRICT,
    service_id          uuid NOT NULL REFERENCES services (id) ON DELETE RESTRICT,
    package_id          uuid REFERENCES packages (id)          ON DELETE RESTRICT,
    starts_at           timestamptz NOT NULL,
    ends_at             timestamptz NOT NULL,
    -- ends_at + buffer. Stored (not computed) so it can be used in the exclusion constraint.
    blocked_until       timestamptz NOT NULL,
    status              varchar(20) NOT NULL DEFAULT 'pending_payment',
    price               numeric(10,2) NOT NULL,          -- snapshot of the price at booking time
    currency            char(3) NOT NULL DEFAULT 'EGP',
    hold_expires_at     timestamptz,                     -- NULL while payment is under review
    meet_url            varchar(500),
    patient_notes       text,
    doctor_notes        text,
    confirmed_at        timestamptz,
    completed_at        timestamptz,
    cancelled_at        timestamptz,
    cancelled_by        uuid REFERENCES users (id) ON DELETE SET NULL,
    cancellation_reason text,
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT appointments_status_check CHECK (status IN
        ('pending_payment', 'confirmed', 'completed', 'no_show', 'cancelled', 'expired')),
    CONSTRAINT appointments_time_order   CHECK (ends_at > starts_at),
    CONSTRAINT appointments_blocked_check CHECK (blocked_until >= ends_at),
    CONSTRAINT appointments_price_check  CHECK (price >= 0),
    CONSTRAINT appointments_confirmed_needs_date CHECK (
        status NOT IN ('confirmed', 'completed', 'no_show') OR confirmed_at IS NOT NULL),
    CONSTRAINT appointments_cancelled_needs_date CHECK (status <> 'cancelled' OR cancelled_at IS NOT NULL),
    CONSTRAINT appointments_meet_url_check CHECK (meet_url IS NULL OR meet_url ~ '^https://meet\.google\.com/[A-Za-z0-9/_?=&.-]+$'),
    -- THE guarantee against double booking under concurrent requests:
    -- no two non-released appointments of the same doctor may overlap in time.
    CONSTRAINT appointments_no_overlap EXCLUDE USING gist (
        doctor_id WITH =,
        tstzrange(starts_at, blocked_until, '[)') WITH &&
    ) WHERE (status NOT IN ('cancelled', 'expired'))
);
-- human-friendly booking number shown to patients and in the payments screen
ALTER TABLE appointments ADD COLUMN number bigint GENERATED ALWAYS AS IDENTITY;
ALTER TABLE appointments ADD CONSTRAINT appointments_number_unique UNIQUE (number);

CREATE INDEX appointments_patient_index ON appointments (patient_id, starts_at DESC);
CREATE INDEX appointments_doctor_index  ON appointments (doctor_id, starts_at);
CREATE INDEX appointments_status_index  ON appointments (status, starts_at);
-- used by the scheduled job that releases unpaid holds
CREATE INDEX appointments_hold_expiry_index ON appointments (hold_expires_at)
    WHERE status = 'pending_payment' AND hold_expires_at IS NOT NULL;
