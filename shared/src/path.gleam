import gleam/string
import gleam/uri

pub fn join(left: String, right: String) -> String {
  case left, right {
    _, "/" -> left
    "", _ -> relative(right)
    "/", _ -> "/" <> relative(right)
    _, _ ->
      remove_trailing_slash(left)
      |> string.append("/")
      |> string.append(relative(right))
  }
  |> remove_trailing_slash()
}

fn relative(path: String) -> String {
  case path {
    "/" <> path -> relative(path)
    _ -> path
  }
}

fn remove_trailing_slash(path: String) -> String {
  case string.ends_with(path, "/") {
    True -> string.drop_right(path, 1)
    False -> path
  }
}

pub fn parent_directory(path: String) -> String {
  uri.path_segments(path)
  |> drop_last_item()
  |> string.join("/")
  |> string.append("/", _)
}

fn drop_last_item(list: List(item)) -> List(item) {
  case list {
    [] | [_] -> []
    [x, ..xs] -> [x, ..drop_last_item(xs)]
  }
}
