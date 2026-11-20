// Client-side form checks. They give instant feedback only; Laravel re-validates everything.
// Keys returned are message keys under "errors.*" in the i18n files.

export type FieldErrors<K extends string> = Partial<Record<K, string>>;

const ARABIC_INDIC = '٠١٢٣٤٥٦٧٨٩';

/** Mirrors the backend: converts Arabic-Indic digits, strips spaces, dashes, dots and brackets. */
export function normalizePhone(input: string): string {
  const digits = input.replace(/[٠-٩]/g, (d) => String(ARABIC_INDIC.indexOf(d)));
  return digits.replace(/[\s\-().]/g, '');
}

export function isValidPhone(input: string): boolean {
  return /^\+?[0-9]{7,15}$/.test(normalizePhone(input));
}

export function isValidEmail(input: string): boolean {
  const v = input.trim();
  return v.length <= 255 && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v);
}

/** Returns an error key, or null when the password meets the policy (min 10, letters and numbers). */
export function passwordError(password: string): 'passwordRequired' | 'passwordShort' | 'passwordWeak' | null {
  if (password.length === 0) return 'passwordRequired';
  if (password.length < 10) return 'passwordShort';
  if (!/\p{L}/u.test(password) || !/\p{N}/u.test(password)) return 'passwordWeak';
  return null;
}

export type RegisterInput = {
  name: string;
  email: string;
  phone: string;
  password: string;
  passwordConfirmation: string;
  acceptedPrivacy: boolean;
};

export type RegisterField = 'name' | 'email' | 'phone' | 'password' | 'passwordConfirmation' | 'acceptedPrivacy';

export function validateRegister(v: RegisterInput): FieldErrors<RegisterField> {
  const e: FieldErrors<RegisterField> = {};
  if (v.name.trim().length < 2) e.name = 'nameRequired';
  if (!isValidEmail(v.email)) e.email = 'emailInvalid';
  if (!isValidPhone(v.phone)) e.phone = 'phoneInvalid';
  const pw = passwordError(v.password);
  if (pw) e.password = pw;
  else if (v.password !== v.passwordConfirmation) e.passwordConfirmation = 'passwordMismatch';
  if (!v.acceptedPrivacy) e.acceptedPrivacy = 'privacyRequired';
  return e;
}

export type ResetInput = { password: string; passwordConfirmation: string };

export function validateReset(v: ResetInput): FieldErrors<'password' | 'passwordConfirmation'> {
  const e: FieldErrors<'password' | 'passwordConfirmation'> = {};
  const pw = passwordError(v.password);
  if (pw) e.password = pw;
  else if (v.password !== v.passwordConfirmation) e.passwordConfirmation = 'passwordMismatch';
  return e;
}
