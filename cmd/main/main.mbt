///|
/// The moonsver command line tool.
///
/// Parse, compare and sort versions, apply bumps, expand and test ranges.
/// Built for moonctl and the website's version automation to call directly.

///|
let usage_text : String =
  #|moonsver — a SemVer 2.0.0 toolkit
  #|
  #|Usage:
  #|  moonsver parse <version>...            parse and print the canonical form
  #|  moonsver compare <a> <b>               compare precedence, printing -1 / 0 / 1
  #|  moonsver sort <version>...             sort ascending
  #|  moonsver bump <release> <version>      apply a bump
  #|  moonsver range <range>                 print the expanded range
  #|  moonsver satisfies <version> <range>   does the version satisfy the range?
  #|  moonsver max <range> <version>...      highest satisfying version
  #|  moonsver min <range> <version>...      lowest satisfying version
  #|  moonsver syntax                        list the grammar presets
  #|
  #|Bump kinds (release):
  #|  major minor patch premajor preminor prepatch prerelease stable
  #|
  #|Options:
  #|  --syntax <npm|cargo|ruby|strict>       grammar to use (npm by default)
  #|  --json                                 print JSON
  #|  -h, --help                             show this help
  #|
  #|Exit codes:
  #|  0      the command ran (satisfies false, and max/min with no match, are still
  #|         0 — read stdout for the answer)
  #|  other  bad arguments or a parse failure, with details on stderr

///|
fn[T] die(message : String) -> T {
  eprintln(message)
  abort("")
}

///|
fn syntax_of(name : String) -> @moonsver.Syntax {
  match @moonsver.Syntax::from_name(name) {
    Some(s) => s
    None => die("unknown grammar: \{name} (try npm, cargo, ruby or strict)")
  }
}

///|
struct Options {
  syntax : @moonsver.Syntax
  json : Bool
  positional : Array[String]
}

///|
fn parse_args(argv : Array[String]) -> Options {
  let mut syntax = @moonsver.Syntax::npm()
  let mut json = false
  let positional : Array[String] = []
  let mut i = 1
  while i < argv.length() {
    let a = argv[i]
    if a == "--json" {
      json = true
    } else if a == "--syntax" {
      i = i + 1
      if i >= argv.length() {
        die("--syntax needs a value")
      }
      syntax = syntax_of(argv[i])
    } else if a.has_prefix("--syntax=") {
      syntax = syntax_of(a[9:].to_owned())
    } else if a == "-h" || a == "--help" || a == "help" {
      positional.push("help")
    } else {
      positional.push(a)
    }
    i = i + 1
  }
  { syntax, json, positional, }
}

///|
fn version_json(input : String, v : @moonsver.Version) -> Json {
  let obj : Map[String, Json] = Map([])
  obj["input"] = Json::string(input)
  obj["normalised"] = Json::string(v.to_string())
  obj["major"] = Json::string(v.major().to_string())
  obj["minor"] = Json::string(v.minor().to_string())
  obj["patch"] = Json::string(v.patch().to_string())
  let pre : Array[Json] = []
  for id in v.prerelease() {
    pre.push(Json::string(id.to_string()))
  }
  obj["prerelease"] = Json::array(pre)
  let build : Array[Json] = []
  for id in v.build() {
    build.push(Json::string(id))
  }
  obj["build"] = Json::array(build)
  obj["is_prerelease"] = Json::boolean(v.is_prerelease())
  Json::object(obj)
}

///|
fn parse_one(input : String, syntax : @moonsver.Syntax) -> @moonsver.Version {
  match @moonsver.Version::parse(input, syntax~) {
    Ok(v) => v
    Err(e) => die("could not parse \{input}: \{e}")
  }
}

///|
fn range_of(input : String, syntax : @moonsver.Syntax) -> @moonsver.Range {
  match @moonsver.Range::parse(input, syntax~) {
    Ok(r) => r
    Err(e) => die("could not parse the range \{input}: \{e}")
  }
}

///|
fn cmd_parse(args : ArrayView[String], opts : Options) -> Unit {
  if args.is_empty() {
    die("parse needs at least one version")
  }
  let results : Array[Json] = []
  for input in args {
    let v = parse_one(input, opts.syntax)
    if opts.json {
      results.push(version_json(input, v))
    } else {
      println(v.to_string())
    }
  }
  if opts.json {
    println(Json::stringify(Json::array(results), indent=2))
  }
}

///|
fn cmd_compare(args : ArrayView[String], _opts : Options) -> Unit {
  if args.length() != 2 {
    die("compare needs two versions")
  }
  let a = parse_one(args[0], @moonsver.Syntax::npm())
  let b = parse_one(args[1], @moonsver.Syntax::npm())
  let d = a.precedence_cmp(b)
  println(d.to_string())
  if d == 0 && a != b {
    eprintln("same precedence, but the versions differ (build metadata)")
  }
}

///|
fn cmd_sort(args : ArrayView[String], opts : Options) -> Unit {
  if args.is_empty() {
    die("sort needs at least one version")
  }
  let versions : Array[@moonsver.Version] = []
  for input in args {
    versions.push(parse_one(input, opts.syntax))
  }
  versions.sort()
  for v in versions {
    println(v.to_string())
  }
}

///|
fn cmd_bump(args : ArrayView[String], opts : Options) -> Unit {
  if args.length() != 2 {
    die("bump needs a bump kind and a version")
  }
  let release = match @moonsver.Release::parse(args[0]) {
    Some(r) => r
    None => die("unknown bump kind: \{args[0]}")
  }
  let v = parse_one(args[1], opts.syntax)
  println(v.inc(release).to_string())
}

///|
fn cmd_range(args : ArrayView[String], opts : Options) -> Unit {
  if args.length() != 1 {
    die("range needs one range")
  }
  let r = range_of(args[0], opts.syntax)
  if opts.json {
    println(Json::stringify(Json::string(r.to_string())))
  } else {
    println(r.to_string())
  }
}

///|
fn cmd_satisfies(args : ArrayView[String], opts : Options) -> Unit {
  if args.length() != 2 {
    die("satisfies needs a version and a range")
  }
  let v = parse_one(args[0], opts.syntax)
  let r = range_of(args[1], opts.syntax)
  let ok = r.satisfies(v)
  if opts.json {
    println(Json::stringify(Json::boolean(ok)))
  } else {
    println(ok.to_string())
  }
}

///|
fn cmd_extreme(
  args : ArrayView[String],
  opts : Options,
  want_max : Bool,
) -> Unit {
  if args.length() < 2 {
    die("needs a range and one or more versions")
  }
  let r = range_of(args[0], opts.syntax)
  let versions : Array[@moonsver.Version] = []
  for i in 1..<args.length() {
    versions.push(parse_one(args[i], opts.syntax))
  }
  let found = if want_max {
    r.max_satisfying(versions)
  } else {
    r.min_satisfying(versions)
  }
  match found {
    Some(v) => println(v.to_string())
    None => ()
  }
}

///|
fn cmd_syntax() -> Unit {
  for name in ["npm", "cargo", "ruby", "strict"] {
    let s = syntax_of(name)
    println("\{name}: \{s}")
  }
}

///|
fn main {
  let opts = parse_args(@env.args())
  if opts.positional.is_empty() {
    println(usage_text)
    return
  }
  let cmd = opts.positional[0]
  let rest = opts.positional[1:]
  match cmd {
    "help" => println(usage_text)
    "parse" => cmd_parse(rest, opts)
    "compare" => cmd_compare(rest, opts)
    "sort" => cmd_sort(rest, opts)
    "bump" => cmd_bump(rest, opts)
    "range" => cmd_range(rest, opts)
    "satisfies" => cmd_satisfies(rest, opts)
    "max" => cmd_extreme(rest, opts, true)
    "min" => cmd_extreme(rest, opts, false)
    "syntax" => cmd_syntax()
    _ => {
      eprintln("unknown command: \{cmd}")
      println(usage_text)
      abort("")
    }
  }
}
