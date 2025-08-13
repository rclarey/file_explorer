const collatorCache = {};
export function do_locale_compare(lang, a, b) {
  const collator = (collatorCache[lang] ??= new Intl.Collator(lang));
  return collator.compare(a, b);
}

const dtCache = {};
export function do_datetime_format(lang, d) {
  const dtf = (dtCache[lang] ??= new Intl.DateTimeFormat(lang, {
    year: 'numeric',
    day: '2-digit',
    month: 'short'
  }));
  return dtf.format(new Date(d));
}

export function read_user_config(on_ok, on_error) {
  const content = document.getElementById("user_config_json")?.textContent;
  if (content) {
    return on_ok(content);
  }
  return on_error(null);
}

export function read_current_uri() {
  return window.location.href;
}

export function open_new_tab(uri) {
  window.open(uri, "_blank")
  return null;
}
