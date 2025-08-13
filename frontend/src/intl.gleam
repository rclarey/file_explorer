import gleam/order.{Eq, Gt, Lt}

pub fn locale_compare(lang: String, a: String, b: String) {
  case do_locale_compare(lang, a, b) {
    0 -> Eq
    x if x > 0 -> Gt
    _ -> Lt
  }
}

@external(javascript, "./ffi.mjs", "do_locale_compare")
fn do_locale_compare(lang: String, a: String, b: String) -> Int

@external(javascript, "./ffi.mjs", "do_datetime_format")
pub fn datetime_format(lang: String, dt: Int) -> String
