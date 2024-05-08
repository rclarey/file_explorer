import gleam/io
import gleam/option
import gleam/result
import gleam/uri.{type Uri}
import lustre
import lustre/effect.{type Effect}
import lustre/element
import lustre/element/html.{div, h1, li, p, text, ul}
import my_modem

import dir_entry.{type DirEntry}
import pages/directory
import pages/settings
import util

// MODEL

pub type Model {
  Directory(directory.Model)
  Settings(settings.Model)
  NotFound
}

pub type Flags {
  Flags(uri: Uri)
}

fn init(flags: Flags) {
  let #(init_model, init_effect) = init_for_route(flags.uri)
  #(init_model, effect.batch([init_effect, my_modem.init(on_route_change)]))
}

fn init_for_route(uri: Uri) {
  case uri.path {
    "/" -> {
      directory.init(uri)
      |> update_with(Directory, DirectoryMsg)
    }
    "/recent" ->
      directory.init_recent()
      |> update_with(Directory, DirectoryMsg)
    "/starred" ->
      directory.init_starred()
      |> update_with(Directory, DirectoryMsg)
    "/settings" -> {
      settings.init()
      |> update_with(Settings, SettingsMsg)
    }
    _ -> #(NotFound, effect.none())
  }
}

fn on_route_change(uri: Uri) {
  let #(msg_model, msg_effect) = init_for_route(uri)
  RouteUpdated(msg_model, msg_effect)
}

// VIEW

fn view(model: Model) {
  case model {
    Directory(model) ->
      directory.view(model)
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
  case model, msg {
    Directory(model), DirectoryMsg(msg) ->
      directory.update(model, msg)
      |> update_with(Directory, DirectoryMsg)
    Settings(model), SettingsMsg(msg) ->
      settings.update(model, msg)
      |> update_with(Settings, SettingsMsg)
    _, RouteUpdated(msg_model, msg_effect) -> #(msg_model, msg_effect)
    _, _ -> #(model, effect.none())
  }
}

fn update_with(
  result: #(sub_model, Effect(sub_msg)),
  to_model: fn(sub_model) -> Model,
  to_msg: fn(sub_msg) -> Msg,
) {
  #(to_model(result.0), effect.map(result.1, to_msg))
}

// MAIN

pub fn main() {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Flags(util.current_uri()))
}
