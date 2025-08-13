import marceau

import shared/path

pub fn from_file_name(name: String) {
  let extension = path.file_extension(name)
  case name {
    ".profile" | ".bash_profile" | ".bashrc" -> "application/x-sh"
    _ -> marceau.extension_to_mime_type(extension)
  }
}
