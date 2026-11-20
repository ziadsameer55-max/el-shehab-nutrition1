'use client';

import { DeveloperCredit } from './Brand';
import { useLocale } from './LocaleProvider';

export function Footer() {
  const { t } = useLocale();
  return (
    <footer className="mt-auto border-t border-line bg-surface">
      <div className="mx-auto flex max-w-6xl flex-col items-center justify-between gap-2 px-4 py-4 text-center sm:flex-row sm:text-start">
        <p className="text-xs text-muted">
          © {new Date().getFullYear()} {t('brand.name')}
        </p>
        <DeveloperCredit />
      </div>
    </footer>
  );
}
