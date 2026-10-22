///|
/// The smallest useful moonsver example; the README quotes this file.
///
/// Run it with `moon run examples`.

///|
fn show_version() -> Unit {
  let v = @moonsver.Version::parse("1.2.3-alpha.1+build.5").unwrap()
  println(v.to_string()) // 1.2.3-alpha.1+build.5
  println(v.core_string()) // 1.2.3
  println(v.is_prerelease()) // true
}

///|
fn show_precedence() -> Unit {
  let a = @moonsver.Version::parse("1.0.0-alpha").unwrap()
  let b = @moonsver.Version::parse("1.0.0").unwrap()
  println(a.precedence_cmp(b)) // -1
  println(b.precedence_cmp(a)) // 1
  println(a.precedence_cmp(a)) // 0
}

///|
fn show_range() -> Unit {
  let r = @moonsver.Range::parse("^1.2.3").unwrap()
  println(r.to_string()) // >=1.2.3, <2.0.0
  for s in ["1.2.2", "1.2.3", "1.9.0", "2.0.0", "2.0.0-rc.1"] {
    let v = @moonsver.Version::parse(s).unwrap()
    println("\{s} → \{r.satisfies(v)}")
  }
}

///|
fn show_bump() -> Unit {
  let v = @moonsver.Version::parse("1.2.3").unwrap()
  println(v.inc(@moonsver.Major).to_string()) // 2.0.0
  println(v.inc(@moonsver.Minor).to_string()) // 1.3.0
  println(v.inc(@moonsver.Patch).to_string()) // 1.2.4
  println(v.inc(@moonsver.Prerelease).to_string()) // 1.2.4-0
}

///|
/// Pick the newest version that fits a constraint: moonctl's bread and butter.
fn pick_latest() -> Unit {
  let versions : Array[@moonsver.Version] = []
  for s in ["1.0.0", "1.2.0", "1.2.3", "1.2.4", "1.3.0-rc.1", "2.0.0"] {
    versions.push(@moonsver.Version::parse(s).unwrap())
  }
  let constraint = @moonsver.Range::parse("~1.2.0").unwrap()
  match constraint.max_satisfying(versions) {
    Some(v) => println("newest 1.2.x available: \{v}")
    None => println("no version fits that constraint")
  }
}

///|
fn main {
  show_version()
  show_precedence()
  show_range()
  show_bump()
  pick_latest()
}
