import lustre/attribute.{class}
import lustre/element.{type Element}
import lustre/element/html.{div}

pub fn row(children: List(Element(msg))) {
  div([class("row")], children)
}
