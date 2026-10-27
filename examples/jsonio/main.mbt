///|
/// A JSON round trip for a version and a range. Both serialise as strings, so
/// `to_json` and `from_json` are loss-free. Run with `moon run examples/json`.

///|
fn main raise {
  // A version becomes a JSON string and comes back equal.
  let v = @moonsver.Version::parse("1.2.3-alpha.1+build.9")
  let vj = @json.to_json(v)
  println("version json " + vj.stringify())
  let back_v : @moonsver.Version = @json.from_json(vj)
  println("version back " + back_v.to_string())
  println("equal        " + (back_v == v).to_string())

  // A range serialises as its canonical text, which re-parses to the same set.
  let r = @moonsver.Range::parse("^1.2.3")
  let rj = @json.to_json(r)
  println("range json   " + rj.stringify())
  let back_r : @moonsver.Range = @json.from_json(rj)
  println("range back   " + back_r.to_string())
  println("equal        " + (back_r == r).to_string())
}
