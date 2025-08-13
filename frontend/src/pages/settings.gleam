import lustre/effect
import lustre/element/html.{h1, text}

import global

// MODEL

pub type Model {
  Model
}

pub fn init() {
  #(Model, effect.none())
}

// VIEW
pub fn view(model: Model) {
  h1([], [text("Settings")])
}

// UPDATE

pub type Msg {
  SettingsLoaded
}

pub fn update(global_model: global.Model, model: Model, msg: Msg) {
  #(global_model, model, effect.none())
}
