///|
/// Every `Release` form against a set of inputs, including the corners that
/// are easy to miss. Run with `moon run examples/bumps`.

///|
fn main raise {
  let cases : Array[(@moonsver.Version, @moonsver.Release)] = [
    // A major bump of a .0.0 prerelease only drops the prerelease, because
    // the minor and patch are already zero.
    (@moonsver.Version::parse("1.0.0-pre"), @moonsver.Major),
    (@moonsver.Version::parse("1.2.0-pre"), @moonsver.Major),

    // A patch bump of 1.2.3-pre lands on the stable 1.2.3.
    (@moonsver.Version::parse("1.2.3-pre"), @moonsver.Patch),

    // Prerelease on a stable version raises the patch and appends -0.
    (@moonsver.Version::parse("1.2.3"), @moonsver.Prerelease),

    // A numeric prerelease identifier is incremented in place.
    (@moonsver.Version::parse("1.2.3-alpha.1.2"), @moonsver.Prerelease),

    // With no numeric identifier, -0 is appended instead.
    (@moonsver.Version::parse("1.2.3-alpha.beta"), @moonsver.Prerelease),

    // Stable drops the prerelease and keeps the build metadata off.
    (@moonsver.Version::parse("1.2.3-rc.1+build"), @moonsver.Stable),
  ]

  println("from              bump        result")
  for pair in cases {
    let (from, rel) = pair
    let left = from.to_string()
    let middle = rel.to_string()
    println(left + "  " + middle + "  " + from.inc(rel).to_string())
  }
}
