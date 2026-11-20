-- 007: notifications, settings, append-only audit log

-- Laravel's standard database-notification shape (notifiable_id is a UUID here)
CREATE TABLE notifications (
    id              uuid PRIMARY KEY,
    type            varchar(255) NOT NULL,
    notifiable_type varchar(255) NOT NULL,
    notifiable_id   uuid NOT NULL,
    data            jsonb NOT NULL,
    read_at         timestamptz,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX notifications_notifiable_index ON notifications (notifiable_type, notifiable_id);
CREATE INDEX notifications_unread_index ON notifications (notifiable_id, created_at DESC) WHERE read_at IS NULL;

CREATE TABLE settings (
    key        varchar(100) PRIMARY KEY,
    value      jsonb NOT NULL,
    updated_by uuid REFERENCES users (id) ON DELETE SET NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

-- No FK on actor_id on purpose: deleting a user must never modify (or be blocked by) audit history.
CREATE TABLE audit_logs (
    id             bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    actor_id       uuid,
    actor_role     varchar(20),
    event          varchar(80) NOT NULL,      -- e.g. payment.approved, payment.rejected, diet_plan.updated
    auditable_type varchar(100),
    auditable_id   uuid,
    old_values     jsonb,
    new_values     jsonb,
    metadata       jsonb,                     -- e.g. rejection reason
    ip_address     inet,
    user_agent     text,
    created_at     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX audit_logs_subject_index ON audit_logs (auditable_type, auditable_id);
CREATE INDEX audit_logs_actor_index   ON audit_logs (actor_id, created_at DESC);
CREATE INDEX audit_logs_event_index   ON audit_logs (event, created_at DESC);

CREATE OR REPLACE FUNCTION audit_logs_block_changes() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'audit_logs is append-only (% not allowed)', TG_OP
        USING ERRCODE = 'insufficient_privilege';
END;
$$;

CREATE TRIGGER audit_logs_no_update_delete
    BEFORE UPDATE OR DELETE ON audit_logs
    FOR EACH ROW EXECUTE FUNCTION audit_logs_block_changes();

CREATE TRIGGER audit_logs_no_truncate
    BEFORE TRUNCATE ON audit_logs
    FOR EACH STATEMENT EXECUTE FUNCTION audit_logs_block_changes();
