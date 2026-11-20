'use client';

import Link from 'next/link';
import { useState, type FormEvent } from 'react';
import { api } from '@/lib/api';
import { withLocale } from '@/lib/access';
import { describeApiError } from '@/lib/form-errors';
import { normalizePhone, validateRegister } from '@/lib/validation';
import { Field } from '../Field';
import { useLocale } from '../LocaleProvider';
import { AuthCard, FormMessage } from './AuthCard';

export function RegisterForm() {
  const { t, href, locale } = useLocale();
  const [form, setForm] = useState({
    name: '', email: '', phone: '', password: '', passwordConfirmation: '', acceptedPrivacy: false,
  });
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [formError, setFormError] = useState('');
  const [busy, setBusy] = useState(false);

  const set = (key: keyof typeof form) => (value: string | boolean) => setForm((f) => ({ ...f, [key]: value }));

  async function onSubmit(event: FormEvent) {
    event.preventDefault();
    setFormError('');

    const found = validateRegister(form);
    const local = Object.fromEntries(Object.entries(found).map(([k, v]) => [k, t(`errors.${v}`)]));
    setErrors(local);
    if (Object.keys(local).length) return;

    setBusy(true);
    try {
      await api('POST', '/auth/register', {
        locale,
        body: {
          name: form.name,
          email: form.email,
          phone: normalizePhone(form.phone),
          password: form.password,
          password_confirmation: form.passwordConfirmation,
          accepted_privacy: form.acceptedPrivacy,
          locale,
        },
      });
      // Spec: after registration the patient continues to complete the health profile.
      window.location.assign(withLocale('/patient/dashboard', locale));
    } catch (error) {
      const result = describeApiError(error, t);
      setErrors(result.fields);
      setFormError(result.form);
      setBusy(false);
    }
  }

  return (
    <AuthCard title={t('auth.registerTitle')} subtitle={t('auth.registerSubtitle')}>
      <form onSubmit={onSubmit} noValidate className="space-y-4">
        {formError && <FormMessage kind="error">{formError}</FormMessage>}
        <Field label={t('fields.name')} autoComplete="name" value={form.name}
          onChange={(e) => set('name')(e.target.value)} error={errors.name} />
        <Field label={t('fields.email')} type="email" autoComplete="email" inputMode="email" dir="ltr"
          value={form.email} onChange={(e) => set('email')(e.target.value)} error={errors.email} />
        <Field label={t('fields.phone')} type="tel" autoComplete="tel" inputMode="tel" dir="ltr"
          value={form.phone} onChange={(e) => set('phone')(e.target.value)} error={errors.phone}
          hint={t('fields.phoneHint')} />
        <Field label={t('fields.password')} type="password" autoComplete="new-password" dir="ltr"
          value={form.password} onChange={(e) => set('password')(e.target.value)} error={errors.password}
          hint={t('auth.passwordHint')} />
        <Field label={t('fields.passwordConfirmation')} type="password" autoComplete="new-password" dir="ltr"
          value={form.passwordConfirmation} onChange={(e) => set('passwordConfirmation')(e.target.value)}
          error={errors.passwordConfirmation} />

        <div>
          <label className="flex items-start gap-2 text-sm">
            <input type="checkbox" className="mt-1 h-4 w-4" checked={form.acceptedPrivacy}
              onChange={(e) => set('acceptedPrivacy')(e.target.checked)} aria-invalid={errors.acceptedPrivacy ? true : undefined} />
            <span>
              {t('auth.privacyPrefix')} <strong>{t('auth.privacyLink')}</strong>{' '}
              <span className="text-muted">{t('auth.privacyUnavailable')}</span>
            </span>
          </label>
          {errors.acceptedPrivacy && (
            <p role="alert" className="mt-1 text-xs text-danger">{errors.acceptedPrivacy}</p>
          )}
          <p className="mt-2 text-xs text-muted">{t('auth.healthConsentNote')}</p>
        </div>

        <button type="submit" className="btn-primary w-full" disabled={busy}>
          {busy ? t('auth.registering') : t('auth.registerButton')}
        </button>
        <p className="text-center text-sm text-muted">
          {t('auth.haveAccount')}{' '}
          <Link href={href('/login')} className="font-semibold text-ink underline">
            {t('nav.login')}
          </Link>
        </p>
      </form>
    </AuthCard>
  );
}
