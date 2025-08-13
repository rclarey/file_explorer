import gleam/int
import gleam/json
import gleam/option
import gleam/order
import gleam/result
import gleam/uri.{type Uri}

import intl
import shared/config
import shared/dir_entry.{type DirEntry, Directory, File}

pub fn read_user_config() {
  {
    use json_text <- result.try(do_read_user_config(Ok, Error))
    json.parse(json_text, config.user_config_decoder())
    |> result.replace_error(Nil)
  }
  |> result.unwrap(config.default())
}

@external(javascript, "./ffi.mjs", "read_user_config")
fn do_read_user_config(
  on_ok: fn(String) -> Result(String, Nil),
  on_error: fn(Nil) -> Result(String, Nil),
) -> Result(String, Nil)

pub fn current_uri() {
  let assert Ok(cur_uri) =
    read_current_uri()
    |> uri.parse()
  cur_uri
}

@external(javascript, "./ffi.mjs", "read_current_uri")
fn read_current_uri() -> String

pub fn path_and_query(uri: Uri) {
  uri.path
  <> option.map(uri.query, fn(q) { "?" <> q })
  |> option.unwrap("")
}

pub fn uri_is_current(target: Uri) {
  path_and_query(target) == path_and_query(current_uri())
}

@external(javascript, "./ffi.mjs", "open_new_tab")
pub fn open_new_tab(uri: String) -> Nil

pub fn compare_name(a: DirEntry, b: DirEntry) {
  compare_kind(a, b)
  |> order.break_tie(case a.name, b.name {
    "." <> _, "." <> _ -> intl.locale_compare("en", a.name, b.name)
    "." <> _, _ -> order.Gt
    _, "." <> _ -> order.Lt
    _, _ -> intl.locale_compare("en", a.name, b.name)
  })
}

pub fn compare_size(a: DirEntry, b: DirEntry) {
  compare_kind(a, b)
  |> order.break_tie(int.compare(a.size, b.size))
}

pub fn compare_mtime(a: DirEntry, b: DirEntry) {
  compare_kind(a, b)
  |> order.break_tie(int.compare(a.mtime, b.mtime))
}

// directories before files
fn compare_kind(a: DirEntry, b: DirEntry) {
  case a.kind, b.kind {
    Directory, File -> order.Lt
    File, Directory -> order.Gt
    _, _ -> order.Eq
  }
}
