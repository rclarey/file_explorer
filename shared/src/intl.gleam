import gleam/order.{type Order, Eq, Gt, Lt}

pub fn locale_compare(lang: String, a: String, b: String) {
  case do_locale_compare(lang, a, b) {
    0 -> Eq
    x if x > 0 -> Gt
    _ -> Lt
  }
}

@external(javascript, "./intl_ffi.mjs", "do_locale_compare")
fn do_locale_compare(lang: String, a: String, b: String) -> Int