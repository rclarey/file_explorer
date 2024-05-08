import lustre/effect
import lustre/element/html.{h1, text}

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

pub fn update(model: Model, msg: Msg) {
  #(model, effect.none())
}
