import { test } from 'node:test';
import assert from 'node:assert/strict';
import { isValidEmail, isValidPhone, normalizePhone, passwordError, validateRegister, validateReset } from './validation.ts';

const good = {
  name: 'Test Patient',
  email: 'p@example.com',
  phone: '+201001234567',
  password: 'Secret12345',
  passwordConfirmation: 'Secret12345',
  acceptedPrivacy: true,
};

test('a fully valid registration has no errors', () => {
  assert.deepEqual(validateRegister(good), {});
});

test('each invalid registration field is reported', () => {
  assert.equal(validateRegister({ ...good, name: ' a ' }).name, 'nameRequired');
  assert.equal(validateRegister({ ...good, email: 'nope' }).email, 'emailInvalid');
  assert.equal(validateRegister({ ...good, phone: '12' }).phone, 'phoneInvalid');
  assert.equal(validateRegister({ ...good, acceptedPrivacy: false }).acceptedPrivacy, 'privacyRequired');
  assert.equal(validateRegister({ ...good, passwordConfirmation: 'Other12345' }).passwordConfirmation, 'passwordMismatch');
});

test('password policy matches the backend (min 10, letters and numbers)', () => {
  assert.equal(passwordError(''), 'passwordRequired');
  assert.equal(passwordError('abc123'), 'passwordShort');
  assert.equal(passwordError('abcdefghijkl'), 'passwordWeak');
  assert.equal(passwordError('1234567890123'), 'passwordWeak');
  assert.equal(passwordError('abcdef12345'), null);
  assert.equal(passwordError('كلمةمرور١٢٣٤٥٦'), null); // Arabic letters + Arabic-Indic digits count
});

test('phone normalization mirrors the backend (Arabic-Indic digits, separators)', () => {
  assert.equal(normalizePhone('٠١٠ ٠١٢٣-٤٥٦٧'), '01001234567');
  assert.equal(normalizePhone('+20 (100) 123.4567'), '+201001234567');
  assert.equal(isValidPhone('٠١٠٠١٢٣٤٥٦٧'), true);
  assert.equal(isValidPhone('+1234567'), true);
  assert.equal(isValidPhone('123456'), false);
  assert.equal(isValidPhone('1234567890123456'), false);
  assert.equal(isValidPhone('abc1234567'), false);
});

test('email check', () => {
  assert.equal(isValidEmail('a@b.co'), true);
  assert.equal(isValidEmail(' a@b.co '), true);
  assert.equal(isValidEmail('a@b'), false);
  assert.equal(isValidEmail('a b@c.com'), false);
  assert.equal(isValidEmail(''), false);
});

test('reset form', () => {
  assert.deepEqual(validateReset({ password: 'Secret12345', passwordConfirmation: 'Secret12345' }), {});
  assert.equal(validateReset({ password: 'short', passwordConfirmation: 'short' }).password, 'passwordShort');
  assert.equal(validateReset({ password: 'Secret12345', passwordConfirmation: 'x' }).passwordConfirmation, 'passwordMismatch');
});
