-- 005: manual payment workflow (clinic receiving details, payment, receipt proofs)
-- No card or sensitive payment data is stored. Receipts are files on the PRIVATE disk.

CREATE TABLE payment_methods (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    type              varchar(20) NOT NULL,
    name_ar           varchar(200) NOT NULL,
    name_en           varchar(200),
    account_holder    varchar(200),
    account_number    varchar(100) NOT NULL,       -- clinic's RECEIVING account / wallet number
    instructions_ar   text,
    instructions_en   text,
    is_active         boolean NOT NULL DEFAULT true,
    sort_order        integer NOT NULL DEFAULT 0,
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT payment_methods_type_check CHECK (type IN ('bank_transfer', 'mobile_wallet', 'instapay', 'other'))
);

CREATE TABLE payments (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    appointment_id   uuid NOT NULL UNIQUE REFERENCES appointments (id) ON DELETE RESTRICT,
    amount           numeric(10,2) NOT NULL,
    currency         char(3) NOT NULL DEFAULT 'EGP',
    status           varchar(20) NOT NULL DEFAULT 'awaiting_proof',
    reviewed_by      uuid REFERENCES users (id) ON DELETE SET NULL,
    reviewed_at      timestamptz,
    rejection_reason text,
    refunded_at      timestamptz,
    refund_note      text,
    created_at       timestamptz NOT NULL DEFAULT now(),
    updated_at       timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT payments_status_check CHECK (status IN
        ('awaiting_proof', 'under_review', 'approved', 'rejected', 'refunded')),
    CONSTRAINT payments_amount_check CHECK (amount >= 0),
    CONSTRAINT payments_rejection_needs_reason CHECK (
        status <> 'rejected' OR (rejection_reason IS NOT NULL AND length(btrim(rejection_reason)) >= 3)),
    CONSTRAINT payments_approval_needs_reviewer CHECK (
        status <> 'approved' OR (reviewed_by IS NOT NULL AND reviewed_at IS NOT NULL))
);
CREATE INDEX payments_status_index ON payments (status, created_at);

CREATE TABLE payment_proofs (
    id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_id         uuid NOT NULL REFERENCES payments (id) ON DELETE CASCADE,
    uploaded_by        uuid REFERENCES users (id) ON DELETE SET NULL,
    payment_method_id  uuid REFERENCES payment_methods (id) ON DELETE SET NULL,
    disk               varchar(20) NOT NULL DEFAULT 'private',
    storage_path       varchar(500) NOT NULL UNIQUE,      -- random server-side name, never the user's
    original_name      varchar(255) NOT NULL,
    mime_type          varchar(100) NOT NULL,
    size_bytes         integer NOT NULL,
    sha256             char(64) NOT NULL,
    sender_name        varchar(150),
    transfer_reference varchar(100),
    transferred_amount numeric(10,2),
    transferred_at     timestamptz,
    status             varchar(20) NOT NULL DEFAULT 'under_review',
    rejection_reason   text,
    reviewed_by        uuid REFERENCES users (id) ON DELETE SET NULL,
    reviewed_at        timestamptz,
    created_at         timestamptz NOT NULL DEFAULT now(),
    updated_at         timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT proofs_disk_private CHECK (disk = 'private'),
    CONSTRAINT proofs_status_check CHECK (status IN ('under_review', 'approved', 'rejected')),
    CONSTRAINT proofs_mime_check   CHECK (mime_type IN ('image/jpeg', 'image/png', 'image/webp', 'application/pdf')),
    CONSTRAINT proofs_size_check   CHECK (size_bytes > 0 AND size_bytes <= 10485760),
    CONSTRAINT proofs_rejection_needs_reason CHECK (
        status <> 'rejected' OR (rejection_reason IS NOT NULL AND length(btrim(rejection_reason)) >= 3)),
    CONSTRAINT proofs_review_consistency CHECK (
        status = 'under_review' OR (reviewed_by IS NOT NULL AND reviewed_at IS NOT NULL))
);
-- at most ONE proof waiting for review per payment; older ones are history
CREATE UNIQUE INDEX proofs_one_pending_per_payment ON payment_proofs (payment_id) WHERE status = 'under_review';
CREATE INDEX proofs_payment_index ON payment_proofs (payment_id, created_at DESC);
-- not unique on purpose: lets the doctor be warned if the same receipt file is reused on another booking
CREATE INDEX proofs_sha256_index ON payment_proofs (sha256);
