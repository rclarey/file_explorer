import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/set.{type Set}
import gleam/string
import gleam/uri.{type Uri}
import lustre/attribute.{type Attribute, attribute, class, classes, href}
import lustre/effect
import lustre/element.{type Element}
import lustre/element/html.{
  a, button, col, colgroup, div, h1, input, li, main, nav, search, span, table,
  tbody, td, text, th, thead, tr, ul,
}
import lustre/event.{on_click}
import modem
import rsvp

import global
import icon
import intl
import shared/config.{type QuickLink, type UserConfig, UserConfig}
import shared/dir_entry.{type DirEntry}
import shared/path
import status.{type Status}
import util

// MODEL

pub type Model {
  Model(
    quick_links: List(QuickLink),
    content: Content,
    entries: Status(List(DirEntry)),
    selected: Selection,
    sort: Sort,
  )
}

pub type Selection {
  Selection(active: Set(String), rest: Set(String))
}

pub type Sort {
  Sort(on: Field, direction: Direction)
}

pub type Field {
  Name
  Size
  Modified
}

pub type Direction {
  Up
  Down
}

pub type Content {
  Directory(dir_path: String)
  Recent
  Starred
}

pub fn init(user_config: UserConfig, cur_uri: Uri) {
  let UserConfig(quick_links:) = user_config
  let p_val =
    option.unwrap(cur_uri.query, "")
    |> uri.parse_query()
    |> result.unwrap([])
    |> list.key_find("p")
    |> result.unwrap("")

  case p_val {
    "" -> {
      #(
        Model(
          quick_links:,
          content: Directory("/"),
          entries: status.Loading,
          selected: new_selection(),
          sort: Sort(Name, Up),
        ),
        effect.batch([
          get_directory("/"),
          modem.replace("/", Some("p=/"), None),
        ]),
      )
    }
    p_val -> #(
      Model(
        quick_links:,
        content: Directory(p_val),
        entries: status.Loading,
        selected: new_selection(),
        sort: Sort(Name, Up),
      ),
      get_directory(p_val),
    )
  }
}

pub fn init_recent(user_config: UserConfig) {
  let UserConfig(quick_links:) = user_config
  #(
    Model(
      quick_links:,
      content: Recent,
      entries: status.Loading,
      selected: new_selection(),
      sort: Sort(Name, Up),
    ),
    get_recent(),
  )
}

pub fn init_starred(user_config: UserConfig) {
  let UserConfig(quick_links:) = user_config
  #(
    Model(
      quick_links:,
      content: Starred,
      entries: status.Loading,
      selected: new_selection(),
      sort: Sort(Name, Up),
    ),
    get_starred(),
  )
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
        Directory(dir_path) ->
          view_directory(dir_path, entries, model.selected, model.sort)
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

const static_quick_links = [
  config.QuickLink(config.House, "Home", "/?p=/"),
  config.QuickLink(config.Clock, "Recent", "/recent"),
  config.QuickLink(config.Star, "Starred", "/starred"),
]

fn view_quick_links(model: Model) {
  let cur_path =
    util.current_uri()
    |> util.path_and_query()
  div([], [
    ul(
      [class("quick-links")],
      list.map(static_quick_links, fn(link) {
        view_quick_link(link, cur_path == link.path)
      }),
    ),
    html.hr([]),
    ul(
      [class("quick-links")],
      list.map(model.quick_links, fn(link) {
        view_quick_link(link, cur_path == link.path)
      }),
    ),
  ])
}

fn view_quick_link(link: config.QuickLink, active: Bool) {
  li([], [
    a(
      [
        class("quick-link"),
        class("btn"),
        classes([#("btn-active", active)]),
        href(link.path),
      ],
      [icon.for_quick_link(link.icon), text(link.label)],
    ),
  ])
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

fn view_error(e: rsvp.Error) {
  h1([], [text("Failed! " <> string.inspect(e))])
}

fn view_directory(
  base_path: String,
  entries: List(DirEntry),
  selected: Selection,
  sort: Sort,
) {
  div([class("dir-scroll")], [
    table([class("dir-list"), on_click(SelectionCleared)], [
      colgroup([class("dir-cols")], [
        col([class("dir-col-name")]),
        col([class("dir-col-size")]),
        col([class("dir-col-time")]),
      ]),
      view_dir_table_head(sort),
      tbody(
        [],
        list.map(entries, fn(entry) {
          let ent_path = path.join(base_path, entry.name)
          let is_selected =
            set.contains(selected.active, entry.id)
            || set.contains(selected.rest, entry.id)
          view_dir_table_row(entry, ent_path, is_selected)
        }),
      ),
    ]),
  ])
}

fn view_recent(_entries: List(DirEntry)) {
  text("Recent")
}

fn view_starred(_entries: List(DirEntry)) {
  text("Starred")
}

fn view_dir_table_head(sort: Sort) {
  thead([class("dir-list-head")], [
    tr([], [
      th([class("dir-col-label")], [
        button([class("no-select"), on_click_no_prop(SortClicked(Name))], [
          text("Name"),
          view_sort_arrow(sort, Name),
        ]),
      ]),
      th([class("dir-col-label")], [
        button([class("no-select"), on_click_no_prop(SortClicked(Size))], [
          text("Size"),
          view_sort_arrow(sort, Size),
        ]),
      ]),
      th([class("dir-col-label")], [
        button([class("no-select"), on_click_no_prop(SortClicked(Modified))], [
          text("Modified"),
          view_sort_arrow(sort, Modified),
        ]),
      ]),
    ]),
  ])
}

fn view_sort_arrow(sort: Sort, on: Field) {
  case sort {
    Sort(cur_on, Up) if cur_on == on -> icon.up_caret()
    Sort(cur_on, Down) if cur_on == on -> icon.down_caret()
    _ -> element.none()
  }
}

fn view_dir_table_row(entry: DirEntry, ent_path: String, is_selected: Bool) {
  let #(row_icon, open_msg) = case entry.kind {
    dir_entry.File -> #(icon.for_mimetype(entry.mimetype), FileOpened(ent_path))
    dir_entry.Directory -> #(icon.folder(), DirOpened(ent_path))
  }
  tr(
    [
      class("dir-list-item"),
      classes([#("dir-list-item-selected", is_selected)]),
      on_click_mod(EntrySelected(entry.id, _)),
      event.on("dblclick", decode.success(open_msg)),
    ],
    [
      td([], [row_icon, no_mouse([class("dir-list-item-name")], entry.name)]),
      td([], [no_mouse([], dir_entry.format_size(entry))]),
      td([], [no_mouse([], intl.datetime_format("en-US", entry.mtime * 1000))]),
    ],
  )
}

fn no_mouse(attrs: List(Attribute(Msg)), str: String) {
  span([class("no-mouse"), ..attrs], [text(str)])
}

fn on_click_mod(cb: fn(ModKey) -> msg) {
  let handler = {
    use ctrl <- decode.field("ctrlKey", decode.bool)
    use meta <- decode.field("metaKey", decode.bool)
    use shift <- decode.field("shiftKey", decode.bool)
    let key = case ctrl || meta, shift {
      True, True -> CtrlShift
      True, False -> Ctrl
      False, True -> Shift
      False, False -> NoMod
    }
    decode.success(cb(key))
  }

  event.on("click", handler)
  |> event.prevent_default()
  |> event.stop_propagation()
}

fn on_click_no_prop(msg: msg) {
  event.on("click", decode.success(msg))
  |> event.stop_propagation()
}

// UPDATE

pub type Msg {
  DirOpened(dir_path: String)
  DirLoaded(Result(List(DirEntry), rsvp.Error))
  RecentOpened
  RecentLoaded(Result(List(DirEntry), rsvp.Error))
  StarredOpened
  StarredLoaded(Result(List(DirEntry), rsvp.Error))
  EntrySelected(id: String, mod: ModKey)
  SelectionCleared
  FileOpened(file_path: String)
  SortClicked(on: Field)
}

pub type ModKey {
  CtrlShift
  Ctrl
  Shift
  NoMod
}

pub fn update(global_model: global.Model, model: Model, msg: Msg) {
  case model.content, msg {
    _, DirOpened(dir_path) -> {
      let assert Ok(target_uri) = uri.parse("/?p=" <> dir_path)
      let msg_effect = case util.uri_is_current(target_uri) {
        True -> get_directory(dir_path)
        False ->
          effect.batch([
            get_directory(dir_path),
            modem.push(target_uri.path, target_uri.query, None),
          ])
      }
      #(
        global_model,
        Model(
          model.quick_links,
          Directory(dir_path),
          status.Loading,
          new_selection(),
          Sort(Name, Up),
        ),
        msg_effect,
      )
    }
    Directory(dir_path), DirLoaded(res) -> #(
      global_model,
      loaded_model(model, Directory(dir_path), res),
      effect.none(),
    )
    _, RecentOpened -> #(
      global_model,
      Model(
        model.quick_links,
        Recent,
        status.Loading,
        new_selection(),
        Sort(Name, Up),
      ),
      get_recent(),
    )
    Recent, RecentLoaded(res) -> #(
      global_model,
      loaded_model(model, Recent, res),
      effect.none(),
    )
    _, StarredOpened -> #(
      global_model,
      Model(
        model.quick_links,
        Starred,
        status.Loading,
        new_selection(),
        Sort(Name, Up),
      ),
      get_starred(),
    )
    Starred, StarredLoaded(res) -> #(
      global_model,
      loaded_model(model, Starred, res),
      effect.none(),
    )
    _, EntrySelected(id, mod) -> #(
      global_model,
      add_selection(model, id, mod),
      effect.none(),
    )
    _, SelectionCleared -> #(
      global_model,
      Model(..model, selected: new_selection()),
      effect.none(),
    )
    _, FileOpened(file_path) -> {
      let cur = util.current_uri()
      let download_uri =
        uri.Uri(..cur, path: "/download", query: Some("p=" <> file_path))
        |> uri.to_string()
      // ignore the result
      let _ = util.open_new_tab(download_uri)
      #(global_model, model, effect.none())
    }
    _, SortClicked(on) -> {
      let sort = case model.sort {
        Sort(cur_on, Up) if on == cur_on -> Sort(on, Down)
        _ -> Sort(on, Up)
      }
      let entries = case model.entries {
        status.Loaded(entries) -> status.Loaded(sort_entries(entries, sort))
        _ -> model.entries
      }
      #(
        global_model,
        Model(..model, entries: entries, sort: sort),
        effect.none(),
      )
    }
    _, _ -> #(global_model, model, effect.none())
  }
}

fn loaded_model(
  model: Model,
  content: Content,
  res: Result(List(DirEntry), rsvp.Error),
) {
  let entries = case res {
    Ok(entries) ->
      list.sort(entries, util.compare_name)
      |> status.Loaded
    Error(e) -> status.Failed(e)
  }
  Model(..model, content: content, entries: entries)
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
  |> rsvp.get(rsvp.expect_json(
    decode.list(dir_entry.decoder()),
    DirLoaded,
  ))
}

fn get_recent() {
  let cur = util.current_uri()
  uri.Uri(..cur, path: "/api/recent", query: None)
  |> uri.to_string()
  |> rsvp.get(rsvp.expect_json(
    decode.list(dir_entry.decoder()),
    RecentLoaded,
  ))
}

fn get_starred() {
  let cur = util.current_uri()
  uri.Uri(..cur, path: "/api/starred", query: None)
  |> uri.to_string()
  |> rsvp.get(rsvp.expect_json(
    decode.list(dir_entry.decoder()),
    StarredLoaded,
  ))
}

fn sort_entries(entries: List(DirEntry), sort: Sort) {
  let sorted = case sort.on {
    Name -> list.sort(entries, util.compare_name)
    Size -> list.sort(entries, util.compare_size)
    Modified -> list.sort(entries, util.compare_mtime)
  }
  case sort.direction {
    Up -> sorted
    Down -> list.reverse(sorted)
  }
}
