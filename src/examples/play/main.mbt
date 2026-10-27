///|
/// A browser-facing shell around the library. Every function takes plain
/// strings and returns a JSON string, so the page can call it without knowing
/// anything about MoonBit values. The site builds this package to JavaScript
/// and loads it as a module.

///|
fn pick_syntax(name : String) -> @moonsver.Syntax {
  match @moonsver.Syntax::from_name(name) {
    Some(s) => s
    None => @moonsver.Syntax::npm()
  }
}

///|
fn policy_name(p : @moonsver.PrereleasePolicy) -> String {
  match p {
    SameTuple => "same-tuple"
    Always => "always"
    Never => "never"
  }
}

///|
fn error_json(input : String, e : @moonsver.Refused) -> String {
  let json : Json = {
    "ok": Json(false),
    "input": Json(input),
    "error": Json(e.message()),
    "at": Json(e.at()),
  }
  json.stringify()
}

///|
fn message_json(input : String, message : String) -> String {
  let json : Json = {
    "ok": Json(false),
    "input": Json(input),
    "error": Json(message),
    "at": Json(0),
  }
  json.stringify()
}

///|
fn ids_array(v : @moonsver.Version) -> Array[String] {
  let out : Array[String] = []
  for id in v.prerelease() {
    out.push(id.to_string())
  }
  out
}

///|
fn build_array(v : @moonsver.Version) -> Array[String] {
  let out : Array[String] = []
  for b in v.build() {
    out.push(b)
  }
  out
}

///|
/// Parse one version and return its parts.
pub fn parse_version(s : String) -> String {
  try {
    let v = @moonsver.Version::parse(s)
    let json : Json = {
      "ok": Json(true),
      "input": Json(s),
      "normalised": Json(v.to_string()),
      "major": Json(v.major().to_string()),
      "minor": Json(v.minor().to_string()),
      "patch": Json(v.patch().to_string()),
      "prerelease": Json(ids_array(v)),
      "build": Json(build_array(v)),
      "is_prerelease": Json(v.is_prerelease()),
      "is_stable": Json(v.is_stable()),
      "core": Json(v.core_string()),
    }
    json.stringify()
  } catch {
    e => error_json(s, e)
  }
}

///|
/// Parse a range and show its expanded comparator sets.
pub fn parse_range(s : String, syntax : String) -> String {
  try {
    let syn = pick_syntax(syntax)
    let r = @moonsver.Range::parse(s, syntax=syn)
    let sets : Array[Json] = []
    for set in r.sets() {
      let comps : Array[String] = []
      for c in set.comparators {
        comps.push(c.to_string())
      }
      sets.push(Json(comps))
    }
    let json : Json = {
      "ok": Json(true),
      "input": Json(s),
      "normalised": Json(r.to_string()),
      "policy": Json(policy_name(r.policy())),
      "syntax": Json(syntax),
      "is_any": Json(r.is_any()),
      "sets": Json(sets),
    }
    json.stringify()
  } catch {
    e => error_json(s, e)
  }
}

///|
/// Read a newline-separated list of versions, dropping blanks.
fn split_versions(text : String) -> Array[String] {
  let out : Array[String] = []
  for raw in text.split("\n") {
    let line = raw.trim()
    if line.length() > 0 {
      out.push(line.to_owned())
    }
  }
  out
}

///|
/// The core of the playground: for each version, does it fit the range, and
/// what is the version order? Rows keep the input order; `sorted` is the same
/// versions in ascending precedence.
pub fn check_all(
  range_text : String,
  versions_text : String,
  syntax : String,
) -> String {
  let syn = pick_syntax(syntax)
  let mut range_ok = true
  let mut range_text_out = ""
  let mut range_error = ""
  let mut range : @moonsver.Range? = None
  try {
    let r = @moonsver.Range::parse(range_text, syntax=syn)
    range_text_out = r.to_string()
    range = Some(r)
  } catch {
    e => {
      range_ok = false
      range_error = e.message()
    }
  }
  let rows : Array[Json] = []
  let good : Array[@moonsver.Version] = []
  for line in split_versions(versions_text) {
    try {
      let v = @moonsver.Version::parse(line)
      let sat = match range {
        Some(r) => r.satisfies(v)
        None => false
      }
      let row : Json = {
        "version": Json(line),
        "normalised": Json(v.to_string()),
        "ok": Json(true),
        "satisfies": Json(sat),
        "error": Json::null(),
      }
      rows.push(row)
      good.push(v)
    } catch {
      e => {
        let row : Json = {
          "version": Json(line),
          "normalised": Json(""),
          "ok": Json(false),
          "satisfies": Json(false),
          "error": Json(e.message()),
        }
        rows.push(row)
      }
    }
  }
  let sorted = good.copy()
  sorted.sort()
  let sorted_names : Array[Json] = []
  for v in sorted {
    sorted_names.push(Json(v.to_string()))
  }
  let max_name : Json = match range {
    Some(r) =>
      match r.max_satisfying(good) {
        Some(v) => Json(v.to_string())
        None => Json::null()
      }
    None => Json::null()
  }
  let json : Json = {
    "ok": Json(range_ok),
    "range": Json(range_text_out),
    "rangeError": Json(range_error),
    "syntax": Json(syntax),
    "rows": Json(rows),
    "sorted": Json(sorted_names),
    "max": max_name,
  }
  json.stringify()
}

///|
/// Apply a release bump.
pub fn bump(version_text : String, release : String) -> String {
  try {
    let v = @moonsver.Version::parse(version_text)
    match @moonsver.Release::parse(release) {
      Some(rel) => {
        let json : Json = {
          "ok": Json(true),
          "input": Json(version_text),
          "release": Json(release),
          "result": Json(v.inc(rel).to_string()),
        }
        json.stringify()
      }
      None => message_json(version_text, "no such release: " + release)
    }
  } catch {
    e => error_json(version_text, e)
  }
}

///|
/// Precedence comparison of two versions: `-1`, `0` or `1`.
pub fn compare(a : String, b : String) -> String {
  try {
    let va = @moonsver.Version::parse(a)
    let vb = @moonsver.Version::parse(b)
    let json : Json = {
      "ok": Json(true),
      "a": Json(a),
      "b": Json(b),
      "cmp": Json(va.compare(vb)),
      "precedence": Json(va.precedence_cmp(vb)),
    }
    json.stringify()
  } catch {
    e => error_json(a, e)
  }
}

///|
/// How the four grammars read the same range string.
pub fn grammars(range_text : String) -> String {
  let names : Array[String] = ["npm", "cargo", "ruby", "strict"]
  let out : Array[Json] = []
  for name in names {
    let syn = pick_syntax(name)
    let mut ok = true
    let mut normalised = ""
    let mut error = ""
    try {
      let r = @moonsver.Range::parse(range_text, syntax=syn)
      normalised = r.to_string()
    } catch {
      e => {
        ok = false
        error = e.message()
      }
    }
    let entry : Json = {
      "syntax": Json(name),
      "ok": Json(ok),
      "normalised": Json(normalised),
      "error": Json(error),
    }
    out.push(entry)
  }
  let json : Json = { "input": Json(range_text), "readings": Json(out) }
  json.stringify()
}
