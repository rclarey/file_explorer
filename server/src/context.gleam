import envoy
import gleam/erlang


pub type Context {
  Context(static_dir: String, fs_base_dir: String)
}

pub type AppEnv {
  Prod
  Dev
}

pub fn init_context() {
  let env = case envoy.get("APP_ENV") {
    Ok("prod") -> Prod
    _ -> Dev
  }
  Context(get_static_dir(), "/home/russ")
}

fn get_static_dir() {
  let assert Ok(priv_directory) = erlang.priv_directory("server")
  priv_directory <> "/static"
}
