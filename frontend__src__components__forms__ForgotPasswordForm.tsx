'use client';

import Link from 'next/link';
import { useState, type FormEvent } from 'react';
import { api } from '@/lib/api';
import { describeApiError } from '@/lib/form-errors';
import { isValidEmail } from '@/lib/validation';
import { Field } from '../Field';
import { useLocale } from '../LocaleProvider';
import { AuthCard, FormMessage } from './AuthCard';

export function ForgotPasswordForm() {
  const { t, href, locale } = useLocale();
  const [email, setEmail] = useState('');
  const [error, setError] = useState('');
  const [formError, setFormError] = useState('');
  const [sentMessage, setSentMessage] = useState('');
  const [busy, setBusy] = useState(false);

  async function onSubmit(event: FormEvent) {
    event.preventDefault();
    setFormError('');
    setSentMessage('');

    if (!isValidEmail(email)) {
      setError(t('errors.emailInvalid'));
      return;
    }
    setError('');

    setBusy(true);
    try {
      const result = await api<{ message: string }>('POST', '/auth/forgot-password', { body: { email }, locale });
      setSentMessage(result.message);
    } catch (e) {
      const { fields, form } = describeApiError(e, t);
      setError(fields.email ?? '');
      setFormError(form);
    } finally {
      setBusy(false);
    }
  }

  return (
    <AuthCard title={t('auth.forgotTitle')} subtitle={t('auth.forgotSubtitle')}>
      <form onSubmit={onSubmit} noValidate className="space-y-4">
        {sentMessage && <FormMessage kind="success">{sentMessage}</FormMessage>}
        {formError && <FormMessage kind="error">{formError}</FormMessage>}
        <Field label={t('fields.email')} type="email" autoComplete="email" inputMode="email" dir="ltr"
          value={email} onChange={(e) => setEmail(e.target.value)} error={error} />
        <button type="submit" className="btn-primary w-full" disabled={busy}>
          {busy ? t('auth.sending') : t('auth.forgotButton')}
        </button>
        <p className="text-center text-sm">
          <Link href={href('/login')} className="underline">{t('auth.backToLogin')}</Link>
        </p>
      </form>
    </AuthCard>
  );
}
