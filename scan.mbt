///|
/// A read-only character cursor.
///
/// Every position is a character index into the original input. Sub-cursors share
/// the same character array, so error positions never drift when parsing in pieces.
priv struct Cursor {
  chars : Array[Char]
  mut pos : Int32
  limit : Int32
}

///|
fn Cursor::new(s : String) -> Cursor {
  let chars = s.to_array()
  { chars, pos: 0, limit: chars.length(), }
}

///|
fn Cursor::sub(self : Cursor, start : Int32, end : Int32) -> Cursor {
  { chars: self.chars, pos: start, limit: end, }
}

///|
fn Cursor::eof(self : Cursor) -> Bool {
  self.pos >= self.limit
}

///|
fn Cursor::peek(self : Cursor) -> Char? {
  if self.pos < self.limit {
    Some(self.chars[self.pos])
  } else {
    None
  }
}

///|
fn Cursor::bump(self : Cursor) -> Unit {
  if self.pos < self.limit {
    self.pos = self.pos + 1
  }
}

///|
fn Cursor::eat(self : Cursor, c : Char) -> Bool {
  match self.peek() {
    Some(x) =>
      if x == c {
        self.bump()
        true
      } else {
        false
      }
    None => false
  }
}

///|
fn Cursor::skip_spaces(self : Cursor) -> Unit {
  while true {
    match self.peek() {
      Some(c) => if is_space(c) { self.bump() } else { break }
      None => break
    }
  }
}

///|
fn Cursor::slice(self : Cursor, start : Int32, end : Int32) -> String {
  String::from_array(self.chars[start:end])
}

///|
fn is_space(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\n' || c == '\r'
}

///|
fn is_digit(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

///|
fn is_alpha(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
}

///|
fn is_identifier_char(c : Char) -> Bool {
  is_alpha(c) || is_digit(c) || c == '-'
}

///|
fn is_wildcard(c : Char) -> Bool {
  c == '*' || c == 'x' || c == 'X'
}

///|
fn describe_char(c : Char) -> String {
  if is_space(c) {
    "whitespace"
  } else {
    "'\{c}'"
  }
}
