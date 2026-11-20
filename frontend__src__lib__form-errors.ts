import { ApiError } from './api';

type T = (key: string) => string;

/** Server field names (snake_case) to form field names (camelCase). */
const FIELD_MAP: Record<string, string> = {
  password_confirmation: 'passwordConfirmation',
  accepted_privacy: 'acceptedPrivacy',
};

/**
 * Turns an API failure into { fields, form }: per-field messages from Laravel's validation errors
 * (already in the user's language), plus one general message for everything else.
 */
export function describeApiError(error: unknown, t: T): { fields: Record<string, string>; form: string } {
  if (!(error instanceof ApiError)) return { fields: {}, form: t('common.genericError') };

  if (error.status === 0) return { fields: {}, form: t('common.networkError') };
  if (error.status === 419) return { fields: {}, form: t('common.sessionExpired') };

  if (error.status === 422 || error.status === 429) {
    const fields: Record<string, string> = {};
    for (const [name, messages] of Object.entries(error.fieldErrors)) {
      if (messages[0]) fields[FIELD_MAP[name] ?? name] = messages[0];
    }
    if (error.status === 429 && Object.keys(fields).length === 0) {
      return { fields, form: t('common.tooManyRequests') };
    }
    return { fields, form: '' };
  }

  return { fields: {}, form: t('common.genericError') };
}
