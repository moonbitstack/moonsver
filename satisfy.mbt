///|
/// Does the version satisfy this one comparator, ignoring the prerelease policy?
fn comparator_satisfies(c : Comparator, v : Version) -> Bool {
  let d = v.precedence_cmp(c.version)
  match c.op {
    Eq => d == 0
    Ne => d != 0
    Gt => d > 0
    Ge => d >= 0
    Lt => d < 0
    Le => d <= 0
  }
}

///|
/// Does the version satisfy this comparator set, prerelease policy included?
fn comparator_set_satisfies(
  set : ComparatorSet,
  v : Version,
  policy : PrereleasePolicy,
) -> Bool {
  if v.is_prerelease() {
    match policy {
      Never => return false
      SameTuple => {
        // npm and Cargo: at least one comparator must carry a prerelease
        // whose major.minor.patch matches the version under test.
        let mut anchored = false
        for c in set.comparators {
          if c.version.is_prerelease() && c.version.same_core(v) {
            anchored = true
          }
        }
        if !anchored {
          return false
        }
      }
      Always => ()
    }
  }
  for c in set.comparators {
    if !comparator_satisfies(c, v) {
      return false
    }
  }
  true
}

///|
/// Does the version fall inside the range?
///
/// The prerelease policy comes from the `Syntax` used to parse the range.
pub fn Range::satisfies(self : Range, version : Version) -> Bool {
  self.satisfies_with(version, self.policy)
}

///|
/// Does the version fall inside the range, with the policy overridden for this call?
pub fn Range::satisfies_with(
  self : Range,
  version : Version,
  policy : PrereleasePolicy,
) -> Bool {
  for set in self.sets {
    if comparator_set_satisfies(set, version, policy) {
      return true
    }
  }
  false
}

///|
/// The highest satisfying version, by precedence, with build metadata breaking ties.
pub fn Range::max_satisfying(
  self : Range,
  versions : Array[Version],
) -> Version? {
  let mut best : Version? = None
  for v in versions {
    if self.satisfies(v) {
      match best {
        None => best = Some(v)
        Some(b) => if v.compare(b) > 0 { best = Some(v) }
      }
    }
  }
  best
}

///|
/// The lowest satisfying version.
pub fn Range::min_satisfying(
  self : Range,
  versions : Array[Version],
) -> Version? {
  let mut best : Version? = None
  for v in versions {
    if self.satisfies(v) {
      match best {
        None => best = Some(v)
        Some(b) => if v.compare(b) < 0 { best = Some(v) }
      }
    }
  }
  best
}

///|
/// Every satisfying version, sorted ascending by precedence.
pub fn Range::satisfying(
  self : Range,
  versions : Array[Version],
) -> Array[Version] {
  let out : Array[Version] = []
  for v in versions {
    if self.satisfies(v) {
      out.push(v)
    }
  }
  out.sort()
  out
}

///|
/// Convenience wrapper: parse two strings and check whether the version satisfies.
///
/// Both strings are read with the same grammar, the version through `Version::parse`.
pub fn satisfies(
  version : String,
  range : String,
  syntax~ : Syntax = Syntax::npm(),
) -> Bool raise Refused {
  Range::parse(range, syntax~).satisfies(Version::parse(version, syntax~))
}
