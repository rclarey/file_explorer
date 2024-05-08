import gleam/dynamic
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/set.{type Set}
import gleam/string
import gleam/uri.{type Uri}
import lustre/attribute.{attribute, class, classes, href}
import lustre/effect
import lustre/element.{type Element}
import lustre/element/html.{
  a, div, h1, input, li, main, nav, search, span, text, ul,
}
import lustre/event.{on_click}
import lustre_http
import my_modem
import plinth/browser/window

import dir_entry.{type DirEntry}
import icon
import path
import status.{type Status}
import util

// MODEL

pub type Model {
  Model(content: Content, entries: Status(List(DirEntry)), selected: Selection)
}

pub type Selection {
  Selection(active: Set(String), rest: Set(String))
}

pub type Content {
  Directory(dir_path: String)
  Recent
  Starred
}

pub fn init(cur_uri: Uri) {
  let p_val =
    option.unwrap(cur_uri.query, "")
    |> uri.parse_query()
    |> result.unwrap([])
    |> list.key_find("p")
    |> result.unwrap("")

  case p_val {
    "" -> {
      let assert Ok(default_uri) = uri.parse("/?p=/")
      #(
        Model(Directory("/"), status.Loading, new_selection()),
        effect.batch([get_directory("/"), my_modem.replace(default_uri)]),
      )
    }
    p_val -> #(
      Model(Directory(p_val), status.Loading, new_selection()),
      get_directory(p_val),
    )
  }
}

pub fn init_recent() {
  #(Model(Recent, status.Loading, new_selection()), get_recent())
}

pub fn init_starred() {
  #(Model(Starred, status.Loading, new_selection()), get_starred())
}

fn new_selection() {
  Selection(set.new(), set.new())
}

fn one_selection(id: String) {
  Selection(
    set.new()
      |> set.insert(id),
    set.new(),
  )
}

// VIEW

pub fn view(model: Model) {
  let content = case model.entries {
    status.Loading -> view_loading()
    status.Failed(e) -> view_error(e)
    status.Loaded(entries) ->
      case model.content {
        Directory(dir_path) -> view_directory(dir_path, entries, model.selected)
        Recent -> view_recent(entries)
        Starred -> view_starred(entries)
      }
  }

  view_layout(model, nav_content: [view_quick_links(model)], main_content: [
    view_top_nav(model),
    content,
  ])
}

fn view_layout(
  model: Model,
  nav_content nav_content: List(Element(msg)),
  main_content main_content: List(Element(msg)),
) {
  main([], [
    view_left_nav(model, nav_content),
    div([class("content")], main_content),
  ])
}

fn view_left_nav(_model: Model, content: List(Element(msg))) {
  nav([class("left-nav")], [
    h1([], [text("Files")]),
    div([class("left-nav-content")], content),
  ])
}

fn view_quick_links(_model: Model) {
  let cur_href =
    util.current_uri()
    |> util.path_and_query()
  let links = [
    #(icon.clock(), "Recent", "/recent"),
    #(icon.star(), "Starred", "/starred"),
    #(icon.house(), "Home", "/?p=/"),
    #(icon.film(), "Movies", "/?p=/Movies"),
    #(icon.tv(), "Shows", "/?p=/Shows"),
    #(icon.download(), "Downloads", "/?p=/Downloads"),
  ]
  ul(
    [class("quick-links")],
    list.map(links, fn(link) {
      li([], [
        a(
          [
            class("quick-link"),
            class("btn"),
            classes([#("btn-active", cur_href == link.2)]),
            href(link.2),
          ],
          [link.0, text(link.1)],
        ),
      ])
    }),
  )
}

fn view_top_nav(model: Model) {
  nav([class("top-nav")], [
    div([], [view_back_button(model)]),
    search([], [input([])]),
  ])
}

fn view_back_button(model: Model) {
  let disabled =
    span([class("btn"), class("btn-disabled")], [icon.left_chevron()])
  case model.content {
    Directory("/") -> disabled
    Directory("") -> disabled
    Directory(dir_path) -> {
      let p = path.parent_directory(dir_path)
      a([class("btn"), href("/?p=" <> p), attribute("title", "Back")], [
        icon.left_chevron(),
      ])
    }
    _ -> disabled
  }
}

fn view_loading() {
  ul([class("dir-list")], [])
}

fn view_error(e: lustre_http.HttpError) {
  h1([], [text("Failed! " <> string.inspect(e))])
}

fn view_directory(
  base_path: String,
  entries: List(DirEntry),
  selected: Selection,
) {
  div(
    [class("dir-list"), on_click(SelectionCleared)],
    list.map(entries, fn(entry) {
      let ent_path = path.join(base_path, entry.name)
      let is_selected =
        set.contains(selected.active, entry.id)
        || set.contains(selected.rest, entry.id)
      view_dir_entry_row(entry, ent_path, is_selected)
    }),
  )
}

fn view_recent(_entries: List(DirEntry)) {
  text("Recent")
}

fn view_starred(_entries: List(DirEntry)) {
  text("Starred")
}

fn view_dir_entry_row(entry: DirEntry, ent_path: String, is_selected: Bool) {
  let #(row_icon, open_msg) = case entry.kind {
    dir_entry.File -> #(icon.for_mimetype(entry.mimetype), FileOpened(ent_path))
    dir_entry.Directory -> #(icon.folder(), DirOpened(ent_path))
  }
  a(
    [
      class("dir-list-item"),
      classes([#("dir-list-item-selected", is_selected)]),
      on_click_mod(EntrySelected(entry.id, _)),
      event.on("dblclick", fn(_) { Ok(open_msg) }),
    ],
    [row_icon, no_mouse_text(entry.name)],
  )
}

fn no_mouse_text(str: String) {
  span([class("no-mouse")], [text(str)])
}

fn on_click_mod(cb: fn(ModKey) -> msg) {
  event.on("click", fn(e) {
    event.stop_propagation(e)
    event.prevent_default(e)
    let #(ctrl, meta, shift) =
      e
      |> dynamic.decode3(
        fn(ctrl, meta, shift) { #(ctrl, meta, shift) },
        dynamic.field("ctrlKey", dynamic.bool),
        dynamic.field("metaKey", dynamic.bool),
        dynamic.field("shiftKey", dynamic.bool),
      )
      |> result.unwrap(#(False, False, False))
    case ctrl || meta, shift {
      True, True -> CtrlShift
      True, False -> Ctrl
      False, True -> Shift
      False, False -> NoMod
    }
    |> cb()
    |> Ok()
  })
}

// UPDATE

pub type Msg {
  DirOpened(dir_path: String)
  DirLoaded(Result(List(DirEntry), lustre_http.HttpError))
  RecentOpened
  RecentLoaded(Result(List(DirEntry), lustre_http.HttpError))
  StarredOpened
  StarredLoaded(Result(List(DirEntry), lustre_http.HttpError))
  EntrySelected(id: String, mod: ModKey)
  SelectionCleared
  FileOpened(file_path: String)
}

pub type ModKey {
  CtrlShift
  Ctrl
  Shift
  NoMod
}

pub fn update(model: Model, msg: Msg) {
  case model.content, msg {
    _, DirOpened(dir_path) -> {
      let assert Ok(target_uri) = uri.parse("/?p=" <> dir_path)
      let msg_effect = case util.uri_is_current(target_uri) {
        True -> get_directory(dir_path)
        False ->
          effect.batch([get_directory(dir_path), my_modem.push(target_uri)])
      }
      #(Model(Directory(dir_path), status.Loading, new_selection()), msg_effect)
    }
    Directory(dir_path), DirLoaded(res) -> #(
      loaded_model(model, Directory(dir_path), res),
      effect.none(),
    )
    _, RecentOpened -> #(
      Model(Recent, status.Loading, new_selection()),
      get_recent(),
    )
    Recent, RecentLoaded(res) -> #(
      loaded_model(model, Recent, res),
      effect.none(),
    )
    _, StarredOpened -> #(
      Model(Starred, status.Loading, new_selection()),
      get_starred(),
    )
    Starred, StarredLoaded(res) -> #(
      loaded_model(model, Starred, res),
      effect.none(),
    )
    _, EntrySelected(id, mod) -> #(add_selection(model, id, mod), effect.none())
    _, SelectionCleared -> #(
      Model(..model, selected: new_selection()),
      effect.none(),
    )
    _, FileOpened(file_path) -> {
      let cur = util.current_uri()
      uri.Uri(..cur, path: "/download", query: Some("p=" <> file_path))
      |> uri.to_string()
      |> window.open("_blank", "")
      #(model, effect.none())
    }
    _, _ -> #(model, effect.none())
  }
}

fn loaded_model(
  model: Model,
  content: Content,
  res: Result(List(DirEntry), lustre_http.HttpError),
) {
  let entries = case res {
    Ok(entries) ->
      list.sort(entries, dir_entry.compare_name)
      |> status.Loaded
    Error(e) -> status.Failed(e)
  }
  Model(content, entries, model.selected)
}

fn add_selection(model: Model, id: String, mod: ModKey) {
  use entries <- status.map_loaded(model.entries, model)
  let active = model.selected.active
  case mod {
    NoMod -> Model(..model, selected: one_selection(id))
    Ctrl ->
      Model(
        ..model,
        selected: Selection(
          set.new()
            |> set.insert(id),
          set.union(model.selected.active, model.selected.rest),
        ),
      )
    Shift -> {
      let new_active =
        select_ids_in_range(entries, active, id, list.first, set.new())
      Model(..model, selected: Selection(new_active, set.new()))
    }
    CtrlShift -> {
      let new_active =
        select_ids_in_range(entries, active, id, list.last, active)
      Model(..model, selected: Selection(new_active, model.selected.rest))
    }
  }
}

fn select_ids_in_range(
  entries: List(DirEntry),
  active: Set(String),
  from_id: String,
  get_to: fn(List(String)) -> Result(String, Nil),
  init_set: Set(String),
) {
  let to =
    set.to_list(active)
    |> get_to()
  {
    use to_id <- result.map(to)
    entry_ids_in_range(entries, from_id, to_id)
    |> list.fold(init_set, set.insert)
  }
  |> result.unwrap(
    set.new()
    |> set.insert(from_id),
  )
}

fn entry_ids_in_range(entries: List(DirEntry), from_id: String, to_id: String) {
  let #(ind_a, ind_b) =
    list.index_fold(entries, #(0, 0), fn(res, entry, ind) {
      case entry.id {
        x if x == from_id -> #(ind, res.1)
        x if x == to_id -> #(res.0, ind)
        _ -> res
      }
    })
  let #(start, end) = #(int.min(ind_a, ind_b), int.max(ind_a, ind_b))
  entries
  |> list.drop(start)
  |> list.take(end - start + 1)
  |> list.map(fn(entry) { entry.id })
}

fn get_directory(path: String) {
  let cur = util.current_uri()
  uri.Uri(..cur, path: "/api/directory", query: Some("p=" <> path))
  |> uri.to_string()
  |> lustre_http.get(lustre_http.expect_json(
    dynamic.list(dir_entry.from_dynamic),
    DirLoaded,
  ))
}

fn get_recent() {
  let cur = util.current_uri()
  uri.Uri(..cur, path: "/api/recent", query: None)
  |> uri.to_string()
  |> lustre_http.get(lustre_http.expect_json(
    dynamic.list(dir_entry.from_dynamic),
    RecentLoaded,
  ))
}

fn get_starred() {
  let cur = util.current_uri()
  uri.Uri(..cur, path: "/api/starred", query: None)
  |> uri.to_string()
  |> lustre_http.get(lustre_http.expect_json(
    dynamic.list(dir_entry.from_dynamic),
    StarredLoaded,
  ))
}
