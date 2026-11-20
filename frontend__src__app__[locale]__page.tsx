import Link from 'next/link';
import { withLocale, type Locale } from '@/lib/access';
import { getMessages } from '@/lib/i18n';

// Foundation home page. The full marketing site (services, packages, articles, ...) is Phase 3 and
// is built from database content; nothing is hard-coded here beyond the system's own labels.
export default async function HomePage({ params }: { params: Promise<{ locale: Locale }> }) {
  const { locale } = await params;
  const m = getMessages(locale);

  return (
    <section className="mx-auto max-w-3xl px-4 py-16 text-center">
      <h1 className="text-3xl font-extrabold">{m.brand.name}</h1>
      <p className="mt-2 text-muted">{m.brand.tagline}</p>
      <p className="mx-auto mt-6 max-w-xl">{m.home.intro}</p>
      <div className="mt-8 flex flex-wrap justify-center gap-3">
        <Link href={withLocale('/register', locale)} className="btn-primary">{m.nav.register}</Link>
        <Link href={withLocale('/login', locale)} className="btn-secondary">{m.nav.login}</Link>
      </div>
    </section>
  );
}
