#!/usr/bin/env bash
# EL SHEHAB NUTRITION: Developed & Powered by CODING Systems
# Runs every Phase 2 verification step in order and prints a PASS / FAIL / SKIPPED summary.
# It never reports a step as passed unless the command actually succeeded.
#
# Prerequisites (see docs/SETUP.md): PostgreSQL running with databases el_shehab and el_shehab_test,
# backend/.env and frontend/.env.local configured, and these exported:
#   PGHOST PGUSER PGPASSWORD            (for the schema tests; needs CREATEDB)
#   DB_USERNAME DB_PASSWORD             (for the Laravel tests, database el_shehab_test)
#   E2E_DOCTOR_EMAIL E2E_DOCTOR_PASSWORD   (must match DOCTOR_EMAIL / DOCTOR_PASSWORD used for seeding)
# backend/.env must have MAIL_MAILER=log and SANCTUM_STATEFUL_DOMAINS=localhost:3000
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RESULTS=()
BACKEND_PID=""; FRONTEND_PID=""

record() { RESULTS+=("$1|$2"); printf '\n==> %s: %s\n' "$2" "$1"; }
step() { # step "name" command...
  local name="$1"; shift
  printf '\n--- %s ---\n' "$name"
  if "$@"; then record "$name" PASS; return 0; else record "$name" FAIL; return 1; fi
}
skip() { record "$1" "SKIPPED ($2)"; }
cleanup() { [ -n "$BACKEND_PID" ] && kill "$BACKEND_PID" 2>/dev/null; [ -n "$FRONTEND_PID" ] && kill "$FRONTEND_PID" 2>/dev/null; }
trap cleanup EXIT

wait_for() { for _ in $(seq 1 60); do curl -fsS -o /dev/null "$1" 2>/dev/null && return 0; sleep 1; done; return 1; }

step "1. Database schema tests (PostgreSQL)"            "$ROOT/tests/db/run.sh"

cd "$ROOT/backend"
step "2. Backend: composer install"                     composer install --no-interaction --prefer-dist
step "3. Backend: Laravel feature tests"                env DB_DATABASE=el_shehab_test php artisan test

cd "$ROOT/frontend"
step "4. Frontend: npm install"                         npm install --no-audit --no-fund
step "5. Frontend: i18n key parity"                     npm run check:i18n
step "6. Frontend: unit tests"                          npm test
step "7. Frontend: TypeScript check"                    npm run typecheck
step "8. Frontend: production build (next build)"       npm run build

if [ "${RESULTS[*]}" = "${RESULTS[*]/FAIL/}" ] && [ -n "${E2E_DOCTOR_EMAIL:-}" ] && [ -n "${E2E_DOCTOR_PASSWORD:-}" ]; then
  cd "$ROOT/backend"
  step "9. Backend: migrate + seed (development database)" bash -c "php artisan migrate --force && DOCTOR_EMAIL='$E2E_DOCTOR_EMAIL' DOCTOR_PASSWORD='$E2E_DOCTOR_PASSWORD' php artisan db:seed --force"
  php artisan serve --host=127.0.0.1 --port=8000 >/tmp/esn-backend.log 2>&1 & BACKEND_PID=$!
  cd "$ROOT/frontend"
  npm run start -- -p 3000 >/tmp/esn-frontend.log 2>&1 & FRONTEND_PID=$!
  if wait_for http://127.0.0.1:8000/up && wait_for http://localhost:3000/; then
    step "10. Browser: install Chromium"                npx playwright install chromium
    step "11. Browser: CSRF/cookies, auth flows, roles, reset, RTL/LTR, mobile (Playwright)" \
      env E2E_BASE_URL=http://localhost:3000 E2E_BACKEND_LOG="$ROOT/backend/storage/logs/laravel.log" npx playwright test
  else
    record "10-11. Browser tests" "FAIL (servers did not start; see /tmp/esn-backend.log and /tmp/esn-frontend.log)"
  fi
else
  skip "9-11. Migrate, run stack, browser tests" "an earlier step failed, or E2E_DOCTOR_EMAIL / E2E_DOCTOR_PASSWORD not set"
fi

printf '\n\n================ PHASE 2 VERIFICATION SUMMARY ================\n'
FAILS=0
for r in "${RESULTS[@]}"; do printf '%-72s %s\n' "${r%%|*}" "${r##*|}"; case "${r##*|}" in PASS) ;; *) FAILS=$((FAILS+1));; esac; done
printf '==============================================================\n'
[ "$FAILS" -eq 0 ] && echo "ALL CHECKS PASSED" || echo "$FAILS check(s) did not pass: Phase 2 is NOT verified"
exit "$FAILS"
