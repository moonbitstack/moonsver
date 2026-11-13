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

///|
/// Replay the corpus generated in `conformance_vectors_test.mbt`. Its expectations come
/// from node-semver and the Rust semver crate, not from this library.

///|
fn accepts_version(text : String, syntax : @moonsver.Syntax) -> Bool {
  match attempt(() => @moonsver.Version::parse(text, syntax~)) {
    Parsed(_) => true
    Failed(_) => false
  }
}

///|
test "conformance: node-semver reads the same versions as the npm grammar" {
  for row in npm_version_cases() {
    let (text, want) = row
    assert_eq(
      accepts_version(text, @moonsver.Syntax::npm()),
      want,
      msg="npm grammar, \{text}",
    )
  }
}

///|
test "conformance: the strict grammar reads the same versions as the spec" {
  for row in strict_version_cases() {
    let (text, want) = row
    assert_eq(
      accepts_version(text, @moonsver.Syntax::strict()),
      want,
      msg="strict grammar, \{text}",
    )
  }
}

///|
test "conformance: precedence agrees with both references" {
  for row in precedence_cases() {
    let (a, b, want) = row
    let got = parse_ok(a).precedence_cmp(parse_ok(b))
    assert_eq(got, want, msg="\{a} against \{b}")
  }
}

///|
test "conformance: npm ranges match node-semver" {
  for group in npm_range_cases() {
    let (text, rows) = group
    let range = match attempt(() => @moonsver.Range::parse(text)) {
      Parsed(r) => r
      Failed(e) => fail("npm reads \{text} but the library refused it: \{e}")
    }
    for row in rows {
      let (version, want) = row
      assert_eq(
        range.satisfies(parse_ok(version)),
        want,
        msg="\{text} takes \{version}",
      )
    }
  }
  for text in npm_refused_ranges() {
    match attempt(() => @moonsver.Range::parse(text)) {
      Parsed(r) => fail("node-semver refuses \{text}, the library read \{r}")
      Failed(_) => ()
    }
  }
}

///|
test "conformance: Cargo requirements match the Rust crate" {
  let cargo = @moonsver.Syntax::cargo()
  for group in cargo_range_cases() {
    let (text, rows) = group
    let range = match
      attempt(() => @moonsver.Range::parse(text, syntax=cargo)) {
      Parsed(r) => r
      Failed(e) => fail("Cargo reads \{text} but the library refused it: \{e}")
    }
    for row in rows {
      let (version, want) = row
      assert_eq(
        range.satisfies(parse_ok(version)),
        want,
        msg="\{text} takes \{version}",
      )
    }
  }
  for text in cargo_refused_ranges() {
    match attempt(() => @moonsver.Range::parse(text, syntax=cargo)) {
      Parsed(r) => fail("Cargo refuses \{text}, the library read \{r}")
      Failed(_) => ()
    }
  }
}

///|
test "conformance: bumps match node-semver" {
  for row in bump_cases() {
    let (version, release, want) = row
    let bump = match attempt(() => @moonsver.Release::parse(release)) {
      Parsed(r) => r
      Failed(e) => fail("unknown release \{release}: \{e}")
    }
    let got = Some(parse_ok(version).inc(bump).to_string())
    assert_eq(got, want, msg="\{version}, \{release}")
  }
}

///|
/// The reference's own selection and ordering, over the same corpus.
test "conformance: highest, lowest and order match node-semver" {
  let pool : Array[@moonsver.Version] = []
  for text in range_versions() {
    pool.push(parse_ok(text))
  }
  for row in npm_extremes() {
    let (text, high, low, sorted_names) = row
    let range = match attempt(() => @moonsver.Range::parse(text)) {
      Parsed(r) => r
      Failed(e) => fail("npm reads \{text} but the library refused it: \{e}")
    }
    let got_high = match range.max_satisfying(pool) {
      Some(v) => v.to_string()
      None => "-"
    }
    let got_low = match range.min_satisfying(pool) {
      Some(v) => v.to_string()
      None => "-"
    }
    assert_eq(got_high, high, msg="highest for \{text}")
    assert_eq(got_low, low, msg="lowest for \{text}")
    let got : Array[String] = []
    for v in range.satisfying(pool) {
      got.push(v.to_string())
    }
    assert_eq(got, sorted_names, msg="sorted matches for \{text}")
  }
}
