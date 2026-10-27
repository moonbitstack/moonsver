///|
test "json: a version serialises as a string" {
  let v = parse_ok("1.2.3-alpha.1+build.9")
  let j = @json.to_json(v)
  assert_eq(Json::stringify(j), "\"1.2.3-alpha.1+build.9\"")
  let back : @moonsver.Version = @json.from_json(j)
  assert_eq(back, v)
}

///|
test "json: a range serialises as canonical text" {
  let r = range_ok("^1.2.3")
  let j = @json.to_json(r)
  assert_eq(Json::stringify(j), "\">=1.2.3, <2.0.0\"")
  let back : @moonsver.Range = @json.from_json(j)
  assert_eq(back, r)
}

///|
test "json: bad input raises a decode error" {
  let ok = try {
    let _ : @moonsver.Version = @json.from_json(@json.parse("\"1.2\""))
    false
  } catch {
    _ => true
  }
  assert_true(ok)
  let ok2 = try {
    let _ : @moonsver.Version = @json.from_json(@json.parse("42"))
    false
  } catch {
    _ => true
  }
  assert_true(ok2)
}
