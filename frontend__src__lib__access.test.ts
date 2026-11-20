import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  areaOf,
  guardRedirect,
  homeFor,
  resolvePostLoginPath,
  roleMayView,
  safeNextPath,
  splitLocale,
  withLocale,
} from './access.ts';

test('splitLocale: Arabic is unprefixed, English uses /en', () => {
  assert.deepEqual(splitLocale('/'), { locale: 'ar', path: '/' });
  assert.deepEqual(splitLocale('/booking'), { locale: 'ar', path: '/booking' });
  assert.deepEqual(splitLocale('/en'), { locale: 'en', path: '/' });
  assert.deepEqual(splitLocale('/en/patient/dashboard'), { locale: 'en', path: '/patient/dashboard' });
  // a path that merely starts with the letters "en" is not the English prefix
  assert.deepEqual(splitLocale('/entries'), { locale: 'ar', path: '/entries' });
});

test('withLocale round-trips with splitLocale', () => {
  for (const path of ['/', '/login', '/patient/dashboard']) {
    for (const locale of ['ar', 'en'] as const) {
      assert.deepEqual(splitLocale(withLocale(path, locale)), { locale, path });
    }
  }
});

test('areaOf: /doctor is public, /doctor/* is the dashboard', () => {
  assert.equal(areaOf('/'), 'public');
  assert.equal(areaOf('/doctor'), 'public');
  assert.equal(areaOf('/doctor/'), 'public');
  assert.equal(areaOf('/doctor/dashboard'), 'doctor');
  assert.equal(areaOf('/doctor/patients/123'), 'doctor');
  assert.equal(areaOf('/patient'), 'patient');
  assert.equal(areaOf('/patient/appointments/abc'), 'patient');
  assert.equal(areaOf('/patients-info'), 'public');
  assert.equal(areaOf('/login'), 'public');
});

test('every spec route lands in the right area', () => {
  const patient = ['dashboard', 'profile', 'health', 'appointments', 'appointments/1', 'payments', 'diet-plans', 'diet-plans/1', 'progress', 'notifications'];
  const doctor = ['dashboard', 'patients', 'patients/1', 'appointments', 'payments', 'diet-plans', 'services', 'packages', 'articles', 'settings', 'messages'];
  const pub = ['/', '/doctor', '/services', '/packages', '/articles', '/success-stories', '/faq', '/contact', '/login', '/register', '/booking', '/forgot-password', '/reset-password'];
  for (const p of patient) assert.equal(areaOf(`/patient/${p}`), 'patient', p);
  for (const p of doctor) assert.equal(areaOf(`/doctor/${p}`), 'doctor', p);
  for (const p of pub) assert.equal(areaOf(p), 'public', p);
});

test('roleMayView: patients and doctors stay in their own area', () => {
  assert.equal(roleMayView('patient', 'patient'), true);
  assert.equal(roleMayView('patient', 'doctor'), false);
  assert.equal(roleMayView('doctor', 'patient'), false);
  assert.equal(roleMayView('doctor', 'doctor'), true);
  assert.equal(roleMayView('patient', 'public'), true);
});

test('homeFor', () => {
  assert.equal(homeFor('patient'), '/patient/dashboard');
  assert.equal(homeFor('doctor'), '/doctor/dashboard');
});

test('guardRedirect: protected areas without a session go to login with a return path', () => {
  assert.equal(guardRedirect({ path: '/patient/dashboard', locale: 'ar', hasSession: false }), '/login?next=%2Fpatient%2Fdashboard');
  assert.equal(guardRedirect({ path: '/doctor/payments', locale: 'en', hasSession: false }), '/en/login?next=%2Fdoctor%2Fpayments');
  assert.equal(guardRedirect({ path: '/patient/dashboard', locale: 'ar', hasSession: true }), null);
  assert.equal(guardRedirect({ path: '/doctor', locale: 'ar', hasSession: false }), null);
  assert.equal(guardRedirect({ path: '/booking', locale: 'en', hasSession: false }), null);
});

test('safeNextPath blocks open redirects', () => {
  const fb = '/patient/dashboard';
  for (const bad of [
    '//evil.com', 'https://evil.com', 'http://evil.com/x', '/\\evil.com', '\\\\evil.com', 'javascript:alert(1)',
    'evil.com', '', null, undefined, '/ok\nSet-Cookie: x=1', '/a://b', '/' + 'a'.repeat(600),
  ]) {
    assert.equal(safeNextPath(bad as string | null | undefined, fb), fb, `should reject ${JSON.stringify(bad)}`);
  }
  assert.equal(safeNextPath('/patient/appointments/5?x=1', fb), '/patient/appointments/5?x=1');
});

test('resolvePostLoginPath never sends a user into the other role\'s area', () => {
  assert.equal(resolvePostLoginPath(null, 'patient'), '/patient/dashboard');
  assert.equal(resolvePostLoginPath(null, 'doctor'), '/doctor/dashboard');
  assert.equal(resolvePostLoginPath('/patient/payments', 'patient'), '/patient/payments');
  assert.equal(resolvePostLoginPath('/doctor/payments', 'patient'), '/patient/dashboard');
  assert.equal(resolvePostLoginPath('/patient/payments', 'doctor'), '/doctor/dashboard');
  assert.equal(resolvePostLoginPath('/booking', 'patient'), '/booking');
  assert.equal(resolvePostLoginPath('//evil.com', 'doctor'), '/doctor/dashboard');
});
