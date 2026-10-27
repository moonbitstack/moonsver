///|
/// A SemVer 2.0.0 version.
///
/// The three numbers are arbitrary-precision integers, so `18446744073709551616.0.0`
/// parses, prints and compares exactly, well past 64 bits.
///
/// The fields are private and only `Version::new` / `Version::parse` can build one,
/// so a version never carries a leading zero or a malformed identifier list.
pub struct Version {
  major : @bigint.BigInt
  minor : @bigint.BigInt
  patch : @bigint.BigInt
  pre : Array[Identifier]
  build : Array[String]
}

///|
/// Build a version from three `Int`s, with no prerelease and no build metadata.
pub fn Version::new(major : Int32, minor : Int32, patch : Int32) -> Version {
  {
    major: @bigint.BigInt::from_int(major),
    minor: @bigint.BigInt::from_int(minor),
    patch: @bigint.BigInt::from_int(patch),
    pre: [],
    build: [],
  }
}

///|
/// Build a version from three arbitrary-precision integers.
pub fn Version::from_bigint(
  major : @bigint.BigInt,
  minor : @bigint.BigInt,
  patch : @bigint.BigInt,
) -> Version {
  { major, minor, patch, pre: [], build: [], }
}

///|
/// The major number.
pub fn Version::major(self : Version) -> @bigint.BigInt {
  self.major
}

///|
/// The minor number.
pub fn Version::minor(self : Version) -> @bigint.BigInt {
  self.minor
}

///|
/// The patch number.
pub fn Version::patch(self : Version) -> @bigint.BigInt {
  self.patch
}

///|
/// The prerelease identifiers: `["alpha", 1]` for `1.2.3-alpha.1`.
pub fn Version::prerelease(self : Version) -> ArrayView[Identifier] {
  self.pre[:]
}

///|
/// The build metadata identifiers: `["build", "5"]` for `1.2.3+build.5`.
pub fn Version::build(self : Version) -> ArrayView[String] {
  self.build[:]
}

///|
/// Whether the version carries a prerelease.
pub fn Version::is_prerelease(self : Version) -> Bool {
  !self.pre.is_empty()
}

///|
/// Whether this is a stable release. Build metadata does not make it unstable.
pub fn Version::is_stable(self : Version) -> Bool {
  self.pre.is_empty()
}

///|
/// Whether the three numbers match, ignoring prerelease and build metadata.
pub fn Version::same_core(self : Version, other : Version) -> Bool {
  self.major == other.major &&
  self.minor == other.minor &&
  self.patch == other.patch
}

///|
/// Keep the three numbers only, dropping prerelease and build metadata.
pub fn Version::core(self : Version) -> Version {
  {
    major: self.major,
    minor: self.minor,
    patch: self.patch,
    pre: [],
    build: [],
  }
}

///|
/// The `major.minor.patch` form, without prerelease or build metadata.
pub fn Version::core_string(self : Version) -> String {
  let sb = StringBuilder()
  sb.write_string(self.major.to_string())
  sb.write_string(".")
  sb.write_string(self.minor.to_string())
  sb.write_string(".")
  sb.write_string(self.patch.to_string())
  sb.to_string()
}

///|
/// Parse a version.
///
/// The npm grammar is the default, so `v1.2.3`, `=1.2.3` and surrounding whitespace
/// are all fine. Pass `syntax=Syntax::strict()` to hold to the spec exactly.
pub fn Version::parse(
  s : String,
  syntax~ : Syntax = Syntax::npm(),
) -> Version raise Refused {
  parse_version_full(s, syntax)
}

///|
fn parse_version_full(s : String, syn : Syntax) -> Version raise Refused {
  let cur = Cursor::new(s)
  if syn.trim {
    cur.skip_spaces()
  }
  if cur.eof() {
    fail(EmptyInput, "empty version string", 0)
  }
  let v = parse_version_at(cur, syn)
  if syn.trim {
    cur.skip_spaces()
  }
  if !cur.eof() {
    let what = match cur.peek() {
      Some(c) => describe_char(c)
      None => "end of input"
    }
    fail(UnexpectedChar, "unexpected \{what} after the version", cur.pos)
  }
  v
}

///|
fn parse_version_at(cur : Cursor, syn : Syntax) -> Version raise Refused {
  if syn.allow_v_prefix {
    match cur.peek() {
      Some('v') | Some('V') => cur.bump()
      _ => ()
    }
  }
  if syn.allow_equals_prefix {
    if cur.eat('=') {
      ()
    }
  }
  let major = parse_number(cur, "major")
  if !cur.eat('.') {
    if cur.eof() {
      fail(
        UnexpectedEnd,
        "version ends early: expected '.' and a minor number",
        cur.pos,
      )
    } else {
      fail(UnexpectedChar, "expected the first '.' separator", cur.pos)
    }
  }
  let minor = parse_number(cur, "minor")
  if !cur.eat('.') {
    if cur.eof() {
      fail(
        UnexpectedEnd,
        "version ends early: expected '.' and a patch number",
        cur.pos,
      )
    } else {
      fail(UnexpectedChar, "expected the second '.' separator", cur.pos)
    }
  }
  let patch = parse_number(cur, "patch")
  let mut pre : Array[Identifier] = []
  if cur.peek() == Some('-') {
    cur.bump()
    pre = parse_prerelease_ids(cur)
  }
  let mut build : Array[String] = []
  if cur.peek() == Some('+') {
    if !syn.allow_build_metadata {
      fail(
        UnsupportedSyntax,
        "this grammar does not accept build metadata",
        cur.pos,
      )
    }
    cur.bump()
    build = parse_build_ids(cur)
  }
  { major, minor, patch, pre, build, }
}

///|
/// Parse a numeric component: decimal digits, no leading zero unless the value is `0`.
fn parse_number(cur : Cursor, what : String) -> @bigint.BigInt raise Refused {
  let start = cur.pos
  while true {
    match cur.peek() {
      Some(c) => if is_digit(c) { cur.bump() } else { break }
      None => break
    }
  }
  if cur.pos == start {
    fail(InvalidNumber, "expected a decimal \{what} number here", cur.pos)
  }
  let text = cur.slice(start, cur.pos)
  if text.length() > 1 && text.get_char(0) == Some('0') {
    fail(LeadingZero, "\{what} number has a leading zero: \{text}", start)
  }
  @bigint.BigInt::from_string(text)
}

///|
/// Parse the prerelease identifiers after `-` (the `-` is already consumed).
fn parse_prerelease_ids(cur : Cursor) -> Array[Identifier] raise Refused {
  let ids : Array[Identifier] = []
  while true {
    let start = cur.pos
    while true {
      match cur.peek() {
        Some(c) => if is_identifier_char(c) { cur.bump() } else { break }
        None => break
      }
    }
    if cur.pos == start {
      fail(EmptyIdentifier, "prerelease identifier is empty", cur.pos)
    }
    let text = cur.slice(start, cur.pos)
    ids.push(parse_identifier(text, true, start))
    if cur.eat('.') {
      continue
    } else {
      break
    }
  }
  ids
}

///|
/// Parse the build metadata identifiers after `+` (the `+` is already consumed).
fn parse_build_ids(cur : Cursor) -> Array[String] raise Refused {
  let ids : Array[String] = []
  while true {
    let start = cur.pos
    while true {
      match cur.peek() {
        Some(c) => if is_identifier_char(c) { cur.bump() } else { break }
        None => break
      }
    }
    if cur.pos == start {
      fail(EmptyIdentifier, "build metadata identifier is empty", cur.pos)
    }
    ids.push(cur.slice(start, cur.pos))
    if cur.eat('.') {
      continue
    } else {
      break
    }
  }
  ids
}

///|
/// Turn a run of identifier text into an `Identifier`.
///
/// All-digit text becomes numeric. A numeric prerelease identifier may not carry a
/// leading zero; build metadata may, since it never takes part in precedence.
fn parse_identifier(
  text : String,
  is_prerelease : Bool,
  position : Int32,
) -> Identifier raise Refused {
  let numeric = text.all(fn(c) { is_digit(c) })
  if numeric {
    if is_prerelease && text.length() > 1 && text.get_char(0) == Some('0') {
      fail(
        LeadingZero,
        "numeric prerelease identifier has a leading zero: \{text}",
        position,
      )
    }
    Identifier::Num(@bigint.BigInt::from_string(text))
  } else {
    Identifier::Alpha(text)
  }
}

///|
/// Compare precedence as laid out in SemVer 2.0.0 §11.
///
/// Returns `-1`, `0` or `1`. **Build metadata takes no part**: `1.0.0+a` and
/// `1.0.0+b` share the same precedence.
pub fn Version::precedence_cmp(self : Version, other : Version) -> Int32 {
  let c = self.major.compare(other.major)
  if c != 0 {
    return c
  }
  let c = self.minor.compare(other.minor)
  if c != 0 {
    return c
  }
  let c = self.patch.compare(other.patch)
  if c != 0 {
    return c
  }
  compare_identifiers(self.pre, other.pre)
}

///|
fn compare_build(a : Array[String], b : Array[String]) -> Int32 {
  if a.is_empty() && b.is_empty() {
    return 0
  }
  if a.is_empty() {
    return -1
  }
  if b.is_empty() {
    return 1
  }
  let n = if a.length() < b.length() { a.length() } else { b.length() }
  for i in 0..<n {
    let c = compare_build_identifier(a[i], b[i])
    if c != 0 {
      return c
    }
  }
  if a.length() < b.length() {
    -1
  } else if a.length() > b.length() {
    1
  } else {
    0
  }
}

///|
/// Build metadata ordering: numbers without a leading zero compare numerically,
/// everything else in ASCII order, numeric before alphanumeric. Ties only.
fn compare_build_identifier(a : String, b : String) -> Int32 {
  let an = is_canonical_number(a)
  let bn = is_canonical_number(b)
  if an && bn {
    @bigint.BigInt::from_string(a).compare(@bigint.BigInt::from_string(b))
  } else if an {
    -1
  } else if bn {
    1
  } else {
    a.lexical_compare(b)
  }
}

///|
fn is_canonical_number(s : String) -> Bool {
  if s.is_empty() {
    return false
  }
  if !s.all(fn(c) { is_digit(c) }) {
    return false
  }
  s.length() == 1 || s.get_char(0) != Some('0')
}

///|
/// The canonical form: `major.minor.patch[-prerelease][+build]`.
pub extend Version with Show::{to_string, output}

///|
pub impl Show for Version with fn to_string(self : Version) -> String {
  let sb = StringBuilder()
  sb.write_string(self.major.to_string())
  sb.write_string(".")
  sb.write_string(self.minor.to_string())
  sb.write_string(".")
  sb.write_string(self.patch.to_string())
  if !self.pre.is_empty() {
    sb.write_string("-")
    for i in 0..<self.pre.length() {
      if i > 0 {
        sb.write_string(".")
      }
      sb.write_string(self.pre[i].to_string())
    }
  }
  if !self.build.is_empty() {
    sb.write_string("+")
    for i in 0..<self.build.length() {
      if i > 0 {
        sb.write_string(".")
      }
      sb.write_string(self.build[i])
    }
  }
  sb.to_string()
}

///|
pub extend Version with @debug.Debug::{to_repr}

///|
pub impl @debug.Debug for Version with fn to_repr(self : Version) -> @debug.Repr {
  @debug.Repr(self.to_string())
}

///|
/// Full equality: the numbers, the prerelease and the build metadata all match.
///
/// That differs from precedence: `1.0.0+a` and `1.0.0+b` are not equal, yet rank alike.
pub extend Version with Eq::{equal, not_equal}

///|
pub impl Eq for Version with fn equal(self : Version, other : Version) -> Bool {
  self.major == other.major &&
  self.minor == other.minor &&
  self.patch == other.patch &&
  self.pre == other.pre &&
  self.build == other.build
}

///|
pub extend Version with Compare::{compare, op_lt, op_le, op_gt, op_ge}

///|
/// A total order: precedence first, then build metadata so sorting is deterministic.
///
/// `Array::sort` gives a reproducible order while `precedence_cmp` stays true to the spec.
pub impl Compare for Version with fn compare(self : Version, other : Version) -> Int32 {
  let c = self.precedence_cmp(other)
  if c != 0 {
    return c
  }
  compare_build(self.build, other.build)
}

///|
pub extend Version with Hash::{hash_combine, hash}

///|
pub impl Hash for Version with fn hash_combine(self : Version, hasher : Hasher) -> Unit {
  hasher.combine_string(self.to_string())
}

///|
pub extend Version with @json.ToJson::{to_json}

///|
pub impl @json.ToJson for Version with fn to_json(self : Version) -> Json {
  Json::string(self.to_string())
}

///|
pub extend Version with @json.FromJson::{from_json}

///|
pub impl @json.FromJson for Version with fn from_json(
  json : Json,
  path : @json.JsonPath,
) -> Version raise @json.JsonDecodeError {
  let s = if json is String(s) {
    s
  } else {
    raise @json.JsonDecodeError((path, "moonsver: a version must be a string"))
  }
  Version::parse(s) catch {
    e => raise @json.JsonDecodeError((path, "moonsver: " + e.to_string()))
  }
}
