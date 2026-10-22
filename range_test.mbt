///|
fn range_ok(
  s : String,
  syntax~ : @moonsver.Syntax = @moonsver.Syntax::npm(),
) -> @moonsver.Range raise {
  match @moonsver.Range::parse(s, syntax~) {
    Ok(r) => r
    Err(e) => fail("expected a clean parse, got \{e} for \{s}")
  }
}

///|
fn range_err(
  s : String,
  syntax~ : @moonsver.Syntax = @moonsver.Syntax::npm(),
) -> Unit raise {
  match @moonsver.Range::parse(s, syntax~) {
    Ok(r) => fail("expected \{s} to be rejected, got \{r}")
    Err(_) => ()
  }
}

///|
/// Check the canonical text, and that it re-parses to the same range.
fn expect_range(
  s : String,
  want : String,
  syntax~ : @moonsver.Syntax = @moonsver.Syntax::npm(),
) -> Unit raise {
  let r = range_ok(s, syntax~)
  assert_eq(r.to_string(), want, msg="canonical text for \{s}")
  let again = range_ok(r.to_string(), syntax~)
  assert_eq(again.to_string(), want, msg="normalising should be idempotent")
}

///|
fn sat(
  version : String,
  range : String,
  syntax~ : @moonsver.Syntax = @moonsver.Syntax::npm(),
) -> Bool raise {
  match @moonsver.satisfies(version, range, syntax~) {
    Ok(b) => b
    Err(e) =>
      fail("satisfaction check failed: \{version} against \{range}: \{e}")
  }
}

///|
test "range: npm caret" {
  expect_range("^1.2.3", ">=1.2.3, <2.0.0")
  expect_range("^1.2", ">=1.2.0, <2.0.0")
  expect_range("^1", ">=1.0.0, <2.0.0")
  expect_range("^0.2.3", ">=0.2.3, <0.3.0")
  expect_range("^0.2", ">=0.2.0, <0.3.0")
  expect_range("^0.0.3", ">=0.0.3, <0.0.4")
  expect_range("^0.0", ">=0.0.0, <0.1.0")
  expect_range("^0", ">=0.0.0, <1.0.0")
  expect_range("^0.0.0", ">=0.0.0, <0.0.1")
  expect_range("^1.2.3-beta.2", ">=1.2.3-beta.2, <2.0.0")
}

///|
test "range: npm tilde" {
  expect_range("~1.2.3", ">=1.2.3, <1.3.0")
  expect_range("~1.2", ">=1.2.0, <1.3.0")
  expect_range("~1", ">=1.0.0, <2.0.0")
  expect_range("~0.0.1", ">=0.0.1, <0.1.0")
  expect_range("~0.2.3", ">=0.2.3, <0.3.0")
}

///|
test "range: npm exact and shorthand" {
  expect_range("1.2.3", "=1.2.3")
  expect_range("=1.2.3", "=1.2.3")
  expect_range("v1.2.3", "=1.2.3")
  expect_range("1.2", ">=1.2.0, <1.3.0")
  expect_range("1", ">=1.0.0, <2.0.0")
  expect_range("1.x", ">=1.0.0, <2.0.0")
  expect_range("1.2.x", ">=1.2.0, <1.3.0")
  expect_range("1.2.*", ">=1.2.0, <1.3.0")
  expect_range("1.2.X", ">=1.2.0, <1.3.0")
  expect_range("*", "*")
  expect_range("", "*")
  expect_range(">=1.2.3+build", ">=1.2.3")
}

///|
test "range: npm comparators with wildcards" {
  expect_range(">1", ">=2.0.0")
  expect_range(">=1", ">=1.0.0")
  expect_range("<1", "<1.0.0")
  expect_range("<=1", "<2.0.0")
  expect_range(">1.2", ">=1.3.0")
  expect_range(">=1.2", ">=1.2.0")
  expect_range("<1.2", "<1.2.0")
  expect_range("<=1.2", "<1.3.0")
}

///|
test "range: npm hyphen ranges" {
  expect_range("1.2.3 - 2.3.4", ">=1.2.3, <=2.3.4")
  expect_range("1.2 - 2.3.4", ">=1.2.0, <=2.3.4")
  expect_range("1.2.3 - 2.3", ">=1.2.3, <2.4.0")
  expect_range("1.2.3 - 2", ">=1.2.3, <3.0.0")
  expect_range("1.2.3-alpha - 2.0.0", ">=1.2.3-alpha, <=2.0.0")
}

///|
test "range: npm conjunction and disjunction" {
  expect_range(">=1.2.3 <2.0.0", ">=1.2.3, <2.0.0")
  expect_range(">=1.2.3, <2.0.0", ">=1.2.3, <2.0.0")
  expect_range("1.2.3 || 2.0.0", "=1.2.3 || =2.0.0")
  expect_range("^1 || ^2", ">=1.0.0, <2.0.0 || >=2.0.0, <3.0.0")
  expect_range("  1.2.3   ||   2.0.0  ", "=1.2.3 || =2.0.0")
}

///|
test "range: Cargo grammar" {
  let cargo = @moonsver.Syntax::cargo()
  // a bare version carries a caret
  expect_range("1.2.3", ">=1.2.3, <2.0.0", syntax=cargo)
  expect_range("1.2", ">=1.2.0, <2.0.0", syntax=cargo)
  expect_range("0.2", ">=0.2.0, <0.3.0", syntax=cargo)
  expect_range("1.*", ">=1.0.0, <2.0.0", syntax=cargo)
  expect_range("1.2.*", ">=1.2.0, <1.3.0", syntax=cargo)
  expect_range("~1.2", ">=1.2.0, <1.3.0", syntax=cargo)
  expect_range(">=1.2, <1.5", ">=1.2.0, <1.5.0", syntax=cargo)
  // no ||, hyphen ranges, v prefix or empty input
  range_err("^1 || ^2", syntax=cargo)
  range_err("1.2.3 - 2.0.0", syntax=cargo)
  range_err("v1.2.3", syntax=cargo)
  range_err("", syntax=cargo)
}

///|
test "range: Ruby grammar" {
  let ruby = @moonsver.Syntax::ruby()
  // ~> drops the last segment, then bumps
  expect_range("~> 1.2", ">=1.2.0, <2.0.0", syntax=ruby)
  expect_range("~> 1.2.3", ">=1.2.3, <1.3.0", syntax=ruby)
  expect_range("~> 1", ">=1.0.0, <2.0.0", syntax=ruby)
  expect_range("!= 1.2.3", "!=1.2.3", syntax=ruby)
  range_err("^1.2.3", syntax=ruby)
  range_err("1.2", syntax=ruby)
  range_err("1.2.3 || 2.0.0", syntax=ruby)
}

///|
test "range: strict takes comparators only" {
  let strict = @moonsver.Syntax::strict()
  expect_range(">=1.2.3, <2.0.0", ">=1.2.3, <2.0.0", syntax=strict)
  expect_range("*", "*", syntax=strict)
  range_err("^1.2.3", syntax=strict)
  range_err("~1.2.3", syntax=strict)
  range_err("1.2", syntax=strict)
  range_err("1.2.3 - 2.0.0", syntax=strict)
  range_err("1.2.3 || 2.0.0", syntax=strict)
  range_err("", syntax=strict)
}

///|
test "range: matching prereleases" {
  // npm and Cargo: only through a comparator with the same tuple and a prerelease
  assert_false(sat("1.2.3-beta", "^1.2.3"))
  assert_true(sat("1.2.3-beta", "^1.2.3-alpha"))
  assert_true(sat("1.2.3-beta.4", ">=1.2.3-alpha"))
  assert_false(sat("1.2.4-beta", ">=1.2.3-alpha"))
  assert_false(sat("1.2.3-beta", "*"))
  assert_false(sat("1.2.3-beta", ""))
  assert_true(sat("1.2.3", "*"))
  assert_true(sat("1.2.3", ">=1.2.3-alpha"))
}

///|
test "range: prerelease policy" {
  let r = range_ok(">=1.0.0")
  let beta = parse_ok("1.5.0-beta")
  let stable = parse_ok("1.5.0")
  // SameTuple by default
  assert_false(r.satisfies(beta))
  assert_true(r.satisfies(stable))
  // includePrerelease
  assert_true(r.satisfies_with(beta, @moonsver.Always))
  // stable only
  assert_true(r.satisfies_with(stable, @moonsver.Never))
  assert_false(r.satisfies_with(beta, @moonsver.Never))
  // the policy follows the grammar used to parse
  let r2 = range_ok(">=1.0.0", syntax=@moonsver.Syntax::npm())
  assert_eq(r2.policy(), @moonsver.SameTuple)
}

///|
test "range: satisfaction cases" {
  assert_true(sat("1.2.3", "^1.2.0"))
  assert_false(sat("2.0.0", "^1.2.0"))
  assert_true(sat("1.9.9", "1.2.3 - 1.9.9"))
  assert_false(sat("2.0.0", "1.2.3 - 1.9.9"))
  assert_true(sat("1.2.3", "1.2.x"))
  assert_false(sat("1.3.0", "1.2.x"))
  assert_true(sat("3.0.0", "1.2.3 || 3.0.0"))
  assert_false(sat("0.0.4", "^0.0.3"))
  assert_true(sat("0.0.3", "^0.0.3"))
  assert_true(sat("0.0.9", "^0.0.3") == false)
  // in Cargo a bare version is a caret
  assert_true(sat("1.5.0", "1.2.3", syntax=@moonsver.Syntax::cargo()))
  assert_false(sat("2.0.0", "1.2.3", syntax=@moonsver.Syntax::cargo()))
  assert_false(sat("0.3.0", "0.2.3", syntax=@moonsver.Syntax::cargo()))
  // Ruby's pessimistic operator
  assert_true(sat("1.9.0", "~> 1.2", syntax=@moonsver.Syntax::ruby()))
  assert_false(sat("2.0.0", "~> 1.2", syntax=@moonsver.Syntax::ruby()))
}

///|
test "range: max, min and filtering" {
  let versions = [
    parse_ok("1.0.0"),
    parse_ok("1.2.0"),
    parse_ok("1.2.3"),
    parse_ok("1.2.4"),
    parse_ok("1.3.0"),
    parse_ok("2.0.0"),
    parse_ok("2.0.0-rc.1"),
  ]
  let r = range_ok("~1.2.0")
  assert_eq(r.max_satisfying(versions).unwrap().to_string(), "1.2.4")
  assert_eq(r.min_satisfying(versions).unwrap().to_string(), "1.2.0")
  let filtered = r.satisfying(versions)
  assert_eq(filtered.length(), 3)
  assert_eq(filtered[0].to_string(), "1.2.0")
  assert_eq(filtered[2].to_string(), "1.2.4")
  // nothing satisfies it
  assert_true(r.max_satisfying([parse_ok("3.0.0")]) is None)
  // prereleases are kept out
  let r2 = range_ok(">=1.0.0")
  assert_eq(
    r2
    .max_satisfying([parse_ok("1.0.0"), parse_ok("2.0.0-rc.1")])
    .unwrap()
    .to_string(),
    "1.0.0",
  )
}

///|
test "range: structural errors" {
  for s in ["1.2.3.4", "1.2.3 -", ">=", "^", "~", "1.x.3", "x.2"] {
    range_err(s)
  }
  // npm reads an empty side as "any version", so "||" is fine
  assert_true(range_ok("||").is_any())
  range_err("||", syntax=@moonsver.Syntax::strict())
  match @moonsver.Range::parse("1.2.3.4") {
    Ok(_) => fail("should have been rejected")
    Err(e) => assert_eq(e.kind(), @moonsver.InvalidRange)
  }
  match @moonsver.Range::parse("^1.2.3", syntax=@moonsver.Syntax::strict()) {
    Ok(_) => fail("should have been rejected")
    Err(e) => assert_eq(e.kind(), @moonsver.UnsupportedSyntax)
  }
}

///|
test "range: comparators and sets" {
  let r = range_ok("^1.2.3")
  assert_eq(r.sets().length(), 1)
  let set = r.sets()[0]
  assert_eq(set.comparators.length(), 2)
  assert_eq(set.comparators[0].op, @moonsver.Ge)
  assert_eq(set.comparators[0].version.to_string(), "1.2.3")
  assert_eq(set.comparators[1].op, @moonsver.Lt)
  assert_eq(set.comparators[1].version.to_string(), "2.0.0")
  // any range
  assert_true(range_ok("*").is_any())
  assert_false(r.is_any())
}
