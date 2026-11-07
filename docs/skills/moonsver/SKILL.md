---
name: moonsver
description: "Parse, compare and bump semantic versions, and test version ranges, in MoonBit with moonbitstack/moonsver: SemVer 2.0.0 precedence, the npm, Cargo, Ruby and strict range grammars, prerelease matching. Use when code reads a version string, checks a dependency constraint, picks the newest release that fits, sorts releases or computes the next version."
---

# moonsver

```bash
moon add moonbitstack/moonsver
```

```moonbit
// moon.pkg
import {
  "moonbitstack/moonsver",
}
```

Everything that reads text raises `@moonsver.Refused`, which says what was wrong and where (`at()`, `message()`).

## Does a version fit a constraint

```moonbit
fn fits(version : String, constraint : String) -> Bool raise @moonsver.Refused {
  @moonsver.satisfies(version, constraint)
}
```

The grammar is npm's unless told otherwise. A Cargo or Ruby constraint is read with its own rules:

```moonbit
fn fits_cargo(version : String, constraint : String) -> Bool raise @moonsver.Refused {
  @moonsver.satisfies(version, constraint, syntax=@moonsver.Syntax::cargo())
}
```

## The newest release that fits

```moonbit
fn newest(constraint : String, released : Array[String]) -> String? raise @moonsver.Refused {
  let range = @moonsver.Range::parse(constraint)
  let versions = []
  for text in released {
    versions.push(@moonsver.Version::parse(text))
  }
  range.max_satisfying(versions).map(v => v.to_string())
}
```

Parse the range once and ask it many times; `satisfying` gives every match, sorted.

## The next version

```moonbit
fn next(version : String, kind : String) -> String raise @moonsver.Refused {
  let release = @moonsver.Release::parse(kind) // major, minor, patch, premajor, preminor, prepatch, prerelease, stable
  @moonsver.Version::parse(version).inc(release).to_string()
}
```

## Things that catch people out

- A bare version means different things: exact under npm and Ruby, a caret under Cargo. `1.2.3` takes `1.9.0` only with `Syntax::cargo()`.
- Prereleases stay out of a range unless a comparator in the same set names a prerelease of the same `major.minor.patch`: `>=1.0.0` does not take `1.1.0-beta`. That is npm's and Cargo's rule; `Syntax` has a `prerelease_policy` of `Always` or `Never` for the others.
- Build metadata takes no part in precedence. `precedence_cmp` calls `1.0.0+a` and `1.0.0+b` equal, `==` does not, and `compare` breaks the tie, so sort with `compare` when the order must be total.
- The three numbers are `BigInt`: `major()` returns one, and `18446744073709551616.0.0` parses.
- `Release::parse` raises for a name it does not know.
