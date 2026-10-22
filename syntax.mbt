///|
/// What a bare version means when no operator is given.
pub(all) enum DefaultOp {
  /// Exact: `1.2.3` means `=1.2.3`, which is how npm and Ruby read it.
  Exact
  /// Caret: `1.2.3` means `^1.2.3`, Cargo's default.
  Caret
  /// Tilde: `1.2.3` means `~1.2.3`.
  Tilde
}

///|
/// How `~` and `~>` work out their upper bound.
pub(all) enum TildeBump {
  /// npm and Cargo: bump the minor if one was written, otherwise bump the major.
  ///
  /// - `~1.2.3` → `>=1.2.3 <1.3.0`
  /// - `~1.2`   → `>=1.2.0 <1.3.0`
  /// - `~1`     → `>=1.0.0 <2.0.0`
  Patch
  /// Ruby's `~>`: drop the last segment, then bump whatever is left.
  ///
  /// - `~> 1.2.3` → `>=1.2.3 <1.3.0`
  /// - `~> 1.2`   → `>=1.2.0 <2.0.0`
  /// - `~> 1`     → `>=1.0.0 <2.0.0`
  LastSpecified
}

///|
/// How prereleases are matched against a range.
///
/// The spec only orders prereleases against each other; it says nothing about how a
/// range should treat them, so every ecosystem settled on its own convention.
pub(all) enum PrereleasePolicy {
  /// The npm and Cargo convention: a prerelease can only satisfy a set when some
  /// comparator carries a prerelease with the same `major.minor.patch`.
  ///
  /// So `>=1.2.3-alpha` takes `1.2.3-beta` but not `1.2.4-beta`, and `*` takes no
  /// prerelease at all.
  SameTuple
  /// Treat prereleases as ordinary versions (npm's `includePrerelease`).
  Always
  /// Prereleases never match anything, for when only stable releases will do.
  Never
}

///|
/// Range grammar settings.
///
/// A version has one spelling in SemVer 2.0.0, but ranges are not in the spec, and
/// npm, Cargo and RubyGems each wrote their own grammar. The differences are pulled
/// out as settings here: one parser, several grammars, the same idea as moonregex.
///
/// Switches that govern version literals:
/// - `allow_v_prefix`: accept `v1.2.3`
/// - `allow_equals_prefix`: accept `=1.2.3` as a version literal
/// - `allow_build_metadata`: accept a `+build` segment
/// - `trim`: allow whitespace around a version literal
///
/// Switches that govern range syntax:
/// - `default_op`: what a bare version means (npm `Exact`, Cargo `Caret`)
/// - `tilde_bump`: how `~` finds its upper bound (npm/Cargo `Patch`, Ruby `LastSpecified`)
/// - `allow_caret` / `allow_tilde`: accept `^` / `~` (`~>` only under `LastSpecified`)
/// - `allow_ne`: accept `!=`
/// - `allow_or`: accept `||`
/// - `allow_hyphen_range`: accept `1.2.3 - 2.0.0`
/// - `allow_xrange`: accept the shorthand forms `1.x`, `1.2.*` and bare `1.2`
/// - `allow_empty`: whether an empty string means "any version"
/// - `prerelease_policy`: how prereleases are matched
pub(all) struct Syntax {
  allow_v_prefix : Bool
  allow_equals_prefix : Bool
  allow_build_metadata : Bool
  trim : Bool
  default_op : DefaultOp
  tilde_bump : TildeBump
  allow_caret : Bool
  allow_tilde : Bool
  allow_ne : Bool
  allow_or : Bool
  allow_hyphen_range : Bool
  allow_xrange : Bool
  allow_empty : Bool
  prerelease_policy : PrereleasePolicy
}

///|
/// Strict SemVer 2.0.0 spelling: only `= > >= < <=`, joined by commas or spaces,
/// with no `^`, `~`, `||`, hyphen ranges, `1.x` shorthand or `v` prefix.
///
/// The one exception is `*`, which always means "any version": it is what
/// `Range::to_string` prints for an empty range, so refusing it would break the round trip.
pub fn Syntax::strict() -> Syntax {
  {
    allow_v_prefix: false,
    allow_equals_prefix: false,
    allow_build_metadata: true,
    trim: false,
    default_op: Exact,
    tilde_bump: Patch,
    allow_caret: false,
    allow_tilde: false,
    allow_ne: false,
    allow_or: false,
    allow_hyphen_range: false,
    allow_xrange: false,
    allow_empty: false,
    prerelease_policy: SameTuple,
  }
}

///|
/// npm (node-semver) grammar: a bare version is exact, with `^`, `~`, `||`, hyphen
/// ranges, `1.x` shorthand, a `v` prefix, and the empty string for "any".
pub fn Syntax::npm() -> Syntax {
  {
    allow_v_prefix: true,
    allow_equals_prefix: true,
    allow_build_metadata: true,
    trim: true,
    default_op: Exact,
    tilde_bump: Patch,
    allow_caret: true,
    allow_tilde: true,
    allow_ne: false,
    allow_or: true,
    allow_hyphen_range: true,
    allow_xrange: true,
    allow_empty: true,
    prerelease_policy: SameTuple,
  }
}

///|
/// Cargo grammar: a bare version carries a caret (`1.2.3` is `^1.2.3`), with `,` or
/// space for conjunctions and `*` / `1.*` wildcards; no `||`, no hyphen ranges, no `v`.
pub fn Syntax::cargo() -> Syntax {
  {
    allow_v_prefix: false,
    allow_equals_prefix: true,
    allow_build_metadata: true,
    trim: true,
    default_op: Caret,
    tilde_bump: Patch,
    allow_caret: true,
    allow_tilde: true,
    allow_ne: false,
    allow_or: false,
    allow_hyphen_range: false,
    allow_xrange: true,
    allow_empty: false,
    prerelease_policy: SameTuple,
  }
}

///|
/// RubyGems grammar: `~>` is the pessimistic operator (drop the last segment, then bump),
/// and `!=` is allowed; no `^`, `||`, hyphen ranges or shorthand.
pub fn Syntax::ruby() -> Syntax {
  {
    allow_v_prefix: false,
    allow_equals_prefix: true,
    allow_build_metadata: true,
    trim: true,
    default_op: Exact,
    tilde_bump: LastSpecified,
    allow_caret: false,
    allow_tilde: true,
    allow_ne: true,
    allow_or: false,
    allow_hyphen_range: false,
    allow_xrange: false,
    allow_empty: false,
    prerelease_policy: SameTuple,
  }
}

///|
/// The default grammar is npm's.
pub extend Syntax with Default::{default}

///|
pub impl Default for Syntax with fn default() -> Syntax {
  Syntax::npm()
}

///|
pub extend Syntax with Show::{to_string, output}

///|
pub impl Show for Syntax with fn to_string(self : Syntax) -> String {
  let sb = StringBuilder()
  sb.write_string("Syntax{")
  sb.write_string("default_op=")
  sb.write_string(
    match self.default_op {
      Exact => "exact"
      Caret => "caret"
      Tilde => "tilde"
    },
  )
  sb.write_string(", tilde_bump=")
  sb.write_string(
    match self.tilde_bump {
      Patch => "patch"
      LastSpecified => "last-specified"
    },
  )
  sb.write_string(", or=")
  sb.write_string(self.allow_or.to_string())
  sb.write_string(", hyphen=")
  sb.write_string(self.allow_hyphen_range.to_string())
  sb.write_string(", xrange=")
  sb.write_string(self.allow_xrange.to_string())
  sb.write_string(", prerelease=")
  sb.write_string(
    match self.prerelease_policy {
      SameTuple => "same-tuple"
      Always => "always"
      Never => "never"
    },
  )
  sb.write_string("}")
  sb.to_string()
}

///|
/// Look up a preset by name, for the CLI and config files.
pub fn Syntax::from_name(name : String) -> Syntax? {
  match name {
    "npm" => Some(Syntax::npm())
    "cargo" => Some(Syntax::cargo())
    "ruby" => Some(Syntax::ruby())
    "strict" | "semver" => Some(Syntax::strict())
    _ => None
  }
}

///|
/// The preset name for this syntax, or `None` for a custom mix.
pub fn Syntax::name(self : Syntax) -> String? {
  if self == Syntax::npm() {
    Some("npm")
  } else if self == Syntax::cargo() {
    Some("cargo")
  } else if self == Syntax::ruby() {
    Some("ruby")
  } else if self == Syntax::strict() {
    Some("strict")
  } else {
    None
  }
}

///|
pub extend Syntax with Eq::{equal, not_equal}

///|
pub impl Eq for Syntax with fn equal(self : Syntax, other : Syntax) -> Bool {
  self.allow_v_prefix == other.allow_v_prefix &&
  self.allow_equals_prefix == other.allow_equals_prefix &&
  self.allow_build_metadata == other.allow_build_metadata &&
  self.trim == other.trim &&
  self.default_op == other.default_op &&
  self.tilde_bump == other.tilde_bump &&
  self.allow_caret == other.allow_caret &&
  self.allow_tilde == other.allow_tilde &&
  self.allow_ne == other.allow_ne &&
  self.allow_or == other.allow_or &&
  self.allow_hyphen_range == other.allow_hyphen_range &&
  self.allow_xrange == other.allow_xrange &&
  self.allow_empty == other.allow_empty &&
  self.prerelease_policy == other.prerelease_policy
}

///|
pub extend DefaultOp with Eq::{equal, not_equal}

///|
pub impl Eq for DefaultOp with fn equal(self : DefaultOp, other : DefaultOp) -> Bool {
  match (self, other) {
    (Exact, Exact) | (Caret, Caret) | (Tilde, Tilde) => true
    _ => false
  }
}

///|
pub extend TildeBump with Eq::{equal, not_equal}

///|
pub impl Eq for TildeBump with fn equal(self : TildeBump, other : TildeBump) -> Bool {
  match (self, other) {
    (Patch, Patch) | (LastSpecified, LastSpecified) => true
    _ => false
  }
}

///|
pub extend PrereleasePolicy with @debug.Debug::{to_repr}

///|
pub impl @debug.Debug for PrereleasePolicy with fn to_repr(
  self : PrereleasePolicy,
) -> @debug.Repr {
  @debug.Repr(
    match self {
      SameTuple => "SameTuple"
      Always => "Always"
      Never => "Never"
    },
  )
}

///|
pub extend PrereleasePolicy with Eq::{equal, not_equal}

///|
pub impl Eq for PrereleasePolicy with fn equal(
  self : PrereleasePolicy,
  other : PrereleasePolicy,
) -> Bool {
  match (self, other) {
    (SameTuple, SameTuple) | (Always, Always) | (Never, Never) => true
    _ => false
  }
}
