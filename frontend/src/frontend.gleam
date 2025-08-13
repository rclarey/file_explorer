import gleam/uri.{type Uri}
import lustre
import lustre/effect.{type Effect}
import lustre/element
import lustre/element/html.{h1, text}
import modem

import global
import pages/directory
import pages/settings
import shared/config.{type UserConfig}
import util

// MODEL

pub type Model {
  Model(global_model: global.Model, page_model: PageModel)
}

pub type PageModel {
  Directory(directory.Model)
  Settings(settings.Model)
  NotFound
}

pub type Flags {
  Flags(user_config: UserConfig, uri: Uri)
}

fn init(flags: Flags) {
  let #(init_model, init_effect) = init_for_route(flags)
  #(init_model, effect.batch([init_effect, modem.init(on_route_change(flags))]))
}

fn init_for_route(flags: Flags) {
  let Flags(user_config:, uri:) = flags
  let global_model = global.Model(user_config)
  case uri.path {
    "/" -> {
      directory.init(user_config, uri)
      |> init_with(global_model, Directory, DirectoryMsg)
    }
    "/recent" ->
      directory.init_recent(user_config)
      |> init_with(global_model, Directory, DirectoryMsg)
    "/starred" ->
      directory.init_starred(user_config)
      |> init_with(global_model, Directory, DirectoryMsg)
    "/settings" -> {
      settings.init()
      |> init_with(global_model, Settings, SettingsMsg)
    }
    _ -> #(Model(global_model:, page_model: NotFound), effect.none())
  }
}

fn init_with(
  result: #(sub_model, Effect(sub_msg)),
  global_model: global.Model,
  to_model: fn(sub_model) -> PageModel,
  to_msg: fn(sub_msg) -> Msg,
) {
  update_with(#(global_model, result.0, result.1), to_model, to_msg)
}

fn on_route_change(flags: Flags) {
  fn(uri: Uri) {
    let #(msg_model, msg_effect) = init_for_route(Flags(..flags, uri: uri))
    RouteUpdated(msg_model, msg_effect)
  }
}

// VIEW

fn view(model: Model) {
  case model.page_model {
    Directory(page_model) ->
      directory.view(page_model)
      |> element.map(DirectoryMsg)
    Settings(_model) -> h1([], [text("Settings")])
    NotFound -> h1([], [text("Not Found!")])
  }
}

// UPDATE

pub type Msg {
  RouteUpdated(Model, Effect(Msg))
  DirectoryMsg(directory.Msg)
  SettingsMsg(settings.Msg)
}

fn update(model: Model, msg: Msg) {
  let Model(global_model:, page_model:)= model
  case page_model, msg {
    Directory(model), DirectoryMsg(msg) ->
      directory.update(global_model, model, msg)
      |> update_with(Directory, DirectoryMsg)
    Settings(model), SettingsMsg(msg) ->
      settings.update(global_model, model, msg)
      |> update_with(Settings, SettingsMsg)
    _, RouteUpdated(msg_model, msg_effect) -> #(msg_model, msg_effect)
    _, _ -> #(model, effect.none())
  }
}

fn update_with(
  result: #(global.Model, sub_model, Effect(sub_msg)),
  to_model: fn(sub_model) -> PageModel,
  to_msg: fn(sub_msg) -> Msg,
) {
  let #(global_model, page_model, page_msg) = result
  #(Model(global_model:, page_model: to_model(page_model)), effect.map(page_msg, to_msg))
}

// MAIN

pub fn main() {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Flags(util.read_user_config(), util.current_uri()))
}
