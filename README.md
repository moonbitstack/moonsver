# moonsver

SemVer 2.0.0 for MoonBit: parsing, printing, precedence and version ranges.

Ranges are not part of the spec, and every ecosystem wrote its own grammar for them.
moonsver pulls those differences out into a set of grammar settings (`Syntax`), so one
parser handles npm, Cargo, RubyGems and a strict reading of the spec — the same idea as
the grammar parameters in moonregex.

```
                      ┌──────────────┐
  "1.2.3-alpha+build" │  Version     │  parse / to_string
  ">=1.2.3, <2.0.0"   │  Range       │  precedence_cmp / satisfies
  "^1.2.3"  "~1.2"    │  Syntax      │  npm / cargo / ruby / strict
                      └──────────────┘
```

- **SemVer 2.0.0 only.** PEP 440 is not SemVer and is not implemented; `1.0.0.post1`
  and `~=1.4` are refused rather than guessed at.
- **Arbitrary precision.** The three numbers are `BigInt`s, so
  `18446744073709551616.0.0` parses, prints and compares exactly. node-semver stops at
  the JavaScript safe integer, Rust's `semver` crate at `u64`.
- **Aligned with the mature implementations.** Precedence follows §11 of the spec to the
  letter; range expansion matches node-semver's `replaceXRange` / `replaceCarets` /
  `replaceTildes` and Cargo's caret rules.
- **No third-party dependencies**, just `moonbitlang/core`.

## Using it

In your `moon.pkg` (module `Lfan-ke/moonsver`, package alias `@moonsver`):

```
import {
  "Lfan-ke/moonsver",
}
```

While it is still local, list the checkout as a member of your `moon.work` workspace
and import it as usual — for local members the version in the import is ignored:

```
// moon.work
members = [
  "vendor/moonsver",
]

// moon.mod
import {
  "Lfan-ke/moonsver@0.1.0",
}
```

(Not on mooncakes yet; once it is, `moon add Lfan-ke/moonsver` will do the job.)

## Quick start

```moonbit
///|
fn demo() -> Unit {
  // Parsing and printing
  let v = @moonsver.Version::parse("1.2.3-alpha.1+build.5").unwrap()
  println(v.to_string())      // 1.2.3-alpha.1+build.5
  println(v.core_string())    // 1.2.3
  println(v.is_prerelease())  // true

  // Precedence (§11; build metadata stays out of it)
  let a = @moonsver.Version::parse("1.0.0-alpha").unwrap()
  let b = @moonsver.Version::parse("1.0.0").unwrap()
  println(a.precedence_cmp(b))  // -1

  // Ranges
  let r = @moonsver.Range::parse("^1.2.3").unwrap()
  println(r.to_string())        // >=1.2.3, <2.0.0
  println(r.satisfies(@moonsver.Version::parse("1.9.0").unwrap()))  // true
  println(r.satisfies(@moonsver.Version::parse("2.0.0").unwrap()))  // false

  // Bumps
  println(@moonsver.Version::parse("1.2.3").unwrap().inc(@moonsver.Major).to_string())  // 2.0.0
}
```

`unwrap()` is there to keep the example short. In real code, match on the result or use
`try` — the error carries a category, a message and the character position.

## API

### `Version`

| Method | What it does |
| --- | --- |
| `Version::parse(s, syntax?)` | Parse, returning `Result[Version, SemverError]`; npm grammar by default |
| `Version::new(major, minor, patch)` | Build from three `Int`s |
| `Version::from_bigint(major, minor, patch)` | Build from three `BigInt`s |
| `major()` / `minor()` / `patch()` | The numbers, as `BigInt` |
| `prerelease()` / `build()` | Identifier lists (`ArrayView`) |
| `is_prerelease()` / `is_stable()` | Prerelease or not |
| `same_core(other)` | Do the three numbers match? |
| `core()` / `core_string()` | Drop prerelease and build metadata |
| `precedence_cmp(other)` | §11 precedence, returning `-1`, `0` or `1` |
| `compare(other)` | Total order: precedence, then build metadata (`Compare`, so `sort` works) |
| `inc(release)` | Apply a bump, see below |
| `to_string()` | Canonical text (`Show`) |

Equality (`Eq`) is **full equality**: `1.0.0+a != 1.0.0+b`, though the two share a
precedence. That is the choice Rust's `semver` makes as well; node-semver's `eq` ignores
build metadata.

### `Release`

`Major`, `Minor`, `Patch`, `PreMajor`, `PreMinor`, `PrePatch`, `Prerelease`, `Stable`,
with the same behaviour as node-semver's `inc()`, including the corners that are easy to
miss:

| Input | Bump | Result |
| --- | --- | --- |
| `1.0.0-pre` | `Major` | `1.0.0` (minor and patch are already zero, so only the prerelease goes) |
| `1.2.0-pre` | `Major` | `2.0.0` |
| `1.2.3-pre` | `Patch` | `1.2.3` |
| `1.2.3` | `Prerelease` | `1.2.4-0` |
| `1.2.3-alpha.1.2` | `Prerelease` | `1.2.3-alpha.1.3` (last numeric identifier wins) |
| `1.2.3-alpha.beta` | `Prerelease` | `1.2.3-alpha.beta.0` |
| `1.2.3-rc.1+build` | `Stable` | `1.2.3` |

`Release::parse("major")` and `to_string()` are there for the CLI and config files.

### `Range`

| Method | What it does |
| --- | --- |
| `Range::parse(s, syntax?)` | Parse, returning `Result[Range, SemverError]` |
| `Range::any()` | Any version (`*`) |
| `satisfies(version)` / `satisfies_with(version, policy)` | Does the version fit? |
| `max_satisfying(versions)` / `min_satisfying(versions)` | The extremes that fit |
| `satisfying(versions)` | Everything that fits, sorted ascending by precedence |
| `sets()` | The disjuncts (`ArrayView[ComparatorSet]`) |
| `policy()` | The prerelease policy the range was parsed with |
| `is_any()` | Is this the same as any version? |
| `to_string()` | Canonical text, which re-parses under the same grammar |

A `Range` is the parsed, expanded structure rather than the original string: `^1.2.3` is
the conjunction of `>=1.2.3` and `<2.0.0`. Canonical output joins comparators with `, `
and disjuncts with ` || `.

### `satisfies(version, range, syntax?)`

A one-liner for two strings, returning `Result[Bool, SemverError]`.

### Errors

`SemverError` carries `kind()` (an `ErrorKind`), `message()` and `position()` (a character
index). The kinds are `EmptyInput`, `UnexpectedChar`, `UnexpectedEnd`, `InvalidNumber`,
`LeadingZero`, `EmptyIdentifier`, `InvalidIdentifier`, `UnsupportedSyntax` and
`InvalidRange`.

## Grammar settings (`Syntax`)

A version has one spelling in SemVer 2.0.0, but ranges are not in the spec, and npm,
Cargo and RubyGems each wrote their own grammar. `Syntax` pulls the differences apart
into fourteen settings:

| Field | What it controls | npm | Cargo | Ruby | strict |
| --- | --- | --- | --- | --- | --- |
| `default_op` | Meaning of a bare version | `Exact` | `Caret` | `Exact` | `Exact` |
| `tilde_bump` | How `~` finds its upper bound | `Patch` | `Patch` | `LastSpecified` | `Patch` |
| `allow_caret` | Accept `^` | yes | yes | no | no |
| `allow_tilde` | Accept `~` (`~>` only under `LastSpecified`) | yes | yes | yes | no |
| `allow_ne` | Accept `!=` | no | no | yes | no |
| `allow_or` | Accept `\|\|` | yes | no | no | no |
| `allow_hyphen_range` | Accept `1.2.3 - 2.0.0` | yes | no | no | no |
| `allow_xrange` | Accept `1.x`, `1.2.*`, bare `1.2` | yes | yes | no | no |
| `allow_empty` | Empty string means any version | yes | no | no | no |
| `allow_v_prefix` | Accept `v1.2.3` | yes | no | no | no |
| `allow_equals_prefix` | Accept `=1.2.3` as a version literal | yes | yes | yes | no |
| `allow_build_metadata` | Accept `+build` | yes | yes | yes | yes |
| `trim` | Whitespace around a version literal | yes | yes | yes | no |
| `prerelease_policy` | How prereleases are matched | `SameTuple` | `SameTuple` | `SameTuple` | `SameTuple` |

`Syntax::from_name("cargo")` and `name()` serve config files and the CLI; `Default` is
npm's grammar. You can also build a `Syntax` literal of your own — npm's sugar with
Cargo's caret default, say.

### The same string, three readings

| Written | npm | Cargo | Ruby |
| --- | --- | --- | --- |
| `1.2.3` | `=1.2.3` | `>=1.2.3, <2.0.0` | `=1.2.3` |
| `~1.2` | `>=1.2.0, <1.3.0` | `>=1.2.0, <1.3.0` | — (`~> 1.2` gives `>=1.2.0, <2.0.0`) |
| `1.2.*` | `>=1.2.0, <1.3.0` | `>=1.2.0, <1.3.0` | not supported |
| `^1.2.3 \|\| ^2` | fine | rejected | rejected |

Note that `1.2.*` is **not** a caret under Cargo: an explicit wildcard wins over
`default_op`, which is what Cargo's own documentation says (`1.2.*` := `>=1.2.0,
<1.3.0`).

## How it behaves

### Precedence (§11)

1. Compare `major`, `minor`, `patch` in turn (arbitrary precision);
2. a version with a prerelease ranks below the same numbers without one;
3. prerelease identifiers compare one by one: numeric by value, numeric below
   alphanumeric, alphanumeric in ASCII order;
4. a prefix ranks below the longer list;
5. **build metadata takes no part**.

`1.0.0-alpha < 1.0.0-alpha.1 < 1.0.0-alpha.beta < 1.0.0-beta < 1.0.0-beta.2 <
1.0.0-beta.11 < 1.0.0-rc.1 < 1.0.0` is a test case, so it stays that way.

### Prereleases and ranges

The spec says nothing about how a range should treat prereleases, and every ecosystem
settled on "only through a comparator with the same `major.minor.patch` that carries a
prerelease itself". moonsver makes that a three-way setting:

| Policy | Meaning | Example |
| --- | --- | --- |
| `SameTuple` | The npm and Cargo convention | `>=1.2.3-alpha` takes `1.2.3-beta`, refuses `1.2.4-beta`; `*` takes no prerelease at all |
| `Always` | Compare them like any other version (npm's `includePrerelease`) | `>=1.0.0` takes `1.5.0-beta` |
| `Never` | Prereleases never match, for when only stable releases will do | `>=1.0.0` refuses `1.5.0-beta` |

The policy is recorded in the `Range` when it is parsed, and `satisfies_with` can override
it for a single call.

### Canonical text

`Range::to_string` prints the expanded comparators, and the output re-parses under the
same grammar (there are tests for the round trip). The one exception is `*`, which is
always accepted as "any version" — it is what an empty range prints, so refusing it would
break the round trip.

## How it compares

| Behaviour | node-semver | Rust `semver` | Cargo | moonsver |
| --- | --- | --- | --- | --- |
| Numeric range | JS safe integer | `u64` | `u64` | arbitrary precision |
| Bare version means | exact | exact | caret | whatever `Syntax::default_op` says |
| Build metadata in precedence | no | no | no | no |
| Build metadata in `Eq` | no (`eq` uses `compare`) | yes | — | yes |
| `\|\|` | yes | no | no | a setting |
| Hyphen ranges | yes | no | no | a setting |
| `1.x` shorthand | yes | no | `*` forms only | a setting |
| Prerelease matching | same-tuple anchor | same-tuple anchor | same-tuple anchor | three policies |

## CLI

```bash
moon run cmd/main -- parse 1.2.3 v2.0.0-rc.1+build
moon run cmd/main -- compare 1.0.0-rc.1 1.0.0
moon run cmd/main -- sort 2.0.0 1.0.0-beta 1.0.0 0.9.9
moon run cmd/main -- bump prerelease 1.2.3-alpha.1     # 1.2.3-alpha.2
moon run cmd/main -- range "^0.2.3"                    # >=0.2.3, <0.3.0
moon run cmd/main -- range --syntax cargo 1.2.3        # >=1.2.3, <2.0.0
moon run cmd/main -- range --syntax ruby "~> 1.2"      # >=1.2.0, <2.0.0
moon run cmd/main -- satisfies 1.9.0 "^1.2.3"          # true
moon run cmd/main -- max "^1.2.0" 1.0.0 1.2.3 1.5.0    # 1.5.0
moon run cmd/main -- parse --json 1.2.3-alpha.1
```

`parse --json` prints (the numbers are strings, so nothing is lost):

```json
{
  "input": "1.2.3-alpha.1",
  "normalised": "1.2.3-alpha.1",
  "major": "1",
  "minor": "2",
  "patch": "3",
  "prerelease": ["alpha", "1"],
  "build": [],
  "is_prerelease": true
}
```

Exit codes: `0` means the command ran — `satisfies` returning `false`, or `max`/`min`
finding nothing, is still `0`, so read stdout for the answer. Bad arguments and parse
failures exit non-zero with the detail on stderr.

## Consuming it as a library

`Version` and `Range` both implement `ToJson` / `FromJson`, serialised as strings, so they
can go straight into config files or API responses:

```moonbit
let j = @json.to_json(@moonsver.Range::parse("^1.2.3").unwrap())
// Json::string(">=1.2.3, <2.0.0")
```

A tool like moonctl can hand `Range::max_satisfying` a list of versions and get the newest
one that fits, without reimplementing the comparison rules.

## Examples and tests

```bash
moon run examples   # the smallest useful example
moon test           # 47 cases, green on wasm-gc, js, native and wasm
moon check          # no warnings
```

The cases cover the valid and invalid examples in the spec, the §11 precedence chain,
build metadata, leading zeroes, arbitrary precision, npm's caret / tilde / shorthand /
hyphen / disjunction forms, Cargo's caret default and wildcards, Ruby's pessimistic
operator, all three prerelease policies, the extreme-value helpers, the JSON round trip
and error kinds with their positions.

## Deliberately not done

- **PEP 440.** Not SemVer; `1.0.0.post1`, `~=1.4` and `==1.*` are refused.
- **Loose mode.** node-semver's `loose` lets `01.2.3` and `1.2.3beta` through. moonsver
  offers different grammars, not a licence to accept broken input.
- **Range algebra.** `subset`, `intersects`, `minVersion` and `coerce` are not here. They
  are not parsing problems but interval arithmetic over comparator sets, and deserve a
  module of their own.
- **Some Ruby spellings.** `~>`, `!=` and the comparators all work, but Ruby's bare `1.2`
  means exactly `1.2.0` (Ruby pads the missing segments with zeroes), which is not npm's
  x-range. Under the ruby preset that form is refused rather than guessed at — it is a
  grey area, and guessing would be worse.
- **Upper bounds under `Always`.** npm appends `-0` to upper bounds (`<2.0.0-0`) to shut
  out the next version's prereleases. `SameTuple` gets the same result and keeps the
  bounds clean; with `Always` those prereleases do fall inside, which is what `Always`
  means.
