'use client';

import Link from 'next/link';
import { useLocale } from './LocaleProvider';

const CLIENT_LOGO = process.env.NEXT_PUBLIC_CLIENT_LOGO || '';
const DEV_LOGO = process.env.NEXT_PUBLIC_DEV_LOGO || '';

/**
 * Primary brand: EL SHEHAB NUTRITION. Shows the client's official logo when its file is configured
 * (NEXT_PUBLIC_CLIENT_LOGO); until then it shows the brand NAME as plain text. No logo is invented.
 */
export function ClientBrand({ linkHome = true }: { linkHome?: boolean }) {
  const { t, href } = useLocale();
  const inner = CLIENT_LOGO ? (
    // eslint-disable-next-line @next/next/no-img-element
    <img src={CLIENT_LOGO} alt={t('brand.name')} className="h-10 w-auto" />
  ) : (
    <span className="text-lg font-extrabold tracking-wide text-ink">{t('brand.name')}</span>
  );
  return linkHome ? (
    <Link href={href('/')} className="inline-flex items-center" aria-label={t('brand.name')}>
      {inner}
    </Link>
  ) : (
    inner
  );
}

/** Secondary, professional developer credit. Always visually quieter than the client brand. */
export function DeveloperCredit({ className = '' }: { className?: string }) {
  const { t } = useLocale();
  return (
    <p className={`inline-flex items-center gap-2 text-xs text-muted ${className}`}>
      <span>{t('credit.developedBy')}</span>
      {DEV_LOGO ? (
        // eslint-disable-next-line @next/next/no-img-element
        <img src={DEV_LOGO} alt={t('credit.company')} className="h-5 w-auto" />
      ) : (
        <span className="font-semibold text-ink" dir="ltr">
          {t('credit.company')}
        </span>
      )}
    </p>
  );
}
