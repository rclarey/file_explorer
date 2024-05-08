import gleam/bit_array
import gleam/dynamic.{type Dynamic}
import gleam/float
import gleam/int
import gleam/json
import gleam/order
import gleam/string

import intl

pub type Kind {
  File
  Directory
}

pub type DirEntry {
  DirEntry(kind: Kind, id: String, name: String, size: Int, mtime: Int, mimetype: String)
}

pub fn new_file(name: String, size: Int, mtime: Int, mimetype: String) {
  #(File, name, size, mtime)
  |> string.inspect()
  |> DirEntry(File, _, name, size, mtime, mimetype)
}

pub fn new_directory(name: String, size: Int, mtime: Int, mimetype: String) {
  #(Directory, name, size, mtime)
  |> string.inspect()
  |> DirEntry(Directory, _, name, size, mtime, mimetype)
}

pub fn to_json(entry: DirEntry) {
  json.object([
    #("kind", json.string(case entry.kind {
      File -> "file"
      Directory -> "directory"
    })),
    #("id", json.string(entry.id)),
    #("name", json.string(entry.name)),
    #("size", json.int(entry.size)),
    #("mtime", json.int(entry.mtime)),
    #("mimetype", json.string(entry.mimetype)),
  ])
}

pub fn from_dynamic(entry: Dynamic) {
  let decode =
    dynamic.decode6(
      fn(a, b, c, d, e, f) { #(a, b, c, d, e, f) },
      dynamic.field("kind", dynamic.string),
      dynamic.field("id", dynamic.string),
      dynamic.field("name", dynamic.string),
      dynamic.field("size", dynamic.int),
      dynamic.field("mtime", dynamic.int),
      dynamic.field("mimetype", dynamic.string),
    )
  case decode(entry) {
    Ok(#("file", id, name, size, mtime, mimetype)) ->
      Ok(new_file(name, size, mtime, mimetype))
    Ok(#("directory", id, name, size, mtime, mimetype)) ->
      Ok(new_directory(name, size, mtime, mimetype))
    Ok(#(found, _, _, _, _, _)) ->
      Error([dynamic.DecodeError("\"file\" or \"directory\"", found, ["type"])])
    Error(x) -> Error(x)
  }
}

pub fn file_size(size: Int) {
  case size {
    x if x < 1024 -> int.to_string(x) <> " B"
    x if x < 1_048_576 -> two_digits(int.to_float(x) /. 1024.0) <> " KB"
    x if x < 1_073_741_824 ->
      two_digits(int.to_float(x) /. 1_048_576.0) <> " MB"
    x -> two_digits(int.to_float(x) /. 1_073_741_824.0) <> " GB"
  }
}

fn two_digits(n: Float) {
  let int_part =
    float.truncate(n)
    |> int.to_string()
  let dec_part = {
    n
    |> float.subtract(float.floor(n))
    |> float.multiply(100.0)
    |> float.truncate()
    |> int.to_string()
  }
  int_part <> "." <> dec_part
}

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
