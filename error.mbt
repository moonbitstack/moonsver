///|
/// Why a version or a range was refused, and where.
///
/// `at` is the zero-based character index of the first offending character, or
/// the input's length when it ended early; the message says what was expected.
pub(all) suberror Refused {
  // Empty input where the grammar wants a version or a range.
  Empty(at~ : Int32, String)
  // A character that does not belong where it stands.
  Unexpected(at~ : Int32, String)
  // The input ended partway through.
  Truncated(at~ : Int32, String)
  // A numeric component that is not a number.
  Number(at~ : Int32, String)
  // A numeric component, or a numeric prerelease identifier, with a leading zero
  // (SemVer 2.0.0 §2, §9).
  LeadingZero(at~ : Int32, String)
  // An empty identifier, as in `1.0.0-` or `1.0.0-a..b`.
  EmptyIdentifier(at~ : Int32, String)
  // An identifier with characters §9 and §10 do not allow.
  Identifier(at~ : Int32, String)
  // A spelling the chosen `Syntax` does not accept.
  Unsupported(at~ : Int32, String)
  // A range that does not hang together, such as a concrete part after a wildcard.
  Range(at~ : Int32, String)
} derive(Eq)

///|
pub extend Refused with Eq::{equal, not_equal}

///|
/// Where the input went wrong.
pub fn Refused::at(self : Refused) -> Int32 {
  match self {
    Empty(_, at~)
    | Unexpected(_, at~)
    | Truncated(_, at~)
    | Number(_, at~)
    | LeadingZero(_, at~)
    | EmptyIdentifier(_, at~)
    | Identifier(_, at~)
    | Unsupported(_, at~)
    | Range(_, at~) => at
  }
}

///|
/// What was wrong, in words.
pub fn Refused::message(self : Refused) -> String {
  match self {
    Empty(m, ..)
    | Unexpected(m, ..)
    | Truncated(m, ..)
    | Number(m, ..)
    | LeadingZero(m, ..)
    | EmptyIdentifier(m, ..)
    | Identifier(m, ..)
    | Unsupported(m, ..)
    | Range(m, ..) => m
  }
}

///|
pub impl Show for Refused with fn output(self, logger) {
  logger.write_string(self.message() + " (at " + self.at().to_string() + ")")
}

///|
pub extend Refused with Show::{to_string, output}

///|
pub impl @debug.Debug for Refused with fn to_repr(self) {
  @debug.Repr(self.to_string())
}

///|
pub extend Refused with @debug.Debug::{to_repr}

///|
/// The parser's own names for what went wrong, turned into a `Refused` by `fail`.
priv enum ErrorKind {
  EmptyInput
  UnexpectedChar
  UnexpectedEnd
  InvalidNumber
  LeadingZero
  EmptyIdentifier
  InvalidIdentifier
  UnsupportedSyntax
  InvalidRange
}

///|
/// Raise a refusal. The generic return type lets it sit in a `match` arm.
fn[T] fail(
  kind : ErrorKind,
  message : String,
  position : Int32,
) -> T raise Refused {
  let at = position
  raise match kind {
    EmptyInput => Empty(at~, message)
    UnexpectedChar => Unexpected(at~, message)
    UnexpectedEnd => Truncated(at~, message)
    InvalidNumber => Number(at~, message)
    LeadingZero => Refused::LeadingZero(at~, message)
    EmptyIdentifier => Refused::EmptyIdentifier(at~, message)
    InvalidIdentifier => Identifier(at~, message)
    UnsupportedSyntax => Unsupported(at~, message)
    InvalidRange => Range(at~, message)
  }
}
