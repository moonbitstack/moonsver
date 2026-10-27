///|
/// The kind of bump to apply.
///
/// Several corners are easy to miss:
/// the major bump of `1.0.0-pre` is `1.0.0`.
pub(all) enum Release {
  /// `1.2.3` → `2.0.0`；`1.0.0-pre` → `1.0.0`
  Major
  /// `1.2.3` → `1.3.0`；`1.2.0-pre` → `1.2.0`
  Minor
  /// `1.2.3` → `1.2.4`；`1.2.3-pre` → `1.2.3`
  Patch
  /// `1.2.3` → `2.0.0-0`
  PreMajor
  /// `1.2.3` → `1.3.0-0`
  PreMinor
  /// `1.2.3` → `1.2.4-0`
  PrePatch
  /// Bump the last numeric identifier, or raise the patch and append `-0` if there is none
  Prerelease
  /// Drop the prerelease, leaving the numbers alone
  Stable
}

///|
fn with_pre(v : Version, pre : Array[Identifier]) -> Version {
  { major: v.major, minor: v.minor, patch: v.patch, pre, build: [], }
}

///|
/// Bump the last numeric prerelease identifier, appending `0` if there is none.
fn bump_prerelease(v : Version) -> Version {
  let pre = v.pre.copy()
  let mut i = pre.length() - 1
  let mut bumped = false
  while i >= 0 {
    match pre[i] {
      Num(n) => {
        pre[i] = Num(n + one())
        bumped = true
        break
      }
      Alpha(_) => ()
    }
    i = i - 1
  }
  if !bumped {
    pre.push(Identifier::numeric(0))
  }
  with_pre(v, pre)
}

///|
/// Apply a bump.
pub fn Version::inc(self : Version, release : Release) -> Version {
  match release {
    Major => {
      let major = if !self.minor.is_zero() ||
        !self.patch.is_zero() ||
        self.pre.is_empty() {
        self.major + one()
      } else {
        self.major
      }
      mk(major, zero(), zero())
    }
    Minor => {
      let minor = if !self.patch.is_zero() || self.pre.is_empty() {
        self.minor + one()
      } else {
        self.minor
      }
      mk(self.major, minor, zero())
    }
    Patch => {
      let patch = if self.pre.is_empty() {
        self.patch + one()
      } else {
        self.patch
      }
      mk(self.major, self.minor, patch)
    }
    PreMajor =>
      with_pre(mk(self.major + one(), zero(), zero()), [Identifier::numeric(0)])
    PreMinor =>
      with_pre(mk(self.major, self.minor + one(), zero()), [
        Identifier::numeric(0),
      ])
    PrePatch =>
      with_pre(mk(self.major, self.minor, self.patch + one()), [
        Identifier::numeric(0),
      ])
    Prerelease =>
      if self.pre.is_empty() {
        with_pre(mk(self.major, self.minor, self.patch + one()), [
          Identifier::numeric(0),
        ])
      } else {
        bump_prerelease(self)
      }
    Stable => mk(self.major, self.minor, self.patch)
  }
}

///|
/// Parse a bump name, for the CLI.
pub fn Release::parse(name : String) -> Release? {
  match name {
    "major" => Some(Major)
    "minor" => Some(Minor)
    "patch" => Some(Patch)
    "premajor" => Some(PreMajor)
    "preminor" => Some(PreMinor)
    "prepatch" => Some(PrePatch)
    "prerelease" | "pre" => Some(Prerelease)
    "stable" | "release" => Some(Stable)
    _ => None
  }
}

///|
pub extend Release with @debug.Debug::{to_repr}

///|
pub impl @debug.Debug for Release with fn to_repr(self : Release) -> @debug.Repr {
  @debug.Repr(self.to_string())
}

///|
pub extend Release with Show::{to_string, output}

///|
pub impl Show for Release with fn to_string(self : Release) -> String {
  match self {
    Major => "major"
    Minor => "minor"
    Patch => "patch"
    PreMajor => "premajor"
    PreMinor => "preminor"
    PrePatch => "prepatch"
    Prerelease => "prerelease"
    Stable => "stable"
  }
}
