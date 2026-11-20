import ar from '@/messages/ar.json';
import en from '@/messages/en.json';
import { type Locale } from './access';

export type Messages = typeof ar;

const dictionaries: Record<Locale, Messages> = { ar, en };

export function getMessages(locale: Locale): Messages {
  return dictionaries[locale];
}

export function dirOf(locale: Locale): 'rtl' | 'ltr' {
  return locale === 'ar' ? 'rtl' : 'ltr';
}

/** Looks up "section.key" and fills {placeholders}. Returns the key itself if missing (visible in QA). */
export function translate(messages: Messages, key: string, vars?: Record<string, string>): string {
  const found = key.split('.').reduce<unknown>((node, part) => {
    return node && typeof node === 'object' ? (node as Record<string, unknown>)[part] : undefined;
  }, messages);

  if (typeof found !== 'string') return key;
  return vars ? found.replace(/\{(\w+)\}/g, (_, name: string) => vars[name] ?? `{${name}}`) : found;
}
