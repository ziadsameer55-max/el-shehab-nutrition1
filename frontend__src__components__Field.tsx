'use client';

import { useId, useState, type InputHTMLAttributes } from 'react';
import { useLocale } from './LocaleProvider';

type Props = Omit<InputHTMLAttributes<HTMLInputElement>, 'id'> & {
  label: string;
  error?: string;
  hint?: string;
};

export function Field({ label, error, hint, type = 'text', className = '', ...rest }: Props) {
  const id = useId();
  const { t } = useLocale();
  const [visible, setVisible] = useState(false);
  const isPassword = type === 'password';

  return (
    <div>
      <label htmlFor={id} className="mb-1 block text-sm font-medium">
        {label}
      </label>
      <div className="relative">
        <input
          id={id}
          type={isPassword && visible ? 'text' : type}
          aria-invalid={error ? true : undefined}
          aria-describedby={error ? `${id}-err` : hint ? `${id}-hint` : undefined}
          className={`input ${error ? 'input-error' : ''} ${isPassword ? 'pe-20' : ''} ${className}`}
          {...rest}
        />
        {isPassword && (
          <button
            type="button"
            onClick={() => setVisible((v) => !v)}
            className="absolute inset-y-0 end-0 px-3 text-xs font-medium text-muted hover:text-ink"
            aria-label={visible ? t('common.hidePassword') : t('common.showPassword')}
          >
            {visible ? t('common.hidePassword') : t('common.showPassword')}
          </button>
        )}
      </div>
      {error ? (
        <p id={`${id}-err`} role="alert" className="mt-1 text-xs text-danger">
          {error}
        </p>
      ) : hint ? (
        <p id={`${id}-hint`} className="mt-1 text-xs text-muted">
          {hint}
        </p>
      ) : null}
    </div>
  );
}
