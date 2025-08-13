import lustre/effect

import shared/config.{type UserConfig}

pub type Model {
  Model(config: UserConfig)
}

pub type GlobalMsg(msg) {
  GlobalMsg(Msg)
  PageMsg(msg)
}

pub type Msg {}

pub fn update(model:Model, msg: Msg) {
  #(model, effect.none())
}
