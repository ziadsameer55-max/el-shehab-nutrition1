'use client';

import Link from 'next/link';
import { Suspense } from 'react';
import { ClientBrand } from './Brand';
import { LocaleSwitcher } from './LocaleSwitcher';
import { LogoutButton } from './LogoutButton';
import { useLocale } from './LocaleProvider';
import { homeFor, type Role } from '@/lib/access';

export function Header({ role }: { role?: Role }) {
  const { t, href } = useLocale();

  return (
    <header className="border-b border-line bg-surface">
      <div className="mx-auto flex max-w-6xl flex-wrap items-center justify-between gap-3 px-4 py-3">
        <ClientBrand />
        <nav className="flex flex-wrap items-center gap-2" aria-label={t('nav.menu')}>
          {role ? (
            <>
              <Link href={href(homeFor(role))} className="btn-secondary min-h-9 px-3">
                {t('nav.dashboard')}
              </Link>
              <LogoutButton />
            </>
          ) : (
            <>
              <Link href={href('/login')} className="btn-secondary min-h-9 px-3">
                {t('nav.login')}
              </Link>
              <Link href={href('/register')} className="btn-primary min-h-9 px-3">
                {t('nav.register')}
              </Link>
            </>
          )}
          <Suspense fallback={null}>
            <LocaleSwitcher />
          </Suspense>
        </nav>
      </div>
    </header>
  );
}
