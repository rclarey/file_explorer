import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/json
import gleam/string

pub type Kind {
  File
  Directory
}

pub type DirEntry {
  DirEntry(
    kind: Kind,
    id: String,
    name: String,
    size: Int,
    mtime: Int,
    mimetype: String,
  )
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
    #(
      "kind",
      json.string(case entry.kind {
        File -> "file"
        Directory -> "directory"
      }),
    ),
    #("id", json.string(entry.id)),
    #("name", json.string(entry.name)),
    #("size", json.int(entry.size)),
    #("mtime", json.int(entry.mtime)),
    #("mimetype", json.string(entry.mimetype)),
  ])
}

pub fn decoder() {
  let decode_kind =
    decode.new_primitive_decoder("Kind", fn(data) {
      case decode.run(data, decode.string) {
        Ok("file") -> Ok(File)
        Ok("directory") -> Ok(Directory)
        _ -> Error(File)
      }
    })
  use kind <- decode.field("kind", decode_kind)
  use id <- decode.field("id", decode.string)
  use name <- decode.field("name", decode.string)
  use size <- decode.field("size", decode.int)
  use mtime <- decode.field("mtime", decode.int)
  use mimetype <- decode.field("mimetype", decode.string)
  decode.success(DirEntry(kind, id, name, size, mtime, mimetype))
}

pub fn format_size(entry: DirEntry) {
  case entry.kind {
    Directory -> dir_size(entry.size)
    File -> file_size(entry.size)
  }
}

fn dir_size(size: Int) {
  case size {
    1 -> "1 item"
    x -> int.to_string(x) <> " items"
  }
}

fn file_size(size: Int) {
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
