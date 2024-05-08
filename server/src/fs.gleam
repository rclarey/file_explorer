import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import simplifile as sf

import dir_entry
import mimetype
import path

pub fn get_secret_key(fallback: String) {
  case sf.read(".secret_key") {
    Error(sf.Enoent) ->
      sf.write(".secret_key", fallback)
      |> result.replace(fallback)
    x -> x
  }
}

pub fn read_directory(dir_path: String) {
  use <- validate_path(dir_path)
  let res = case sf.read_directory(dir_path) {
    Ok(names) -> Ok(Some(names))
    Error(sf.Enoent) -> Ok(None)
    Error(x) -> Error(x)
  }
  use maybe_names <- result.try(res)
  case maybe_names {
    Some(names) ->
      read_entries(dir_path, names)
      |> result.map(Some)
    None -> Ok(None)
  }
}

pub fn read_file(file_path: String) {
  use <- validate_path(file_path)
  Ok(file_path)
}

fn validate_path(dir_path: String, next: fn() -> Result(a, sf.FileError)) {
  let segments = string.split(dir_path, "/")
  case list.contains(segments, ".") || list.contains(segments, "..") {
    True -> Error(sf.Eacces)
    False -> next()
  }
}

fn read_entries(dir_path: String, names: List(String)) {
  list.map(names, fn(name) {
    let ent_path = path.join(dir_path, name)
    use is_dir <- result.try(sf.verify_is_directory(ent_path))
    use info <- result.try(sf.file_info(ent_path))
    case is_dir {
      True -> {
        use sub_entries <- result.map(sf.read_directory(ent_path))
        dir_entry.new_directory(
          name,
          list.length(sub_entries),
          info.mtime_seconds,
          "",
        )
      }
      False ->
        mimetype.from_file_name(name)
        |> dir_entry.new_file(name, info.size, info.mtime_seconds, _)
        |> Ok()
    }
  })
  |> result.all()
}
