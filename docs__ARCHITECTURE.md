# EL SHEHAB NUTRITION — Architecture (Phase 1)

Developed & Powered by CODING Systems.
Source of truth: *Project Specification & Developer Handover* (8 pages). Anything not stated there is marked **[DECISION]** and listed in section 12 for client approval.

---

## 1. Stack (as approved in the spec)

| Layer | Choice | Notes |
|---|---|---|
| Frontend | Next.js 15 (App Router), TypeScript, Tailwind CSS | `next-intl` for AR/EN, `react-hook-form` + `zod` for forms, Recharts for progress charts |
| Backend | Laravel 12 REST API, PHP 8.3 | Sanctum for auth, Policies for authorization, Form Requests for validation |
| Database | PostgreSQL 16 | UUID primary keys, CHECK constraints, exclusion constraint for double-booking |
| Files | Laravel `private` disk | Payment proofs and health files are never publicly reachable; streamed through authorized endpoints |
| PDF | mPDF (`mpdf/mpdf`) | **[DECISION]** chosen because it shapes Arabic and RTL correctly; DomPDF handles Arabic poorly |
| Queue / scheduler | Laravel queue (database driver) + `schedule:run` | Expiring holds, sending notifications. Redis can replace the driver later with no code change |
| Meetings | Google Meet link pasted manually by the doctor | No Google API integration (spec) |

## 2. Repository layout

```
el-shehab-nutrition/
├── backend/            Laravel 12 API
│   ├── app/{Models,Http/{Controllers,Requests,Resources,Middleware},Policies,Services,Enums,Jobs,Notifications}
│   ├── database/{migrations,sql,seeders,factories}
│   ├── routes/api.php
│   └── tests/{Feature,Unit}
├── frontend/           Next.js 15
│   ├── src/app/[locale]/(public|auth|patient|doctor)/...
│   ├── src/{components,lib,messages/{ar,en}.json}
│   └── e2e/            Playwright tests
├── deploy/             Docker Compose, nginx, backup scripts (Phase 9)
├── docs/               This file, API reference, QA matrix, runbook
└── tests/db/           SQL-level schema verification (runs against real PostgreSQL)
```

## 3. Request flow and authentication

- The browser only talks to **Next.js**. Next.js proxies `/api/*` to Laravel (`rewrites`), so everything is same-origin: no CORS, and the Sanctum session cookie is `HttpOnly`, `Secure`, `SameSite=Lax`. No token is ever stored in `localStorage`.
- Sanctum SPA (cookie) mode with CSRF cookie. Login/logout/register/forgot/reset endpoints are under `/api/auth/*`, rate limited.
- Next.js middleware redirects unauthenticated users to `/login` and wrong-role users to their own area. **This is a UX convenience only.** Every API request is authorized again on the server (spec §7.2).

## 4. Roles and authorization

Roles (stored in `users.role`): `patient`, `doctor`.

| Rule | Enforcement |
|---|---|
| Patient reads/writes only their own records | Laravel Policies on every model + query scoping (`where patient_id = auth()->id()`), never trusting IDs from the URL |
| Doctor sees only their own patients | `patient_profiles.primary_doctor_id` or an appointment/plan link; checked in the Policy |
| Google Meet link visible only to the patient of a `confirmed` appointment | `AppointmentResource` omits `meet_url` unless status is `confirmed` and viewer is that patient or the doctor |
| Payment proofs / health files | Streamed by a controller after a Policy check; stored with random names on the private disk |
| Role changes, payment decisions, plan edits, cancellations | Written to `audit_logs` (append-only, enforced by a database trigger) |

Because the spec's "test that patient A cannot open patient B by changing the ID" is a release gate, every resource endpoint gets a Feature test for it. UUID keys make IDs hard to guess but are **not** treated as a security control.

## 5. Booking and payment state machine

Appointment status (`appointments.status`):

```
pending_payment ──(payment approved)──▶ confirmed ──▶ completed
      │                                     │──────▶ no_show
      │                                     └──────▶ cancelled
      ├──(hold expires, job)──▶ expired
      └──(patient/doctor cancels)──▶ cancelled
```

Payment status (`payments.status`): `awaiting_proof → under_review → approved | rejected`, and `rejected → under_review` again on resubmission. `refunded` is reserved for a manual refund note (policy pending).

Proof status (`payment_proofs.status`): `under_review → approved | rejected`. Each resubmission creates a **new** proof row; old rejected proofs stay as history.

Rules enforced:

1. **No double booking.** PostgreSQL exclusion constraint on `(doctor_id, tstzrange(starts_at, blocked_until))` for every status except `cancelled`/`expired`. Application checks give friendly errors; the constraint is the guarantee under concurrent requests. A violation maps to the spec's "slot taken, choose another time" response.
2. **Not confirmed until payment approved.** Confirmation happens in one DB transaction together with the payment approval and audit log.
3. **Rejection requires a reason** (CHECK constraint + Form Request), is visible to the patient, and is audited.
4. **Rejection never deletes the booking.** It keeps the slot for a grace period (`rejected_hold_minutes` setting), then the scheduled job marks it `expired` and the slot is free again. While a proof is `under_review` the hold does not expire.
5. **Hold timer.** A new booking holds the slot for `booking_hold_minutes` waiting for a proof.
6. All times are stored as UTC `timestamptz`; the clinic timezone (`Africa/Cairo`, which observes DST) is a setting used to generate slots and render dates.

Slot generation = weekly `working_hours` − `time_off` − existing active appointments, using each service's `duration_minutes` plus `buffer_minutes`. If no working hours are configured, booking is reported as "not available" rather than showing invented slots.

## 6. Data model

Tables (all PKs are UUID unless noted):

```
users ─┬─ doctor_profiles
       ├─ patient_profiles ── (health fields, consent timestamps)
       ├─ patient_files               (lab results etc., private)
       ├─ appointments ─┬─ payments ── payment_proofs
       │                └─ (service_id, package_id)
       ├─ diet_plans ── diet_meals ── meal_items
       ├─ progress_records
       └─ notifications (Laravel standard)
services, packages, payment_methods, faqs, articles, success_stories,
contact_messages, working_hours, time_off, settings, audit_logs (bigint PK)
+ Laravel infrastructure: sessions, cache, jobs, failed_jobs, password_reset_tokens
```

The spec's 10 core table groups are all present; additions (`working_hours`, `time_off`, `payment_methods`, `contact_messages`, `patient_files`, `settings`) are required by features the spec lists (doctor-defined hours, bank/wallet details shown to patients, the `/contact` form, health files, configurable policies).

Key design points:

- **Bilingual content** uses `_ar` / `_en` columns (`_ar` required, `_en` optional with Arabic fallback). Patient-specific text (diet plans, notes) is stored once as written by the doctor.
- **Health data** (`medical_conditions`, `allergies`, `medications`) is encrypted at the application layer (Eloquent `encrypted` cast). Consequence: those fields cannot be searched; patient search uses name, phone and email only, which matches the spec.
- **Success stories** cannot be published without a recorded consent timestamp, and photos require explicit photo consent (CHECK constraints).
- **Audit log** is append-only: a trigger rejects UPDATE, DELETE and TRUNCATE. It has no foreign key to `users` so deleting a user can never alter history.
- **No sensitive payment data** is stored: only the clinic's receiving details and the patient's transfer receipt image/PDF with a reference number.

Full DDL: `backend/database/sql/*.up.sql` (run by the Laravel migrations).

## 7. Internationalisation

- Locales: `ar` (default, RTL) and `en` (LTR). Spec URLs stay unprefixed for Arabic (`/booking`) and English uses a prefix (`/en/booking`) via `next-intl` `localePrefix: 'as-needed'`.
- `dir` and `lang` set on `<html>`; Tailwind logical utilities (`ms-*`, `ps-*`, `text-start`) so layouts mirror without duplicate CSS.
- API returns raw bilingual fields; the frontend picks by locale. Validation messages and notification text are localised by `users.locale` / `Accept-Language`.
- Fonts: an Arabic-capable family (e.g. Cairo/Tajawal) plus a Latin family; PDF uses an embedded Arabic font.

## 8. Branding

- Client brand (EL SHEHAB NUTRITION) leads: header, hero, colors, patient and doctor shells.
- "Developed & Powered by CODING Systems" appears, visually secondary, in the footer, login/register pages, both dashboards and generated documents (PDF footer), per spec page 1.
- **Both logo files and brand colors are needed from the client/CODING Systems** (see section 12). Until supplied, Phase 2 uses a clearly named text wordmark slot, not an invented logo.

## 9. Security checklist (mandatory per spec)

Authorization on every request; hashed passwords (bcrypt/argon2); HTTPS + HSTS; secure cookies; CSRF; login/reset/contact/upload rate limiting; upload validation by extension, real MIME and size (JPG/PNG/WebP/PDF, 5 MB default), random server-side filenames, SHA-256 stored; private storage with no public URL; strict security headers (CSP, `X-Content-Type-Options`, frame denial); input validation via Form Requests; Eloquent/query bindings only; generic login errors (no account enumeration on reset); audit log for sensitive actions; privacy policy and explicit health-data consent captured with a timestamp and version; daily encrypted database backup with a documented, tested restore.

## 10. Testing strategy

| Level | Tooling | Covers |
|---|---|---|
| Database | `tests/db/verify_schema.sql` on real PostgreSQL | Constraints, overlap prevention, consent rules, audit immutability |
| Backend | PHPUnit/Pest Feature tests on PostgreSQL | Every endpoint, policies, state machine, cross-patient access |
| Frontend | Vitest/RTL + Playwright | Every button/route in the spec, AR/EN, RTL, mobile viewport |
| Acceptance | The spec's page-7 checklist, one automated scenario each | Release gate |

## 11. Delivery phases

Each phase ships backend + frontend for its slice, with tests passing before the next begins.

| # | Phase | Output |
|---|---|---|
| 1 | Architecture and database | This document, migrations, seeders, verified schema |
| 2 | Foundation | Laravel and Next.js scaffolds, auth (register, login, reset), roles, policies, audit service, i18n/RTL shell, brand layout |
| 3 | Public site and content | Home, doctor, services, packages, articles, success stories, FAQ, contact; doctor CRUD for content |
| 4 | Patient profile and health data | Profile, health form, consent, health file uploads |
| 5 | Booking | Working hours, slot engine, booking flow, conflict handling, cancellation |
| 6 | Payments | Proof upload, doctor review, approve/reject/resubmit, Meet link, notifications |
| 7 | Diet plans | Doctor builder, draft/publish/edit/archive, patient view, PDF |
| 8 | Progress and dashboards | Measurements, charts, doctor stats, in-app notifications |
| 9 | Hardening and delivery | Security review, full acceptance run, Docker deploy, backups, user and developer docs |

## 12. Client decisions

### Approved (Phase 2 go-ahead)

- **Packages** are bundles of sessions; services and packages are both bookable. The doctor manages package details, session count, price, validity and usage.
- **`/doctor/messages`** is added so the doctor can read and manage contact-form messages.
- **Patient health files** (lab results, documents) are allowed: private storage, patient sees only their own, the doctor can access them.
- **Branding**: the client's and CODING Systems' original logos will be supplied; no logo or brand color is invented. EL SHEHAB NUTRITION is primary; CODING Systems gets professional developer credit throughout.
- **Provisional policies** (60-minute hold, 12-hour rejected-receipt grace, 24-hour cancellation window) stay configurable and are NOT final business policies.
- **Business policies** (services, prices, hours, cancellation/refund, notification channels, payment details) are never hard-coded; configurable and pending confirmation.

### Still open

The spec itself says these must be approved before development. Phase 1 stores them as configurable data, so none blocks the schema, but Phases 3 to 6 need answers:

1. **Services, packages, prices, session durations** (entered by the doctor in the dashboard; no fake data is seeded).
2. **Working hours, buffer between sessions, provisional-hold length.** Provisional defaults seeded: hold 60 min, post-rejection grace 12 h, buffer 0.
3. **Payment methods** to show patients (bank, wallet, InstaPay) and their details.
4. **Cancellation, refund, lateness and no-show policy.**
5. **Notifications:** email only, or WhatsApp too? (WhatsApp needs a Business API provider and cost.)
6. **Extra reports or print exports** beyond diet-plan PDF.
7. **How packages are used.** The spec lists packages but the booking flow only says "choose a service". Proposed: a package has a number of sessions and the booking flow lets a patient book with a package; confirm.
8. **Contact messages.** The `/contact` form needs somewhere for the doctor to read messages. Proposed addition: `/doctor/messages` (not in the spec's page list).
9. **Health files.** The spec mentions private health files; proposed: patients upload lab results on `/patient/health`, visible to their doctor.
10. **Logos and brand colors** for both EL SHEHAB NUTRITION and CODING Systems, plus the privacy-policy and terms text.
11. **Hosting target** (VPS, domain, mail provider) for the deployment phase.
