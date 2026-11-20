import { redirect } from 'next/navigation';
import { type ReactNode } from 'react';
import { homeFor, withLocale, type Locale } from '@/lib/access';
import { getCurrentUser } from '@/lib/server-auth';

// Server-side guard for the whole patient portal. Real data access is still enforced by the API.
export default async function PatientLayout({
  children,
  params,
}: {
  children: ReactNode;
  params: Promise<{ locale: Locale }>;
}) {
  const { locale } = await params;
  const user = await getCurrentUser();

  if (!user) redirect(withLocale('/login', locale));
  if (user.role !== 'patient') redirect(withLocale(homeFor(user.role), locale));

  return <div className="mx-auto w-full max-w-6xl px-4 py-8">{children}</div>;
}
