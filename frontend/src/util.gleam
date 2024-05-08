import gleam/option
import gleam/uri.{type Uri}
import plinth/browser/window

pub fn current_uri() {
  let assert Ok(cur_uri) =
    window.location()
    |> uri.parse()
  cur_uri
}

pub fn path_and_query(uri: Uri) {
  uri.path
  <> option.map(uri.query, fn(q) { "?" <> q })
  |> option.unwrap("")
}

pub fn uri_is_current(target: Uri) {
  path_and_query(target) == path_and_query(current_uri())
}
