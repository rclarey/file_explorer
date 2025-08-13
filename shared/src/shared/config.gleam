import gleam/dynamic/decode
import gleam/json

pub type UserConfig {
  UserConfig(quick_links: List(QuickLink))
}

pub type QuickLink {
  QuickLink(icon: QuickLinkIcon, label: String, path: String)
}

pub type QuickLinkIcon {
  Clock
  Download
  Film
  House
  Star
  Tv
}

pub fn quick_link_decoder() {
  use icon <- decode.field("icon", quick_link_icon_decoder())
  use label <- decode.field("label", decode.string)
  use path <- decode.field("path", decode.string)
  decode.success(QuickLink(icon:, label:, path:))
}

pub fn quick_link_to_json(quick_link: QuickLink) {
  json.object([
    #("icon", quick_link_icon_to_json(quick_link.icon)),
    #("label", json.string(quick_link.label)),
    #("path", json.string(quick_link.path)),
  ])
}

pub fn quick_link_icon_decoder() {
  decode.new_primitive_decoder("QuickLinkIcon", fn(data) {
    case decode.run(data, decode.string) {
      Ok("clock") -> Ok(Clock)
      Ok("download") -> Ok(Download)
      Ok("film") -> Ok(Film)
      Ok("house") -> Ok(House)
      Ok("star") -> Ok(Star)
      Ok("tv") -> Ok(Tv)
      _ -> Error(House)
    }
  })
}

pub fn quick_link_icon_to_json(icon: QuickLinkIcon) {
  json.string(case icon {
    Clock -> "clock"
    Download -> "download"
    Film -> "film"
    House -> "house"
    Star -> "star"
    Tv -> "tv"
  })
}

pub fn default() {
  UserConfig(quick_links: [])
}

pub fn user_config_decoder() {
  use quick_links <- decode.field(
    "quick_links",
    decode.list(quick_link_decoder()),
  )
  decode.success(UserConfig(quick_links:))
}

pub fn user_config_to_json(config: UserConfig) {
  json.object([
    #("quick_links", json.array(config.quick_links, quick_link_to_json)),
  ])
}
