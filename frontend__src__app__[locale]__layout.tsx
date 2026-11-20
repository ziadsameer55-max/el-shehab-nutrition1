import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { type ReactNode } from 'react';
import '../globals.css';
import { Footer } from '@/components/Footer';
import { Header } from '@/components/Header';
import { LocaleProvider } from '@/components/LocaleProvider';
import { LOCALES, type Locale } from '@/lib/access';
import { dirOf, getMessages } from '@/lib/i18n';
import { getCurrentUser } from '@/lib/server-auth';

export async function generateMetadata({ params }: { params: Promise<{ locale: string }> }): Promise<Metadata> {
  const { locale } = await params;
  const messages = getMessages(locale === 'en' ? 'en' : 'ar');
  return {
    title: { default: messages.brand.name, template: `%s | ${messages.brand.name}` },
    description: messages.brand.tagline,
    robots: { index: false }, // flip when the public site goes live (Phase 3+)
  };
}

export default async function LocaleLayout({
  children,
  params,
}: {
  children: ReactNode;
  params: Promise<{ locale: string }>;
}) {
  const { locale: raw } = await params;
  if (!(LOCALES as readonly string[]).includes(raw)) notFound();
  const locale = raw as Locale;

  const user = await getCurrentUser();

  return (
    <html lang={locale} dir={dirOf(locale)}>
      <body className="flex min-h-screen flex-col">
        <LocaleProvider locale={locale} messages={getMessages(locale)}>
          <Header role={user?.role} />
          <main className="flex-1">{children}</main>
          <Footer />
        </LocaleProvider>
      </body>
    </html>
  );
}
