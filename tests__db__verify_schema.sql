-- EL SHEHAB NUTRITION: Developed & Powered by CODING Systems
-- Database-level acceptance tests. Run against a database that already has all migrations applied.
-- Every "expect_*" block must raise the named error; if the statement unexpectedly succeeds, the
-- block raises TEST FAILED and psql (with ON_ERROR_STOP) exits non-zero. Everything is rolled back.

\set ON_ERROR_STOP on
BEGIN;

-- ---------- fixtures ----------
INSERT INTO users (id, name, email, password, role) VALUES
 ('00000000-0000-0000-0000-0000000000d1', 'Dr Test',   'doc@example.com',  'x', 'doctor'),
 ('00000000-0000-0000-0000-0000000000d2', 'Dr Other',  'doc2@example.com', 'x', 'doctor'),
 ('00000000-0000-0000-0000-0000000000a1', 'Patient A', 'a@example.com',    'x', 'patient'),
 ('00000000-0000-0000-0000-0000000000a2', 'Patient B', 'b@example.com',    'x', 'patient');
INSERT INTO services (id, slug, name_ar, duration_minutes, price)
 VALUES ('00000000-0000-0000-0000-0000000000e1', 'first-visit', 'كشف', 45, 300);

-- helper: insert an appointment for patient A (or B) with given start, minutes, buffer, doctor, status
CREATE FUNCTION t_appt(p_start timestamptz, p_min int, p_buffer int,
                       p_doctor uuid DEFAULT '00000000-0000-0000-0000-0000000000d1',
                       p_status text DEFAULT 'pending_payment',
                       p_patient uuid DEFAULT '00000000-0000-0000-0000-0000000000a1')
RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE v_id uuid;
BEGIN
  INSERT INTO appointments (patient_id, doctor_id, service_id, starts_at, ends_at, blocked_until, status, price,
                            confirmed_at, cancelled_at)
  VALUES (p_patient, p_doctor, '00000000-0000-0000-0000-0000000000e1', p_start,
          p_start + make_interval(mins => p_min), p_start + make_interval(mins => p_min + p_buffer), p_status, 300,
          CASE WHEN p_status IN ('confirmed','completed','no_show') THEN now() END,
          CASE WHEN p_status = 'cancelled' THEN now() END)
  RETURNING id INTO v_id;
  RETURN v_id;
END $$;

-- ---------- 1. double booking ----------
DO $$
DECLARE a uuid; b uuid;
BEGIN
  a := t_appt('2030-01-10 10:00+00', 45, 5);
  -- exact same slot, other patient
  BEGIN
    PERFORM t_appt('2030-01-10 10:00+00', 45, 5, p_patient => '00000000-0000-0000-0000-0000000000a2');
    RAISE EXCEPTION 'TEST FAILED: identical slot was accepted';
  EXCEPTION WHEN exclusion_violation THEN RAISE NOTICE 'PASS: identical slot rejected'; END;
  -- partial overlap
  BEGIN
    PERFORM t_appt('2030-01-10 10:30+00', 45, 5);
    RAISE EXCEPTION 'TEST FAILED: overlapping slot was accepted';
  EXCEPTION WHEN exclusion_violation THEN RAISE NOTICE 'PASS: overlapping slot rejected'; END;
  -- inside the buffer (A blocks until 10:50)
  BEGIN
    PERFORM t_appt('2030-01-10 10:48+00', 45, 0);
    RAISE EXCEPTION 'TEST FAILED: slot inside buffer was accepted';
  EXCEPTION WHEN exclusion_violation THEN RAISE NOTICE 'PASS: buffer time respected'; END;
  -- immediately after the buffer is fine
  b := t_appt('2030-01-10 10:50+00', 45, 5);
  RAISE NOTICE 'PASS: back-to-back slot after buffer accepted';
  -- another doctor at the same time is fine
  PERFORM t_appt('2030-01-10 10:00+00', 45, 5, p_doctor => '00000000-0000-0000-0000-0000000000d2');
  RAISE NOTICE 'PASS: different doctor, same time accepted';
  -- cancelling frees the slot
  UPDATE appointments SET status = 'cancelled', cancelled_at = now() WHERE id = a;
  PERFORM t_appt('2030-01-10 10:00+00', 45, 5, p_patient => '00000000-0000-0000-0000-0000000000a2');
  RAISE NOTICE 'PASS: cancelled slot can be rebooked';
  -- expiring frees the slot
  UPDATE appointments SET status = 'expired' WHERE id = b;
  PERFORM t_appt('2030-01-10 10:50+00', 45, 5);
  RAISE NOTICE 'PASS: expired hold can be rebooked';
END $$;

-- ---------- 2. appointment integrity ----------
DO $$
DECLARE c1 uuid; c2 uuid; n int;
BEGIN
  c1 := t_appt('2030-02-01 09:00+00', 45, 0, p_status => 'cancelled');
  c2 := t_appt('2030-02-02 09:00+00', 45, 0, p_status => 'confirmed');
  BEGIN UPDATE appointments SET cancelled_at = NULL WHERE id = c1;
        RAISE EXCEPTION 'TEST FAILED: cancelled without cancelled_at accepted';
  EXCEPTION WHEN check_violation THEN RAISE NOTICE 'PASS: cancelled requires cancelled_at'; END;
  BEGIN UPDATE appointments SET confirmed_at = NULL WHERE id = c2;
        RAISE EXCEPTION 'TEST FAILED: confirmed without confirmed_at accepted';
  EXCEPTION WHEN check_violation THEN RAISE NOTICE 'PASS: confirmed requires confirmed_at'; END;
  BEGIN UPDATE appointments SET meet_url = 'https://evil.example.com/abc' WHERE id = c2;
        RAISE EXCEPTION 'TEST FAILED: non-Google-Meet URL accepted';
  EXCEPTION WHEN check_violation THEN RAISE NOTICE 'PASS: meet_url must be a Google Meet link'; END;
  UPDATE appointments SET meet_url = 'https://meet.google.com/abc-defg-hij' WHERE id = c2;
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 1 THEN RAISE EXCEPTION 'TEST FAILED: valid Meet link was not saved'; END IF;
  RAISE NOTICE 'PASS: valid Google Meet link accepted';
  BEGIN INSERT INTO appointments (patient_id, doctor_id, service_id, starts_at, ends_at, blocked_until, price)
        VALUES ('00000000-0000-0000-0000-0000000000a1','00000000-0000-0000-0000-0000000000d1',
                '00000000-0000-0000-0000-0000000000e1','2030-03-01 10:00+00','2030-03-01 09:00+00','2030-03-01 10:00+00',1);
        RAISE EXCEPTION 'TEST FAILED: end before start accepted';
  EXCEPTION WHEN check_violation THEN RAISE NOTICE 'PASS: end must be after start'; END;
  IF (SELECT count(DISTINCT number) FROM appointments) <> (SELECT count(*) FROM appointments) THEN
    RAISE EXCEPTION 'TEST FAILED: booking numbers not unique'; END IF;
  RAISE NOTICE 'PASS: booking numbers unique';
  BEGIN DELETE FROM users WHERE id = '00000000-0000-0000-0000-0000000000a1';
        RAISE EXCEPTION 'TEST FAILED: deleted a patient who has appointments';
  EXCEPTION WHEN foreign_key_violation THEN RAISE NOTICE 'PASS: patient with bookings cannot be deleted'; END;
END $$;

-- ---------- 3. payments and proofs ----------
DO $$
DECLARE appt uuid; pay uuid; p1 uuid;
BEGIN
  appt := t_appt('2030-04-01 09:00+00', 45, 0);
  INSERT INTO payments (appointment_id, amount) VALUES (appt, 300) RETURNING id INTO pay;

  BEGIN INSERT INTO payments (appointment_id, amount) VALUES (appt, 300);
        RAISE EXCEPTION 'TEST FAILED: second payment for same appointment accepted';
  EXCEPTION WHEN unique_violation THEN RAISE NOTICE 'PASS: one payment per appointment'; END;

  BEGIN UPDATE payments SET status = 'rejected' WHERE id = pay;
        RAISE EXCEPTION 'TEST FAILED: rejection without reason accepted';
  EXCEPTION WHEN check_violation THEN RAISE NOTICE 'PASS: payment rejection requires a reason'; END;
  BEGIN UPDATE payments SET status = 'rejected', rejection_reason = '   ' WHERE id = pay;
        RAISE EXCEPTION 'TEST FAILED: blank rejection reason accepted';
  EXCEPTION WHEN check_violation THEN RAISE NOTICE 'PASS: blank rejection reason refused'; END;
  BEGIN UPDATE payments SET status = 'approved' WHERE id = pay;
        RAISE EXCEPTION 'TEST FAILED: approval without reviewer accepted';
  EXCEPTION WHEN check_violation THEN RAISE NOTICE 'PASS: approval requires reviewer'; END;

  INSERT INTO payment_proofs (payment_id, uploaded_by, storage_path, original_name, mime_type, size_bytes, sha256)
  VALUES (pay, '00000000-0000-0000-0000-0000000000a1', 'proofs/aaa.jpg', 'r.jpg', 'image/jpeg', 1000, repeat('a', 64))
  RETURNING id INTO p1;

  BEGIN INSERT INTO payment_proofs (payment_id, storage_path, original_name, mime_type, size_bytes, sha256)
        VALUES (pay, 'proofs/bbb.jpg', 'r2.jpg', 'image/jpeg', 1000, repeat('b', 64));
        RAISE EXCEPTION 'TEST FAILED: two proofs under review for one payment';
  EXCEPTION WHEN unique_violation THEN RAISE NOTICE 'PASS: only one proof under review at a time'; END;

  BEGIN UPDATE payment_proofs SET status = 'rejected' WHERE id = p1;
        RAISE EXCEPTION 'TEST FAILED: proof rejected without reason/reviewer';
  EXCEPTION WHEN check_violation THEN RAISE NOTICE 'PASS: proof rejection needs reason and reviewer'; END;

  -- full rejection then resubmission path
  UPDATE payment_proofs SET status = 'rejected', rejection_reason = 'Receipt unreadable',
         reviewed_by = '00000000-0000-0000-0000-0000000000d1', reviewed_at = now() WHERE id = p1;
  UPDATE payments SET status = 'rejected', rejection_reason = 'Receipt unreadable',
         reviewed_by = '00000000-0000-0000-0000-0000000000d1', reviewed_at = now() WHERE id = pay;
  INSERT INTO payment_proofs (payment_id, storage_path, original_name, mime_type, size_bytes, sha256)
  VALUES (pay, 'proofs/ccc.pdf', 'r3.pdf', 'application/pdf', 2000, repeat('c', 64));
  RAISE NOTICE 'PASS: resubmission after rejection accepted';

  BEGIN INSERT INTO payment_proofs (payment_id, storage_path, original_name, mime_type, size_bytes, sha256, status, reviewed_by, reviewed_at)
        VALUES (pay, 'proofs/exe.exe', 'x.exe', 'application/x-msdownload', 10, repeat('d', 64), 'approved', '00000000-0000-0000-0000-0000000000d1', now());
        RAISE EXCEPTION 'TEST FAILED: executable accepted as proof';
  EXCEPTION WHEN check_violation THEN RAISE NOTICE 'PASS: unsupported file type refused'; END;
  BEGIN INSERT INTO payment_proofs (payment_id, storage_path, original_name, mime_type, size_bytes, sha256, status, reviewed_by, reviewed_at)
        VALUES (pay, 'proofs/big.jpg', 'big.jpg', 'image/jpeg', 20000000, repeat('e', 64), 'approved', '00000000-0000-0000-0000-0000000000d1', now());
        RAISE EXCEPTION 'TEST FAILED: oversized proof accepted';
  EXCEPTION WHEN check_violation THEN RAISE NOTICE 'PASS: oversized file refused'; END;
  BEGIN INSERT INTO payment_proofs (payment_id, disk, storage_path, original_name, mime_type, size_bytes, sha256, status, reviewed_by, reviewed_at)
        VALUES (pay, 'public', 'proofs/pub.jpg', 'pub.jpg', 'image/jpeg', 100, repeat('f', 64), 'approved', '00000000-0000-0000-0000-0000000000d1', now());
        RAISE EXCEPTION 'TEST FAILED: proof on a public disk accepted';
  EXCEPTION WHEN check_violation THEN RAISE NOTICE 'PASS: proofs can only live on the private disk'; END;
END $$;

-- ---------- 4. consent rules ----------
DO $$ BEGIN
  BEGIN INSERT INTO success_stories (display_name, title_ar, story_ar, is_published) VALUES ('M.', 't', 's', true);
        RAISE EXCEPTION 'TEST FAILED: story published without consent';
  EXCEPTION WHEN check_violation THEN RAISE NOTICE 'PASS: story cannot be published without consent'; END;
  BEGIN INSERT INTO success_stories (display_name, title_ar, story_ar, consent_given_at, before_photo_path)
        VALUES ('M.', 't', 's', now(), 'stories/b.jpg');
        RAISE EXCEPTION 'TEST FAILED: photo stored without photo consent';
  EXCEPTION WHEN check_violation THEN RAISE NOTICE 'PASS: photos require explicit photo consent'; END;
  INSERT INTO success_stories (display_name, title_ar, story_ar, consent_given_at, consent_includes_photos, before_photo_path, is_published)
  VALUES ('M.', 't', 's', now(), true, 'stories/b.jpg', true);
  RAISE NOTICE 'PASS: story with full consent can be published';
  BEGIN INSERT INTO patient_profiles (user_id, health_completed_at) VALUES ('00000000-0000-0000-0000-0000000000a2', now());
        RAISE EXCEPTION 'TEST FAILED: health profile completed without consent';
  EXCEPTION WHEN check_violation THEN RAISE NOTICE 'PASS: health profile needs recorded consent'; END;
END $$;

-- ---------- 5. audit log is append-only ----------
DO $$ BEGIN
  INSERT INTO audit_logs (actor_role, event) VALUES ('doctor', 'payment.approved');
  BEGIN UPDATE audit_logs SET event = 'tampered';
        RAISE EXCEPTION 'TEST FAILED: audit row updated';
  EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'PASS: audit UPDATE blocked'; END;
  BEGIN DELETE FROM audit_logs;
        RAISE EXCEPTION 'TEST FAILED: audit row deleted';
  EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'PASS: audit DELETE blocked'; END;
  BEGIN TRUNCATE audit_logs;
        RAISE EXCEPTION 'TEST FAILED: audit table truncated';
  EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'PASS: audit TRUNCATE blocked'; END;
END $$;

-- ---------- 6. accounts ----------
DO $$ BEGIN
  BEGIN INSERT INTO users (name, email, password) VALUES ('Dup', 'A@EXAMPLE.COM', 'x');
        RAISE EXCEPTION 'TEST FAILED: duplicate email (different case) accepted';
  EXCEPTION WHEN unique_violation THEN RAISE NOTICE 'PASS: email unique, case-insensitive'; END;
  BEGIN INSERT INTO users (name, email, password, role) VALUES ('Bad', 'bad@example.com', 'x', 'admin');
        RAISE EXCEPTION 'TEST FAILED: unknown role accepted';
  EXCEPTION WHEN check_violation THEN RAISE NOTICE 'PASS: only patient/doctor roles exist'; END;
END $$;

-- ---------- 7. diet plans, progress, content ----------
DO $$ BEGIN
  BEGIN INSERT INTO diet_plans (patient_id, doctor_id, title, start_date, end_date)
        VALUES ('00000000-0000-0000-0000-0000000000a1','00000000-0000-0000-0000-0000000000d1','P','2030-02-10','2030-02-01');
        RAISE EXCEPTION 'TEST FAILED: plan ending before start accepted';
  EXCEPTION WHEN check_violation THEN RAISE NOTICE 'PASS: plan dates validated'; END;
  BEGIN INSERT INTO diet_plans (patient_id, doctor_id, title, start_date, end_date, status)
        VALUES ('00000000-0000-0000-0000-0000000000a1','00000000-0000-0000-0000-0000000000d1','P','2030-02-01','2030-02-10','published');
        RAISE EXCEPTION 'TEST FAILED: published plan without published_at';
  EXCEPTION WHEN check_violation THEN RAISE NOTICE 'PASS: published plan needs published_at'; END;
  BEGIN INSERT INTO progress_records (patient_id, recorded_on) VALUES ('00000000-0000-0000-0000-0000000000a1', CURRENT_DATE);
        RAISE EXCEPTION 'TEST FAILED: empty measurement record accepted';
  EXCEPTION WHEN check_violation THEN RAISE NOTICE 'PASS: measurement needs at least one value'; END;
  BEGIN INSERT INTO progress_records (patient_id, recorded_on, weight_kg) VALUES ('00000000-0000-0000-0000-0000000000a1', CURRENT_DATE, 5);
        RAISE EXCEPTION 'TEST FAILED: 5 kg weight accepted';
  EXCEPTION WHEN check_violation THEN RAISE NOTICE 'PASS: implausible weight refused'; END;
  INSERT INTO progress_records (patient_id, recorded_on, weight_kg) VALUES ('00000000-0000-0000-0000-0000000000a1', CURRENT_DATE, 82.5);
  BEGIN INSERT INTO progress_records (patient_id, recorded_on, weight_kg) VALUES ('00000000-0000-0000-0000-0000000000a1', CURRENT_DATE, 82.0);
        RAISE EXCEPTION 'TEST FAILED: two records for the same day accepted';
  EXCEPTION WHEN unique_violation THEN RAISE NOTICE 'PASS: one measurement record per day'; END;
  BEGIN INSERT INTO articles (slug, title_ar, body_ar, status) VALUES ('x', 't', 'b', 'published');
        RAISE EXCEPTION 'TEST FAILED: published article without date';
  EXCEPTION WHEN check_violation THEN RAISE NOTICE 'PASS: published article needs a date'; END;
  BEGIN INSERT INTO contact_messages (name, message) VALUES ('N', 'hello');
        RAISE EXCEPTION 'TEST FAILED: contact message with no way to reply';
  EXCEPTION WHEN check_violation THEN RAISE NOTICE 'PASS: contact message needs email or phone'; END;
END $$;

ROLLBACK;
\echo ALL DATABASE TESTS PASSED
