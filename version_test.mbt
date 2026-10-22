///|
/// Unwrap a successful parse, or fail the test with the reason.
fn parse_ok(
  s : String,
  syntax~ : @moonsver.Syntax = @moonsver.Syntax::npm(),
) -> @moonsver.Version raise {
  match @moonsver.Version::parse(s, syntax~) {
    Ok(v) => v
    Err(e) => fail("expected a clean parse, got \{e} for \{s}")
  }
}

///|
fn parse_err(
  s : String,
  syntax~ : @moonsver.Syntax = @moonsver.Syntax::npm(),
) -> Unit raise {
  match @moonsver.Version::parse(s, syntax~) {
    Ok(v) => fail("expected \{s} to be rejected, got \{v}")
    Err(_) => ()
  }
}

///|
fn roundtrip(
  s : String,
  syntax~ : @moonsver.Syntax = @moonsver.Syntax::npm(),
) -> Unit raise {
  let v = parse_ok(s, syntax~)
  assert_eq(v.to_string(), s)
}

///|
test "version: valid examples from the spec" {
  for
    s in [
      "0.0.0", "1.2.3", "10.20.30", "1.0.0-alpha", "1.0.0-alpha.1", "1.0.0-0.3.7",
      "1.0.0-x.7.z.92", "1.0.0-x-y-z.--", "1.0.0+20130313144700", "1.0.0-beta+exp.sha.5114f85",
      "1.0.0+21AF26D3---117B344092BD", "1.0.0-alpha+001", "1.0.0-rc.1+build.1",
    ] {
    roundtrip(s)
  }
}

///|
test "version: invalid examples from the spec" {
  for
    s in [
      "", "1", "1.2", "1.2.3.4", "01.2.3", "1.02.3", "1.2.03", "1.2.3-01", "1.2.3-",
      "1.2.3+", "1.2.3-+", "1.2.3-a..b", "1.2.3+a..b", "-1.2.3", "1.2.3-α", "1.2.3-a b",
      "1.2.3+a b", "a.b.c", "1.2.3-", "v1.2.3",
    ] {
    parse_err(s, syntax=@moonsver.Syntax::strict())
  }
}

///|
test "version: where leading zeroes are refused" {
  // neither a numeric component nor a numeric prerelease may carry one
  parse_err("01.0.0")
  parse_err("0.01.0")
  parse_err("0.0.01")
  parse_err("1.0.0-01")
  // build metadata may
  roundtrip("1.0.0+001")
  roundtrip("1.0.0+20130313144700")
}

///|
test "version: npm takes a v prefix and whitespace" {
  assert_eq(parse_ok("v1.2.3").to_string(), "1.2.3")
  assert_eq(parse_ok("V1.2.3").to_string(), "1.2.3")
  assert_eq(parse_ok("=1.2.3").to_string(), "1.2.3")
  assert_eq(parse_ok("  1.2.3  ").to_string(), "1.2.3")
  // the strict grammar does not
  parse_err("v1.2.3", syntax=@moonsver.Syntax::strict())
  parse_err(" 1.2.3", syntax=@moonsver.Syntax::strict())
}

///|
test "version: arbitrary-precision numbers" {
  let big = "99999999999999999999999999999999999999"
  let v = parse_ok("\{big}.0.0")
  assert_eq(v.to_string(), "\{big}.0.0")
  // one past u64::MAX
  let a = parse_ok("18446744073709551616.0.0")
  let b = parse_ok("18446744073709551615.0.0")
  assert_eq(a.precedence_cmp(b), 1)
}

///|
test "version: the §11 precedence chain" {
  let chain = [
    "1.0.0-alpha", "1.0.0-alpha.1", "1.0.0-alpha.beta", "1.0.0-beta", "1.0.0-beta.2",
    "1.0.0-beta.11", "1.0.0-rc.1", "1.0.0",
  ]
  let n = chain.length() - 1
  for i in 0..<n {
    let lo = parse_ok(chain[i])
    let hi = parse_ok(chain[i + 1])
    assert_true(
      lo.precedence_cmp(hi) < 0,
      msg="\{chain[i]} should rank below \{chain[i + 1]}",
    )
    assert_true(hi.precedence_cmp(lo) > 0)
    assert_true(lo.precedence_cmp(lo) == 0)
  }
}

///|
test "version: numeric identifiers rank below alphanumeric ones" {
  assert_true(parse_ok("1.0.0-1").precedence_cmp(parse_ok("1.0.0-a")) < 0)
  assert_true(parse_ok("1.0.0-2").precedence_cmp(parse_ok("1.0.0-10")) < 0)
  assert_true(parse_ok("1.0.0-10").precedence_cmp(parse_ok("1.0.0-a")) < 0)
  // alphanumeric ones compare in ASCII order
  assert_true(parse_ok("1.0.0-A").precedence_cmp(parse_ok("1.0.0-a")) < 0)
  assert_true(
    parse_ok("1.0.0-alpha").precedence_cmp(parse_ok("1.0.0-alpha.1")) < 0,
  )
}

///|
test "version: build metadata stays out of precedence" {
  let a = parse_ok("1.0.0+a")
  let b = parse_ok("1.0.0+b")
  assert_eq(a.precedence_cmp(b), 0)
  // yet they are not equal
  assert_true(a != b)
  // the total order still puts one first
  assert_true(a.compare(b) < 0)
  // prerelease plus build metadata
  assert_eq(
    parse_ok("1.0.0-alpha+a").precedence_cmp(parse_ok("1.0.0-alpha+b")),
    0,
  )
}

///|
test "version: comparing the numbers" {
  assert_true(parse_ok("1.0.0").precedence_cmp(parse_ok("2.0.0")) < 0)
  assert_true(parse_ok("2.1.0").precedence_cmp(parse_ok("2.1.1")) < 0)
  assert_true(parse_ok("1.0.0").precedence_cmp(parse_ok("1.0.1")) < 0)
  assert_true(parse_ok("1.10.0").precedence_cmp(parse_ok("1.9.0")) > 0)
}

///|
test "version: sorting" {
  let versions = [
    parse_ok("1.0.0"),
    parse_ok("1.0.0-rc.1"),
    parse_ok("1.0.0-alpha"),
    parse_ok("2.0.0"),
    parse_ok("0.9.0"),
    parse_ok("1.0.0-beta.11"),
    parse_ok("1.0.0-beta.2"),
  ]
  versions.sort()
  let got : Array[String] = []
  for v in versions {
    got.push(v.to_string())
  }
  assert_eq(
    got.join(","),
    "0.9.0,1.0.0-alpha,1.0.0-beta.2,1.0.0-beta.11,1.0.0-rc.1,1.0.0,2.0.0",
  )
}

///|
test "version: accessors" {
  let v = parse_ok("1.2.3-alpha.1+build.9")
  assert_eq(v.major().to_string(), "1")
  assert_eq(v.minor().to_string(), "2")
  assert_eq(v.patch().to_string(), "3")
  assert_eq(v.core_string(), "1.2.3")
  assert_true(v.is_prerelease())
  assert_true(!v.is_stable())
  assert_eq(v.prerelease().length(), 2)
  assert_eq(v.build().length(), 2)
  assert_true(v.same_core(parse_ok("1.2.3")))
  assert_true(!v.same_core(parse_ok("1.2.4")))
  assert_eq(v.core().to_string(), "1.2.3")
  assert_true(parse_ok("1.2.3").is_stable())
}

///|
test "version: error kinds and positions" {
  match @moonsver.Version::parse("1.02.3") {
    Ok(_) => fail("should have been rejected")
    Err(e) => {
      assert_eq(e.kind(), @moonsver.LeadingZero)
      assert_eq(e.position(), 2)
    }
  }
  match @moonsver.Version::parse("1.2.3-") {
    Ok(_) => fail("should have been rejected")
    Err(e) => assert_eq(e.kind(), @moonsver.EmptyIdentifier)
  }
  match @moonsver.Version::parse("1.2") {
    Ok(_) => fail("should have been rejected")
    Err(e) => assert_eq(e.kind(), @moonsver.UnexpectedEnd)
  }
  match @moonsver.Version::parse("1.2.3.4") {
    Ok(_) => fail("should have been rejected")
    Err(e) => assert_eq(e.position(), 5)
  }
}

///|
test "version: equality and hashing" {
  let a = parse_ok("1.2.3-alpha+build")
  let b = parse_ok("1.2.3-alpha+build")
  let c = parse_ok("1.2.3-alpha+other")
  assert_true(a == b)
  assert_true(a != c)
  assert_eq(a.hash(), b.hash())
}
