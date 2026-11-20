'use client';

import Link from 'next/link';
import { useState, type FormEvent } from 'react';
import { api } from '@/lib/api';
import { withLocale } from '@/lib/access';
import { describeApiError } from '@/lib/form-errors';
import { validateReset } from '@/lib/validation';
import { Field } from '../Field';
import { useLocale } from '../LocaleProvider';
import { AuthCard, FormMessage } from './AuthCard';

export function ResetPasswordForm({ token, email }: { token?: string; email?: string }) {
  const { t, href, locale } = useLocale();
  const [password, setPassword] = useState('');
  const [confirmation, setConfirmation] = useState('');
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [formError, setFormError] = useState('');
  const [busy, setBusy] = useState(false);

  if (!token || !email) {
    return (
      <AuthCard title={t('auth.resetTitle')}>
        <div className="space-y-4">
          <FormMessage kind="error">{t('auth.resetMissing')}</FormMessage>
          <Link href={href('/forgot-password')} className="btn-primary w-full">{t('auth.requestNewLink')}</Link>
        </div>
      </AuthCard>
    );
  }

  async function onSubmit(event: FormEvent) {
    event.preventDefault();
    setFormError('');

    const found = validateReset({ password, passwordConfirmation: confirmation });
    const local = Object.fromEntries(Object.entries(found).map(([k, v]) => [k, t(`errors.${v}`)]));
    setErrors(local);
    if (Object.keys(local).length) return;

    setBusy(true);
    try {
      await api('POST', '/auth/reset-password', {
        locale,
        body: { token, email, password, password_confirmation: confirmation },
      });
      window.location.assign(`${withLocale('/login', locale)}?reset=1`);
    } catch (e) {
      const result = describeApiError(e, t);
      // The API reports a bad/expired token under "email"; show it as a general message.
      setFormError(result.fields.email ?? result.form);
      setErrors({ password: result.fields.password ?? '', passwordConfirmation: result.fields.passwordConfirmation ?? '' });
      setBusy(false);
    }
  }

  return (
    <AuthCard title={t('auth.resetTitle')} subtitle={t('auth.resetSubtitle')}>
      <form onSubmit={onSubmit} noValidate className="space-y-4">
        {formError && <FormMessage kind="error">{formError}</FormMessage>}
        <Field label={t('fields.password')} type="password" autoComplete="new-password" dir="ltr"
          value={password} onChange={(e) => setPassword(e.target.value)} error={errors.password}
          hint={t('auth.passwordHint')} />
        <Field label={t('fields.passwordConfirmation')} type="password" autoComplete="new-password" dir="ltr"
          value={confirmation} onChange={(e) => setConfirmation(e.target.value)} error={errors.passwordConfirmation} />
        <button type="submit" className="btn-primary w-full" disabled={busy}>
          {busy ? t('auth.saving') : t('auth.resetButton')}
        </button>
        <p className="text-center text-sm">
          <Link href={href('/forgot-password')} className="underline">{t('auth.requestNewLink')}</Link>
        </p>
      </form>
    </AuthCard>
  );
}
