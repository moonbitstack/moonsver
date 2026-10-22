///|
/// A version identifier.
///
/// SemVer 2.0.0 allows two kinds of identifier: all digits, or a string drawn from
/// `[0-9A-Za-z-]`. Numeric ones are held as arbitrary-precision integers, so a value
/// such as `18446744073709551616` does not overflow.
pub(all) enum Identifier {
  /// A numeric identifier, normalised to carry no leading zeroes.
  Num(@bigint.BigInt)
  /// An alphanumeric identifier, kept verbatim.
  Alpha(String)
}

///|
pub fn Identifier::is_numeric(self : Identifier) -> Bool {
  match self {
    Num(_) => true
    Alpha(_) => false
  }
}

///|
/// The integer value, or `None` for an alphanumeric identifier.
pub fn Identifier::as_bigint(self : Identifier) -> @bigint.BigInt? {
  match self {
    Num(n) => Some(n)
    Alpha(_) => None
  }
}

///|
/// The value as an `Int`, or `None` if it is alphanumeric or out of range.
pub fn Identifier::as_int(self : Identifier) -> Int32? {
  match self {
    Num(n) =>
      if n.compare_int(2147483647) <= 0 && n.compare_int(0) >= 0 {
        Some(n.to_int())
      } else {
        None
      }
    Alpha(_) => None
  }
}

///|
pub fn Identifier::numeric(n : Int32) -> Identifier {
  Num(@bigint.BigInt::from_int(n))
}

///|
pub fn Identifier::alpha(s : String) -> Identifier {
  Alpha(s)
}

///|
pub extend Identifier with Show::{to_string, output}

///|
pub impl Show for Identifier with fn to_string(self : Identifier) -> String {
  match self {
    Num(n) => n.to_string()
    Alpha(s) => s
  }
}

///|
pub extend Identifier with @debug.Debug::{to_repr}

///|
pub impl @debug.Debug for Identifier with fn to_repr(self : Identifier) -> @debug.Repr {
  @debug.Repr(self.to_string())
}

///|
pub extend Identifier with Eq::{equal, not_equal}

///|
pub impl Eq for Identifier with fn equal(self : Identifier, other : Identifier) -> Bool {
  match (self, other) {
    (Num(a), Num(b)) => a == b
    (Alpha(a), Alpha(b)) => a == b
    _ => false
  }
}

///|
pub extend Identifier with Compare::{compare, op_lt, op_le, op_gt, op_ge}

///|
/// Precedence rules for prerelease identifiers (SemVer 2.0.0 §11.4):
///
/// 1. numeric identifiers compare numerically;
/// 2. numeric identifiers always rank below alphanumeric ones;
/// 3. alphanumeric identifiers compare in ASCII sort order.
pub impl Compare for Identifier with fn compare(
  self : Identifier,
  other : Identifier,
) -> Int32 {
  match (self, other) {
    (Num(a), Num(b)) => a.compare(b)
    (Num(_), Alpha(_)) => -1
    (Alpha(_), Num(_)) => 1
    (Alpha(a), Alpha(b)) => a.lexical_compare(b)
  }
}

///|
pub extend Identifier with Hash::{hash_combine, hash}

///|
pub impl Hash for Identifier with fn hash_combine(
  self : Identifier,
  hasher : Hasher,
) -> Unit {
  hasher.combine_string(self.to_string())
}

///|
fn compare_identifiers(a : Array[Identifier], b : Array[Identifier]) -> Int32 {
  if a.is_empty() && b.is_empty() {
    return 0
  }
  if a.is_empty() {
    return 1
  }
  if b.is_empty() {
    return -1
  }
  let n = if a.length() < b.length() { a.length() } else { b.length() }
  for i in 0..<n {
    let c = a[i].compare(b[i])
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
