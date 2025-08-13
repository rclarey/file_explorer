import rsvp

pub type Status(a) {
  Loading
  Failed(rsvp.Error)
  Loaded(a)
}

pub fn map_loaded(status: Status(a), fallback: b, f: fn(a) -> b) {
  case status {
    Loaded(x) -> f(x)
    _ -> fallback
  }
}
