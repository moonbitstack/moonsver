///|
/// Error categories. Callers can branch on these; `message` carries the detail.
pub(all) enum ErrorKind {
  /// Empty input where the grammar does not allow it.
  EmptyInput
  /// A character that does not belong here.
  UnexpectedChar
  /// Input ended early — the version was only half written.
  UnexpectedEnd
  /// A numeric component that is not a valid number.
  InvalidNumber
  /// A numeric component, or a numeric prerelease identifier, with a leading zero.
  LeadingZero
  /// An empty identifier, as in `1.0.0-` or `1.0.0-a..b`.
  EmptyIdentifier
  /// An identifier with illegal characters, or a prerelease identifier in the wrong place.
  InvalidIdentifier
  /// The current grammar (`Syntax`) does not allow this spelling.
  UnsupportedSyntax
  /// A malformed range, e.g. a concrete segment after a wildcard.
  InvalidRange
}

///|
/// A parse error: category, human-readable message and position.
///
/// `position` is the zero-based character index of the first offending character
/// (equal to the input length when the input ends early).
pub(all) struct SemverError {
  kind : ErrorKind
  message : String
  position : Int32
}

///|
pub fn SemverError::kind(self : SemverError) -> ErrorKind {
  self.kind
}

///|
pub fn SemverError::message(self : SemverError) -> String {
  self.message
}

///|
pub fn SemverError::position(self : SemverError) -> Int32 {
  self.position
}

///|
pub extend SemverError with Show::{to_string, output}

///|
pub impl Show for SemverError with fn to_string(self : SemverError) -> String {
  let sb = StringBuilder()
  sb.write_string(self.message)
  sb.write_string(" (at ")
  sb.write_string(self.position.to_string())
  sb.write_string(")")
  sb.to_string()
}

///|
pub extend SemverError with @debug.Debug::{to_repr}

///|
pub impl @debug.Debug for SemverError with fn to_repr(self : SemverError) -> @debug.Repr {
  @debug.Repr(self.to_string())
}

///|
pub extend SemverError with Eq::{equal, not_equal}

///|
pub impl Eq for SemverError with fn equal(
  self : SemverError,
  other : SemverError,
) -> Bool {
  self.kind == other.kind &&
  self.message == other.message &&
  self.position == other.position
}

///|
pub extend ErrorKind with @debug.Debug::{to_repr}

///|
pub impl @debug.Debug for ErrorKind with fn to_repr(self : ErrorKind) -> @debug.Repr {
  @debug.Repr(
    match self {
      EmptyInput => "EmptyInput"
      UnexpectedChar => "UnexpectedChar"
      UnexpectedEnd => "UnexpectedEnd"
      InvalidNumber => "InvalidNumber"
      LeadingZero => "LeadingZero"
      EmptyIdentifier => "EmptyIdentifier"
      InvalidIdentifier => "InvalidIdentifier"
      UnsupportedSyntax => "UnsupportedSyntax"
      InvalidRange => "InvalidRange"
    },
  )
}

///|
pub extend ErrorKind with Eq::{equal, not_equal}

///|
pub impl Eq for ErrorKind with fn equal(self : ErrorKind, other : ErrorKind) -> Bool {
  match (self, other) {
    (EmptyInput, EmptyInput)
    | (UnexpectedChar, UnexpectedChar)
    | (UnexpectedEnd, UnexpectedEnd)
    | (InvalidNumber, InvalidNumber)
    | (LeadingZero, LeadingZero)
    | (EmptyIdentifier, EmptyIdentifier)
    | (InvalidIdentifier, InvalidIdentifier)
    | (UnsupportedSyntax, UnsupportedSyntax)
    | (InvalidRange, InvalidRange) => true
    _ => false
  }
}

///|
/// Internal error channel: the parser raises all the way through, and the public
/// API turns that into `Result` at the boundary so the parser stays linear.
priv suberror ParseFail {
  ParseFail(SemverError)
}

///|
/// Raise a parse error. The generic return type lets it sit in a `match` arm.
fn[T] fail(
  kind : ErrorKind,
  message : String,
  position : Int32,
) -> T raise ParseFail {
  raise ParseFail({ kind, message, position, })
}
