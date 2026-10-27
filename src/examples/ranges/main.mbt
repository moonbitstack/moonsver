///|
/// Ranges in practice: the same string under each preset, the shorthands, the
/// three prerelease policies, and picking the newest that fits.
///
/// Run with `moon run examples/ranges`.

///|
fn main raise {
  // ── The same string is read differently by each preset ──────────────────
  println("the same string under each preset")
  for name in ["npm", "cargo", "ruby", "strict"] {
    let syn = match @moonsver.Syntax::from_name(name) {
      Some(s) => s
      None => @moonsver.Syntax::npm()
    }
    let line = try
      name + " " + @moonsver.Range::parse("1.2.3", syntax=syn).to_string()
    catch {
      _ => name + " refused"
    }
    println("  " + line)
  }

  // ── Shorthands and combinators ──────────────────────────────────────────
  println("\nranges that expand")
  for text in ["^1.2.3", "~1.2", "1.2.*", "1.2.3 - 2.0.0", "^1.2.3 || ^3.0.0"] {
    let r = @moonsver.Range::parse(text)
    println("  " + text + " -> " + r.to_string())
  }

  // ── Prereleases: one range, three policies ──────────────────────────────
  // A prerelease is admitted only through a comparator that shares its
  // major.minor.patch and carries a prerelease itself, unless the policy says
  // otherwise.
  println("\nprereleases under each policy")
  let v = @moonsver.Version::parse("1.5.0-beta")
  let r = @moonsver.Range::parse(">=1.0.0")
  println("  same-tuple " + r.satisfies(v).to_string())
  println("  always     " + r.satisfies_with(v, @moonsver.Always).to_string())
  println("  never      " + r.satisfies_with(v, @moonsver.Never).to_string())

  // ── Picking from a list ─────────────────────────────────────────────────
  println("\npicking from a list")
  let versions : Array[@moonsver.Version] = []
  for s in ["1.0.0", "1.2.0", "1.2.3", "1.2.4", "1.3.0-rc.1", "2.0.0"] {
    versions.push(@moonsver.Version::parse(s))
  }
  let constraint = @moonsver.Range::parse("~1.2.0")
  println("  range      " + constraint.to_string())
  match constraint.min_satisfying(versions) {
    Some(x) => println("  min        " + x.to_string())
    None => println("  min        none")
  }
  match constraint.max_satisfying(versions) {
    Some(x) => println("  max        " + x.to_string())
    None => println("  max        none")
  }
  let fits : Array[String] = []
  for x in constraint.satisfying(versions) {
    fits.push(x.to_string())
  }
  println("  satisfying " + fits.join(", "))
}
