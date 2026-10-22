///|
/// What a parse came to, for the tests that look at a refusal.
priv enum Outcome[T] {
  Parsed(T)
  Failed(@moonsver.Refused)
}

///|
fn[T] attempt(f : () -> T raise @moonsver.Refused) -> Outcome[T] {
  try f() catch {
    e => Failed(e)
  } noraise {
    v => Parsed(v)
  }
}
