import { NextResponse, type NextRequest } from 'next/server';
import { guardRedirect, splitLocale } from '@/lib/access';

const SESSION_COOKIE = process.env.SESSION_COOKIE_NAME || 'esn_session';

// 1) Arabic (default) is served unprefixed: rewrite /x to the internal /ar/x route.
// 2) English lives under /en. The internal /ar prefix is never public: /ar/x redirects to /x.
// 3) Protected areas without a session cookie go to login. (UX only; the API enforces real access.)
export function middleware(request: NextRequest) {
  const { pathname, search } = request.nextUrl;

  if (pathname === '/ar' || pathname.startsWith('/ar/')) {
    const url = request.nextUrl.clone();
    url.pathname = pathname.slice(3) || '/';
    return NextResponse.redirect(url, 308);
  }

  const { locale, path } = splitLocale(pathname);

  const redirectTo = guardRedirect({
    path,
    locale,
    hasSession: Boolean(request.cookies.get(SESSION_COOKIE)?.value),
  });
  if (redirectTo) {
    return NextResponse.redirect(new URL(redirectTo, request.url));
  }

  if (locale === 'ar') {
    const url = request.nextUrl.clone();
    url.pathname = `/ar${pathname === '/' ? '' : pathname}`;
    url.search = search;
    return NextResponse.rewrite(url);
  }

  return NextResponse.next();
}

export const config = {
  // skip API proxy, Next internals and static files
  matcher: ['/((?!api|sanctum|_next|brand|.*\\..*).*)'],
};
