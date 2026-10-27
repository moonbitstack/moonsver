///|
test "bump: ordinary increments" {
  let v = parse_ok("1.2.3")
  assert_eq(v.inc(@moonsver.Major).to_string(), "2.0.0")
  assert_eq(v.inc(@moonsver.Minor).to_string(), "1.3.0")
  assert_eq(v.inc(@moonsver.Patch).to_string(), "1.2.4")
  assert_eq(v.inc(@moonsver.PreMajor).to_string(), "2.0.0-0")
  assert_eq(v.inc(@moonsver.PreMinor).to_string(), "1.3.0-0")
  assert_eq(v.inc(@moonsver.PrePatch).to_string(), "1.2.4-0")
  assert_eq(v.inc(@moonsver.Prerelease).to_string(), "1.2.4-0")
}

///|
test "bump: the special rules for prereleases" {
  // major and minor only move once they are already past zero
  assert_eq(parse_ok("1.0.0-pre").inc(@moonsver.Major).to_string(), "1.0.0")
  assert_eq(parse_ok("1.2.0-pre").inc(@moonsver.Major).to_string(), "2.0.0")
  assert_eq(parse_ok("1.2.0-pre").inc(@moonsver.Minor).to_string(), "1.2.0")
  assert_eq(parse_ok("1.2.3-pre").inc(@moonsver.Minor).to_string(), "1.3.0")
  // patch on a prerelease only drops the prerelease
  assert_eq(parse_ok("1.2.3-pre").inc(@moonsver.Patch).to_string(), "1.2.3")
}

///|
test "bump: incrementing prerelease identifiers" {
  assert_eq(
    parse_ok("1.2.3-alpha").inc(@moonsver.Prerelease).to_string(),
    "1.2.3-alpha.0",
  )
  assert_eq(
    parse_ok("1.2.3-alpha.1").inc(@moonsver.Prerelease).to_string(),
    "1.2.3-alpha.2",
  )
  assert_eq(
    parse_ok("1.2.3-1").inc(@moonsver.Prerelease).to_string(),
    "1.2.3-2",
  )
  // the last numeric identifier is the one that moves
  assert_eq(
    parse_ok("1.2.3-alpha.1.2").inc(@moonsver.Prerelease).to_string(),
    "1.2.3-alpha.1.3",
  )
  assert_eq(
    parse_ok("1.2.3-alpha.beta").inc(@moonsver.Prerelease).to_string(),
    "1.2.3-alpha.beta.0",
  )
  assert_eq(
    parse_ok("1.2.3-0").inc(@moonsver.Prerelease).to_string(),
    "1.2.3-1",
  )
}

///|
test "bump: build metadata is dropped" {
  assert_eq(parse_ok("1.2.3+build.9").inc(@moonsver.Patch).to_string(), "1.2.4")
  assert_eq(
    parse_ok("1.2.3-rc.1+build.9").inc(@moonsver.Stable).to_string(),
    "1.2.3",
  )
}

///|
test "bump: parsing bump names" {
  assert_true(@moonsver.Release::parse("major") is Some(@moonsver.Major))
  assert_true(@moonsver.Release::parse("pre") is Some(@moonsver.Prerelease))
  assert_true(
    @moonsver.Release::parse("prerelease") is Some(@moonsver.Prerelease),
  )
  assert_true(@moonsver.Release::parse("release") is Some(@moonsver.Stable))
  assert_true(@moonsver.Release::parse("nope") is None)
  assert_eq(@moonsver.Major.to_string(), "major")
}
