import gleam/http
import gleam/http/request
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import simplifile as sf
import wisp.{type Request, type Response}

import context.{type Context}
import dir_entry
import fs
import path

fn require_param(req: Request, key: String, next: fn(String) -> Response) {
  request.get_query(req)
  |> result.unwrap([])
  |> list.key_find(key)
  |> result.map(fn(val) { next(val) })
  |> result.replace_error(wisp.bad_request())
  |> result.unwrap_both()
}

pub fn get_directory(req: Request, ctx: Context) {
  use <- wisp.require_method(req, http.Get)
  use p_val <- require_param(req, "p")
  let dir_path = path.join(ctx.base_path, p_val)
  case fs.read_directory(dir_path) {
    Ok(Some(res)) -> {
      json.array(res, dir_entry.to_json)
      |> json.to_string_builder()
      |> wisp.json_response(200)
    }
    Ok(None) -> {
      json.object([#("not_found", json.bool(True))])
      |> json.to_string_builder()
      |> wisp.json_response(404)
    }
    Error(e) -> error_response(e)
  }
}

pub fn get_recent(req: Request, _ctx: Context) {
  use <- wisp.require_method(req, http.Get)
  wisp.internal_server_error()
}

pub fn get_starred(req: Request, _ctx: Context) {
  use <- wisp.require_method(req, http.Get)
  wisp.internal_server_error()
}

pub fn get_file(req: Request, ctx: Context) {
  use <- wisp.require_method(req, http.Get)
  use p_val <- require_param(req, "p")
  let file_path = path.join(ctx.base_path, p_val)
  case fs.read_file(file_path) {
    Ok(file_path) ->
      wisp.ok()
      |> wisp.set_body(wisp.File(file_path))
    Error(e) -> error_response(e)
  }
}

pub fn serve_static(_req: Request, _ctx: Context) {
  wisp.internal_server_error()
}

fn error_response(err: sf.FileError) {
  case err {
    sf.Eacces
    | sf.Eexist
    | sf.Efbig
    | sf.Eisdir
    | sf.Eloop
    | sf.Enametoolong
    | sf.Enotdir -> wisp.bad_request()
    sf.Enoent -> wisp.not_found()
    _ -> wisp.internal_server_error()
  }
}
