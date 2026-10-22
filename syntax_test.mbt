///|
test "syntax: preset names round-trip" {
  for name in ["npm", "cargo", "ruby", "strict"] {
    let s = @moonsver.Syntax::from_name(name).unwrap()
    assert_eq(s.name().unwrap(), name)
  }
  match @moonsver.Syntax::from_name("semver") {
    Some(s) => assert_true(s == @moonsver.Syntax::strict())
    None => fail("semver should map to strict")
  }
  assert_true(@moonsver.Syntax::from_name("pnpm") is None)
  assert_true(@moonsver.Syntax::from_name("") is None)
}

///|
test "syntax: npm is the default" {
  let d : @moonsver.Syntax = Default::default()
  assert_true(d == @moonsver.Syntax::npm())
}

///|
test "syntax: where the presets differ" {
  let npm = @moonsver.Syntax::npm()
  let cargo = @moonsver.Syntax::cargo()
  let ruby = @moonsver.Syntax::ruby()
  let strict = @moonsver.Syntax::strict()
  // bare version semantics
  assert_true(npm.default_op == @moonsver.Exact)
  assert_true(cargo.default_op == @moonsver.Caret)
  assert_true(ruby.default_op == @moonsver.Exact)
  // tilde upper bound
  assert_true(npm.tilde_bump == @moonsver.Patch)
  assert_true(ruby.tilde_bump == @moonsver.LastSpecified)
  // sugar switches
  assert_true(npm.allow_or && npm.allow_hyphen_range && npm.allow_xrange)
  assert_true(
    !cargo.allow_or && !cargo.allow_hyphen_range && cargo.allow_xrange,
  )
  assert_true(!ruby.allow_caret && ruby.allow_ne)
  assert_true(!strict.allow_caret && !strict.allow_or && !strict.allow_xrange)
  // every preset is distinct
  assert_true(npm != cargo && cargo != ruby && ruby != strict)
}

///|
test "syntax: one string, three readings" {
  // "1.2.3": exact in npm, a caret in Cargo
  assert_eq(
    range_ok("1.2.3", syntax=@moonsver.Syntax::npm()).to_string(),
    "=1.2.3",
  )
  assert_eq(
    range_ok("1.2.3", syntax=@moonsver.Syntax::cargo()).to_string(),
    ">=1.2.3, <2.0.0",
  )
  // "~1.2": npm bumps the minor, Ruby's ~> the major
  assert_eq(
    range_ok("~1.2", syntax=@moonsver.Syntax::npm()).to_string(),
    ">=1.2.0, <1.3.0",
  )
  assert_eq(
    range_ok("~> 1.2", syntax=@moonsver.Syntax::ruby()).to_string(),
    ">=1.2.0, <2.0.0",
  )
}

///|
test "syntax: Show gives a readable summary" {
  let s = @moonsver.Syntax::cargo().to_string()
  assert_true(s.contains("default_op=caret"))
  assert_true(s.contains("or=false"))
  assert_true(s.contains("prerelease=same-tuple"))
}
