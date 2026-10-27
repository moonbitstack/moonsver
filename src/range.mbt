///|
/// A comparison operator.
pub(all) enum Op {
  /// Equals `=`
  Eq
  /// Not equal `!=`, which only grammars such as `Syntax::ruby()` accept
  Ne
  /// Greater than `>`
  Gt
  /// Greater than or equal `>=`
  Ge
  /// Less than `<`
  Lt
  /// Less than or equal `<=`
  Le
}

///|
/// One comparator: an operator and a full version.
///
/// Build metadata is dropped from comparators (`>=1.2.3+build` is `>=1.2.3`),
/// since it takes no part in precedence.
pub(all) struct Comparator {
  op : Op
  version : Version
}

///|
/// A conjunction (AND) of comparators. An empty list means "any version".
pub(all) struct ComparatorSet {
  comparators : Array[Comparator]
}

///|
/// A version range: a disjunction (OR) of comparator sets.
///
/// A `Range` is the parsed, normalised structure rather than the original string.
/// `^1.2.3`, for instance, becomes the set `>=1.2.3`, `<2.0.0`.
pub struct Range {
  sets : Array[ComparatorSet]
  policy : PrereleasePolicy
}

///|
/// A range matching any stable version, the same as `*`.
pub fn Range::any() -> Range {
  let comps : Array[Comparator] = []
  { sets: [{ comparators: comps, }], policy: SameTuple, }
}

///|
/// The disjuncts, one per `||` branch.
pub fn Range::sets(self : Range) -> ArrayView[ComparatorSet] {
  self.sets[:]
}

///|
/// The prerelease policy this range was parsed with.
pub fn Range::policy(self : Range) -> PrereleasePolicy {
  self.policy
}

///|
/// Whether this is equivalent to "any version".
pub fn Range::is_any(self : Range) -> Bool {
  for set in self.sets {
    if !set.comparators.is_empty() {
      return false
    }
  }
  true
}

///|
/// Parse a version range.
///
/// npm's grammar is the default; pass `syntax=` for Cargo, Ruby or strict.
pub fn Range::parse(
  s : String,
  syntax~ : Syntax = Syntax::npm(),
) -> Range raise Refused {
  parse_range_full(s, syntax)
}

///|
/// Parse with the given grammar, raising `Refused` when it does not fit.
fn parse_range_full(s : String, syn : Syntax) -> Range raise Refused {
  let cur = Cursor::new(s)
  if syn.trim {
    cur.skip_spaces()
  }
  let sets : Array[ComparatorSet] = []
  if cur.eof() {
    if !syn.allow_empty {
      fail(EmptyInput, "empty range", 0)
    }
    let comps : Array[Comparator] = []
    sets.push({ comparators: comps, })
  } else {
    while true {
      sets.push(parse_comparator_set(cur, syn))
      if syn.trim {
        cur.skip_spaces()
      }
      if cur.eof() {
        break
      }
      match cur.peek() {
        Some('|') => {
          if !syn.allow_or {
            fail(
              UnsupportedSyntax,
              "this grammar does not support '||'",
              cur.pos,
            )
          }
          cur.bump()
          if !cur.eat('|') {
            fail(UnexpectedChar, "'|' must come in pairs ('||')", cur.pos)
          }
        }
        Some(c) =>
          fail(
            UnexpectedChar,
            "unexpected \{describe_char(c)} in the range",
            cur.pos,
          )
        None => break
      }
    }
  }
  { sets, policy: syn.prerelease_policy, }
}

///|
/// Parse one conjunct: the text between `||`.
fn parse_comparator_set(
  cur : Cursor,
  syn : Syntax,
) -> ComparatorSet raise Refused {
  let tokens : Array[Token] = []
  while true {
    while true {
      match cur.peek() {
        Some(c) => if is_space(c) || c == ',' { cur.bump() } else { break }
        None => break
      }
    }
    if cur.eof() {
      break
    }
    if cur.peek() == Some('|') {
      break
    }
    let start = cur.pos
    while true {
      match cur.peek() {
        Some(c) =>
          if is_space(c) || c == ',' || c == '|' {
            break
          } else {
            cur.bump()
          }
        None => break
      }
    }
    let end = cur.pos
    tokens.push({ text: cur.slice(start, end), start, end, })
  }
  let tokens = merge_operator_tokens(tokens)
  if tokens.is_empty() {
    if !syn.allow_empty {
      fail(EmptyInput, "expected a version range here", cur.pos)
    }
    let comps : Array[Comparator] = []
    return { comparators: comps, }
  }
  if tokens.length() == 3 && tokens[1].text == "-" {
    if !syn.allow_hyphen_range {
      fail(
        UnsupportedSyntax,
        "this grammar does not support hyphen ranges (A - B)",
        tokens[1].start,
      )
    }
    let lo = parse_partial_token(cur, tokens[0], syn)
    let hi = parse_partial_token(cur, tokens[2], syn)
    return { comparators: hyphen_range(lo, hi), }
  }
  let comps : Array[Comparator] = []
  for tok in tokens {
    for c in parse_comparator_token(cur, tok, syn) {
      comps.push(c)
    }
  }
  { comparators: comps, }
}

///|
/// Is this token nothing but an operator?
///
/// Cargo and Ruby allow a space between operator and version (`>= 1.2`, `~> 1.2`),
/// which lexes as two tokens; glue them back together here.
fn is_operator_only(s : String) -> Bool {
  match s {
    ">" | ">=" | "<" | "<=" | "=" | "==" | "!=" | "!" | "^" | "~" | "~>" => true
    _ => false
  }
}

///|
fn merge_operator_tokens(tokens : Array[Token]) -> Array[Token] {
  let out : Array[Token] = []
  let mut i = 0
  while i < tokens.length() {
    let t = tokens[i]
    if is_operator_only(t.text) && i + 1 < tokens.length() {
      let n = tokens[i + 1]
      out.push({ text: t.text + n.text, start: t.start, end: n.end, })
      i = i + 2
    } else {
      out.push(t)
      i = i + 1
    }
  }
  out
}

///|
/// A token: text with no space or comma, plus its position in the original input.
priv struct Token {
  text : String
  start : Int32
  end : Int32
}

///|
/// The operator found on a token (internal, kept apart from the public `Op`).
priv enum TokenOp {
  TNone
  TEq
  TNe
  TGt
  TGe
  TLt
  TLe
  TCaret
  TTilde
}

///|
fn parse_comparator_token(
  cur : Cursor,
  tok : Token,
  syn : Syntax,
) -> Array[Comparator] raise Refused {
  let sub = cur.sub(tok.start, tok.end)
  let op = detect_operator(sub, syn)
  sub.skip_spaces()
  let p = parse_partial_at(sub, syn)
  if !sub.eof() {
    let what = match sub.peek() {
      Some(c) => describe_char(c)
      None => "end of input"
    }
    fail(UnexpectedChar, "unexpected \{what} in the comparator", sub.pos)
  }
  desugar(op, p, syn, tok.start)
}

///|
fn parse_partial_token(
  cur : Cursor,
  tok : Token,
  syn : Syntax,
) -> Partial raise Refused {
  let sub = cur.sub(tok.start, tok.end)
  match sub.peek() {
    Some('>') | Some('<') | Some('=') | Some('^') | Some('~') | Some('!') =>
      fail(
        InvalidRange,
        "a hyphen range endpoint cannot carry an operator",
        sub.pos,
      )
    _ => ()
  }
  let p = parse_partial_at(sub, syn)
  if !sub.eof() {
    let what = match sub.peek() {
      Some(c) => describe_char(c)
      None => "end of input"
    }
    fail(
      UnexpectedChar,
      "unexpected \{what} in the hyphen range endpoint",
      sub.pos,
    )
  }
  p
}

///|
fn detect_operator(cur : Cursor, syn : Syntax) -> TokenOp raise Refused {
  match cur.peek() {
    Some('>') => {
      cur.bump()
      if cur.eat('=') {
        TGe
      } else {
        TGt
      }
    }
    Some('<') => {
      cur.bump()
      if cur.eat('=') {
        TLe
      } else {
        TLt
      }
    }
    Some('!') => {
      let start = cur.pos
      cur.bump()
      if cur.eat('=') {
        if !syn.allow_ne {
          fail(UnsupportedSyntax, "this grammar does not support '!='", start)
        }
        TNe
      } else {
        fail(UnexpectedChar, "a lone '!'", start)
      }
    }
    Some('=') => {
      cur.bump()
      if cur.eat('=') {
        ()
      }
      TEq
    }
    Some('^') => {
      if !syn.allow_caret {
        fail(UnsupportedSyntax, "this grammar does not support '^'", cur.pos)
      }
      cur.bump()
      TCaret
    }
    Some('~') => {
      let start = cur.pos
      cur.bump()
      if cur.peek() == Some('>') {
        cur.bump()
        if !(syn.allow_tilde && syn.tilde_bump == LastSpecified) {
          fail(UnsupportedSyntax, "this grammar does not support '~>'", start)
        }
      } else if !syn.allow_tilde {
        fail(UnsupportedSyntax, "this grammar does not support '~'", start)
      }
      TTilde
    }
    _ => TNone
  }
}

///|
/// A partial version: trailing segments may be omitted (`1`, `1.2`) or wildcarded.
priv struct Partial {
  major : @bigint.BigInt?
  minor : @bigint.BigInt?
  patch : @bigint.BigInt?
  pre : Array[Identifier]
  wild : Bool
}

///|
fn parse_partial_at(cur : Cursor, syn : Syntax) -> Partial raise Refused {
  let start = cur.pos
  if syn.allow_v_prefix {
    match cur.peek() {
      Some('v') | Some('V') => cur.bump()
      _ => ()
    }
  }
  let major = parse_segment(cur, "major")
  let mut wild = is_wild_segment(major)
  let mut minor : @bigint.BigInt? = None
  let mut patch : @bigint.BigInt? = None
  if cur.eat('.') {
    minor = parse_segment(cur, "minor")
    if is_wild_segment(minor) {
      wild = true
    }
    if cur.eat('.') {
      patch = parse_segment(cur, "patch")
      if is_wild_segment(patch) {
        wild = true
      }
      if cur.peek() == Some('.') {
        fail(InvalidRange, "a version has three segments at most", cur.pos)
      }
    }
  }
  let has_major = match major {
    Some(_) => true
    None => false
  }
  let has_minor = match minor {
    Some(_) => true
    None => false
  }
  let has_patch = match patch {
    Some(_) => true
    None => false
  }
  if !has_major && (has_minor || has_patch) {
    fail(InvalidRange, "no concrete segment may follow a wildcard", start)
  }
  if !has_minor && has_patch {
    fail(InvalidRange, "no concrete segment may follow a wildcard", start)
  }
  let full = has_major && has_minor && has_patch
  let mut pre : Array[Identifier] = []
  if cur.peek() == Some('-') {
    if !full {
      fail(
        InvalidIdentifier,
        "a prerelease only follows a complete version",
        cur.pos,
      )
    }
    cur.bump()
    pre = parse_prerelease_ids(cur)
  }
  if cur.peek() == Some('+') {
    if !syn.allow_build_metadata {
      fail(
        UnsupportedSyntax,
        "this grammar does not accept build metadata",
        cur.pos,
      )
    }
    if !full {
      fail(
        InvalidIdentifier,
        "build metadata only follows a complete version",
        cur.pos,
      )
    }
    cur.bump()
    // Build metadata never takes part in precedence, so validate it and drop it.
    let _ = parse_build_ids(cur)
  }
  { major, minor, patch, pre, wild, }
}

///|
fn is_wild_segment(seg : @bigint.BigInt?) -> Bool {
  match seg {
    None => true
    Some(_) => false
  }
}

///|
fn parse_segment(cur : Cursor, what : String) -> @bigint.BigInt? raise Refused {
  match cur.peek() {
    Some(c) =>
      if is_wildcard(c) {
        cur.bump()
        None
      } else {
        Some(parse_number(cur, what))
      }
    None =>
      fail(
        UnexpectedEnd,
        "incomplete version: expected a \{what} number",
        cur.pos,
      )
  }
}

///|
fn zero() -> @bigint.BigInt {
  @bigint.BigInt::from_int(0)
}

///|
fn one() -> @bigint.BigInt {
  @bigint.BigInt::from_int(1)
}

///|
/// The first missing or wildcarded segment: 1 major, 2 minor, 3 patch, 4 complete.
fn Partial::wild_level(self : Partial) -> Int32 {
  let has_major = match self.major {
    Some(_) => true
    None => false
  }
  let has_minor = match self.minor {
    Some(_) => true
    None => false
  }
  let has_patch = match self.patch {
    Some(_) => true
    None => false
  }
  if !has_major {
    1
  } else if !has_minor {
    2
  } else if !has_patch {
    3
  } else {
    4
  }
}

///|
fn Partial::is_any(self : Partial) -> Bool {
  self.wild_level() == 1
}

///|
/// Fill missing segments with 0 for the lower bound (prerelease kept, build dropped).
fn Partial::low(self : Partial) -> Version {
  let major = match self.major {
    Some(x) => x
    None => zero()
  }
  let minor = match self.minor {
    Some(x) => x
    None => zero()
  }
  let patch = match self.patch {
    Some(x) => x
    None => zero()
  }
  { major, minor, patch, pre: self.pre.copy(), build: [], }
}

///|
fn major_of(p : Partial) -> @bigint.BigInt {
  match p.major {
    Some(x) => x
    None => zero()
  }
}

///|
fn minor_of(p : Partial) -> @bigint.BigInt {
  match p.minor {
    Some(x) => x
    None => zero()
  }
}

///|
fn patch_of(p : Partial) -> @bigint.BigInt {
  match p.patch {
    Some(x) => x
    None => zero()
  }
}

///|
fn mk(
  major : @bigint.BigInt,
  minor : @bigint.BigInt,
  patch : @bigint.BigInt,
) -> Version {
  { major, minor, patch, pre: [], build: [], }
}

///|
fn cmp(op : Op, version : Version) -> Comparator {
  { op, version, }
}

///|
/// Expand one token (operator plus partial version) into comparators.
///
/// Each operator expands to a lower and an upper bound; only which spellings are
/// allowed differs, and that is the grammar.
fn desugar(
  op : TokenOp,
  p : Partial,
  syn : Syntax,
  pos : Int32,
) -> Array[Comparator] raise Refused {
  let out : Array[Comparator] = []
  let wl = p.wild_level()
  let op = match op {
    TNone =>
      if p.wild {
        // An explicit wildcard means wildcard semantics whatever default_op says (Cargo's 1.2.* is no caret)
        TEq
      } else {
        match syn.default_op {
          Exact => TEq
          Caret => TCaret
          Tilde => TTilde
        }
      }
    other => other
  }
  match op {
    TEq => {
      if wl == 1 {
        return out
      }
      if wl == 4 {
        out.push(cmp(Op::Eq, p.low()))
        return out
      }
      if !syn.allow_xrange {
        fail(
          UnsupportedSyntax,
          "this grammar does not allow omitted segments (such as 1.2 or 1.x)",
          pos,
        )
      }
      out.push(cmp(Op::Ge, p.low()))
      if wl == 2 {
        out.push(cmp(Op::Lt, mk(major_of(p) + one(), zero(), zero())))
      } else {
        out.push(cmp(Op::Lt, mk(major_of(p), minor_of(p) + one(), zero())))
      }
      out
    }
    TNe => {
      if wl != 4 {
        fail(UnsupportedSyntax, "'!=' needs a complete version", pos)
      }
      out.push(cmp(Op::Ne, p.low()))
      out
    }
    TGt | TGe | TLt | TLe => {
      if wl == 1 {
        match op {
          TGt | TLt => out.push(cmp(Op::Lt, mk(zero(), zero(), zero())))
          _ => ()
        }
        return out
      }
      if wl == 4 {
        out.push(
          cmp(
            match op {
              TGt => Op::Gt
              TGe => Op::Ge
              TLt => Op::Lt
              _ => Op::Le
            },
            p.low(),
          ),
        )
        return out
      }
      if !syn.allow_xrange {
        fail(
          UnsupportedSyntax,
          "this grammar does not allow omitted segments (such as 1.2 or 1.x)",
          pos,
        )
      }
      let major = major_of(p)
      let minor = minor_of(p)
      if wl == 2 {
        match op {
          TGt => out.push(cmp(Op::Ge, mk(major + one(), zero(), zero())))
          TGe => out.push(cmp(Op::Ge, mk(major, zero(), zero())))
          TLt => out.push(cmp(Op::Lt, mk(major, zero(), zero())))
          _ => out.push(cmp(Op::Lt, mk(major + one(), zero(), zero())))
        }
      } else {
        match op {
          TGt => out.push(cmp(Op::Ge, mk(major, minor + one(), zero())))
          TGe => out.push(cmp(Op::Ge, mk(major, minor, zero())))
          TLt => out.push(cmp(Op::Lt, mk(major, minor, zero())))
          _ => out.push(cmp(Op::Lt, mk(major, minor + one(), zero())))
        }
      }
      out
    }
    TCaret => {
      if wl == 1 {
        return out
      }
      let major = major_of(p)
      let minor = minor_of(p)
      let patch = patch_of(p)
      let upper = if major.compare_int(0) > 0 {
        mk(major + one(), zero(), zero())
      } else if wl == 2 {
        mk(one(), zero(), zero())
      } else if minor.compare_int(0) > 0 {
        mk(zero(), minor + one(), zero())
      } else if wl == 3 {
        mk(zero(), one(), zero())
      } else if patch.compare_int(0) > 0 {
        mk(zero(), zero(), patch + one())
      } else {
        mk(zero(), zero(), one())
      }
      out.push(cmp(Op::Ge, p.low()))
      out.push(cmp(Op::Lt, upper))
      out
    }
    TTilde => {
      if wl == 1 {
        return out
      }
      let major = major_of(p)
      let minor = minor_of(p)
      let upper = match syn.tilde_bump {
        Patch =>
          if wl == 2 {
            mk(major + one(), zero(), zero())
          } else {
            mk(major, minor + one(), zero())
          }
        LastSpecified =>
          if wl == 4 {
            mk(major, minor + one(), zero())
          } else {
            mk(major + one(), zero(), zero())
          }
      }
      out.push(cmp(Op::Ge, p.low()))
      out.push(cmp(Op::Lt, upper))
      out
    }
    TNone => out
  }
}

///|
/// A hyphen range `A - B`: the lower bound is A filled out with zeroes, and the upper
/// bound comes from B, with its first wildcard segment bumped.
fn hyphen_range(low : Partial, high : Partial) -> Array[Comparator] {
  let out : Array[Comparator] = []
  if !low.is_any() {
    out.push(cmp(Op::Ge, low.low()))
  }
  if !high.is_any() {
    let wl = high.wild_level()
    if wl == 4 {
      out.push(cmp(Op::Le, high.low()))
    } else if wl == 2 {
      out.push(cmp(Op::Lt, mk(major_of(high) + one(), zero(), zero())))
    } else {
      out.push(cmp(Op::Lt, mk(major_of(high), minor_of(high) + one(), zero())))
    }
  }
  out
}

///|
fn op_symbol(op : Op) -> String {
  match op {
    Eq => "="
    Ne => "!="
    Gt => ">"
    Ge => ">="
    Lt => "<"
    Le => "<="
  }
}

///|
/// Canonical range text: disjuncts joined with ` || `.
///
/// The output always re-parses under the same grammar (even strict reads `*`).
pub extend Range with Show::{to_string, output}

///|
pub impl Show for Range with fn to_string(self : Range) -> String {
  if self.sets.is_empty() {
    return "*"
  }
  let parts : Array[String] = []
  for s in self.sets {
    parts.push(s.to_string())
  }
  parts.join(" || ")
}

///|
pub extend Range with @debug.Debug::{to_repr}

///|
pub impl @debug.Debug for Range with fn to_repr(self : Range) -> @debug.Repr {
  @debug.Repr(self.to_string())
}

///|
pub extend Comparator with Show::{to_string, output}

///|
/// Canonical comparator text: operator plus version.
pub impl Show for Comparator with fn to_string(self : Comparator) -> String {
  let sb = StringBuilder()
  sb.write_string(op_symbol(self.op))
  sb.write_string(self.version.to_string())
  sb.to_string()
}

///|
pub extend Comparator with @debug.Debug::{to_repr}

///|
pub impl @debug.Debug for Comparator with fn to_repr(self : Comparator) -> @debug.Repr {
  @debug.Repr(self.to_string())
}

///|
pub extend ComparatorSet with Show::{to_string, output}

///|
/// Canonical set text: comparators joined with `, `; an empty set prints as `*`.
pub impl Show for ComparatorSet with fn to_string(self : ComparatorSet) -> String {
  if self.comparators.is_empty() {
    return "*"
  }
  let parts : Array[String] = []
  for c in self.comparators {
    parts.push(c.to_string())
  }
  parts.join(", ")
}

///|
pub extend Op with Show::{to_string, output}

///|
/// The operator as text.
pub impl Show for Op with fn to_string(self : Op) -> String {
  op_symbol(self)
}

///|
pub extend Op with @debug.Debug::{to_repr}

///|
pub impl @debug.Debug for Op with fn to_repr(self : Op) -> @debug.Repr {
  @debug.Repr(op_symbol(self))
}

///|
pub extend Op with Eq::{equal, not_equal}

///|
pub impl Eq for Op with fn equal(self : Op, other : Op) -> Bool {
  match (self, other) {
    (Eq, Eq) | (Ne, Ne) | (Gt, Gt) | (Ge, Ge) | (Lt, Lt) | (Le, Le) => true
    _ => false
  }
}

///|
pub extend Comparator with Eq::{equal, not_equal}

///|
pub impl Eq for Comparator with fn equal(self : Comparator, other : Comparator) -> Bool {
  self.op == other.op && self.version == other.version
}

///|
pub extend ComparatorSet with Eq::{equal, not_equal}

///|
pub impl Eq for ComparatorSet with fn equal(
  self : ComparatorSet,
  other : ComparatorSet,
) -> Bool {
  self.comparators == other.comparators
}

///|
pub extend Range with Eq::{equal, not_equal}

///|
pub impl Eq for Range with fn equal(self : Range, other : Range) -> Bool {
  self.sets == other.sets && self.policy == other.policy
}

///|
pub extend Range with @json.ToJson::{to_json}

///|
pub impl @json.ToJson for Range with fn to_json(self : Range) -> Json {
  Json::string(self.to_string())
}

///|
pub extend Range with @json.FromJson::{from_json}

///|
pub impl @json.FromJson for Range with fn from_json(
  json : Json,
  path : @json.JsonPath,
) -> Range raise @json.JsonDecodeError {
  let s = if json is String(s) {
    s
  } else {
    raise @json.JsonDecodeError((path, "moonsver: a range must be a string"))
  }
  Range::parse(s) catch {
    e => raise @json.JsonDecodeError((path, "moonsver: " + e.to_string()))
  }
}
