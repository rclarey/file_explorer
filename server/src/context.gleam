import gleam/erlang/os

pub type Context {
  Context(env: AppEnv, base_path: String)
}

pub type AppEnv {
  Prod
  Dev
}

pub fn init_context() {
  let env = case os.get_env("APP_ENV") {
    Ok("prod") -> Prod
    _ -> Dev
  }
  Context(env, "/home/russ")
}
