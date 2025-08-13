import gleam/erlang/process
import gleam/http/request
import gleam/http/response
import gleam/result
import mist
import wisp
import wisp/wisp_mist

import context
import fs
import handler

pub fn main() {
  wisp.configure_logger()
  let assert Ok(secret_key) = fs.get_secret_key(wisp.random_string(128))
  let handler = handle_request(_, context.init_context())

  let assert Ok(_) =
    wisp_mist.handler(handler, secret_key)
    |> mist.new
    |> mist.port(8000)
    |> mist.start_http

  process.sleep_forever()
}

fn handle_request(req: wisp.Request, ctx: context.Context) {
  use req <- middleware(req, ctx)

  case wisp.path_segments(req) {
    ["api", "directory"] -> handler.get_directory(req, ctx)
    ["api", "recent"] -> handler.get_recent(req, ctx)
    ["api", "starred"] -> handler.get_starred(req, ctx)
    ["download"] -> handler.get_file(req, ctx)
    _ -> handler.serve_static(req, ctx)
  }
}

fn middleware(
  req: wisp.Request,
  _ctx: context.Context,
  handle_request: fn(wisp.Request) -> wisp.Response,
) {
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes()
  use req <- wisp.handle_head(req)

  let res = handle_request(req)
  let origin = result.unwrap(request.get_header(req, "origin"), "")
  response.set_header(res, "access-control-allow-origin", origin)
}
