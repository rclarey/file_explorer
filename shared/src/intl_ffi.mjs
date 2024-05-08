const cache = {};
export function do_locale_compare(lang, a, b) {
  const collator = (cache[lang] ??= new Intl.Collator(lang));
  return collator.compare(a, b);
}