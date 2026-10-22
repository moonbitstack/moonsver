///|
/// Satisfaction cases aligned with the node-semver and Cargo test suites.
test "conformance: npm edge cases" {
  // exact matches and comparators
  assert_true(sat("1.2.3", "1.2.3"))
  assert_true(sat("1.2.3", "=1.2.3"))
  assert_true(sat("1.2.3", "v1.2.3"))
  assert_true(sat("1.2.3", ">=1.2.3"))
  assert_true(sat("1.2.3", ">1.2.2"))
  assert_false(sat("1.2.3", "<1.2.3"))
  assert_true(sat("1.2.2", "<1.2.3"))
  // a stable release against a prerelease lower bound
  assert_true(sat("1.2.3", ">=1.2.3-alpha"))
  assert_true(sat("1.2.3-alpha", ">=1.2.3-alpha"))
  assert_true(sat("1.2.3-alpha.1", ">=1.2.3-alpha"))
  assert_false(sat("1.2.4-alpha", ">=1.2.3-alpha"))
  // exact prerelease matches
  assert_true(sat("1.2.3-beta", "1.2.3-beta"))
  assert_false(sat("1.2.3-beta.2", "1.2.3-beta"))
  assert_false(sat("1.2.3-beta", ">=1.2.3-beta.1"))
  // caret on 0.x
  assert_true(sat("0.2.5", "^0.2.3"))
  assert_false(sat("0.3.0", "^0.2.3"))
  assert_false(sat("1.0.0", "^0.2.3"))
  assert_true(sat("0.0.3", "^0.0.3"))
  assert_false(sat("0.0.4", "^0.0.3"))
}

///|
test "conformance: Cargo edge cases" {
  let cargo = @moonsver.Syntax::cargo()
  assert_true(sat("0.2.5", "0.2.3", syntax=cargo))
  assert_false(sat("0.3.0", "0.2.3", syntax=cargo))
  assert_true(sat("1.9.9", "1.2.3", syntax=cargo))
  assert_false(sat("2.0.0", "1.2.3", syntax=cargo))
  assert_true(sat("1.5.0", ">=1.2, <1.5.1", syntax=cargo))
  assert_false(sat("1.5.1", ">=1.2, <1.5.1", syntax=cargo))
  assert_true(sat("0.0.9", "0.*", syntax=cargo))
  assert_false(sat("1.0.0", "0.*", syntax=cargo))
  // prereleases are held to the same tuple
  assert_false(sat("1.2.4-alpha", ">=1.2.3-alpha", syntax=cargo))
  assert_true(sat("1.2.3-alpha.2", ">=1.2.3-alpha.1", syntax=cargo))
}

///|
test "conformance: parse and print round-trip" {
  let samples = [
    "0.0.0", "1.0.0", "1.2.3", "1.2.3-0", "1.2.3-alpha", "1.2.3-alpha.0", "1.2.3-alpha.beta.gamma",
    "1.2.3-0.1.2", "1.2.3-x-y-z", "1.2.3+build", "1.2.3+build.1.2", "1.2.3-rc.1+build.5",
    "1234567890.0.0",
  ]
  for s in samples {
    let v = parse_ok(s)
    assert_eq(v.to_string(), s, msg="round-trip for \{s}")
    // the canonical text must parse back to the same value
    assert_true(parse_ok(v.to_string()) == v)
  }
}

///|
test "conformance: canonical ranges parse back" {
  let samples = [
    "^1.2.3", "~1.2.3", "1.2.x", "1.2.3 - 2.0.0", ">=1.2.3 <2.0.0", "1.2.3 || >=2.0.0 <3.0.0",
    "*", ">1.2", "<=0.9", "~0.0.1", "^0.0.3",
  ]
  for s in samples {
    let r = range_ok(s)
    let again = range_ok(r.to_string())
    assert_eq(again.to_string(), r.to_string(), msg="round-trip for \{s}")
  }
}

///|
test "conformance: arbitrary-precision numeric identifiers" {
  let big = "18446744073709551616000000000000000001"
  let small = "18446744073709551616000000000000000000"
  let a = parse_ok("1.0.0-\{small}")
  let b = parse_ok("1.0.0-\{big}")
  assert_true(a.precedence_cmp(b) < 0)
  assert_eq(b.to_string(), "1.0.0-\{big}")
}

///|
test "conformance: empty and any ranges" {
  let any = range_ok("*")
  assert_true(any.is_any())
  assert_true(range_ok("").is_any())
  assert_true(any.satisfies(parse_ok("0.0.0")))
  assert_true(any.satisfies(parse_ok("99999999999999999999.0.0")))
  assert_false(any.satisfies(parse_ok("1.0.0-alpha")))
}
