// Expected results from node-semver, for the corpus in a cases directory.
//
//   node npm_reference.cjs <cases-dir> <out-dir>
//
// Rows are index based so that the case text never has to be quoted: the caller
// writes the corpus, so it knows which index is which string.
//
// Pinned by the caller: npm install semver@7.7.4.

const fs = require("fs");
const path = require("path");
const semver = require("semver");

const cases = process.argv[2];
const out = process.argv[3];

function lines(name) {
  const text = fs.readFileSync(path.join(cases, name), "utf8");
  const parts = text.split("\n");
  if (parts.length && parts[parts.length - 1] === "") parts.pop();
  return parts;
}

fs.mkdirSync(out, { recursive: true });

// Version acceptance, as `semver.valid` reads it.
const versions = lines("versions.txt");
fs.writeFileSync(
  path.join(out, "versions.tsv"),
  versions.map((text, i) => `${i}\t${semver.valid(text) !== null}`).join("\n") + "\n"
);

// Precedence of every ordered pair; build metadata takes no part.
const precedence = lines("precedence.txt");
const pairs = [];
for (let i = 0; i < precedence.length; i += 1) {
  for (let j = i + 1; j < precedence.length; j += 1) {
    pairs.push(`${i}\t${j}\t${Math.sign(semver.compare(precedence[i], precedence[j]))}`);
  }
}
fs.writeFileSync(path.join(out, "precedence.tsv"), pairs.join("\n") + "\n");

// Range acceptance and satisfaction, default options.
const rangeVersions = lines("range_versions.txt");
const rows = [];
lines("ranges_npm.txt").forEach((text, ri) => {
  let range = null;
  try {
    range = new semver.Range(text);
  } catch (e) {
    rows.push(`${ri}\t-1\tERR`);
    return;
  }
  rangeVersions.forEach((version, vi) => {
    rows.push(`${ri}\t${vi}\t${range.test(version)}`);
  });
});
fs.writeFileSync(path.join(out, "ranges_npm.tsv"), rows.join("\n") + "\n");

// Highest, lowest and the whole filtered list per accepted range, computed by the
// reference itself so that selection and ordering are compared too.
const extremes = [];
lines("ranges_npm.txt").forEach((text, ri) => {
  let range = null;
  try {
    range = new semver.Range(text);
  } catch (e) {
    return;
  }
  const matching = rangeVersions.map((v, vi) => [v, vi]).filter(([v]) => range.test(v));
  if (matching.length === 0) {
    extremes.push(`${ri}\t-1\t-1\t`);
    return;
  }
  const ordered = matching.slice().sort((a, b) => semver.compare(a[0], b[0]));
  const max = matching.reduce((best, cur) => (semver.gt(cur[0], best[0]) ? cur : best));
  const min = matching.reduce((best, cur) => (semver.lt(cur[0], best[0]) ? cur : best));
  extremes.push(`${ri}\t${max[1]}\t${min[1]}\t${ordered.map(([, vi]) => vi).join(",")}`);
});
fs.writeFileSync(path.join(out, "extremes.tsv"), extremes.join("\n") + "\n");

// Bumps: the index of the (version, release) line and the result, `-` for none.
const bumps = lines("bumps.txt").map((line, i) => {
  const [version, release] = line.split("\t");
  const result = semver.inc(version, release);
  return `${i}\t${result === null ? "-" : result}`;
});
fs.writeFileSync(path.join(out, "bumps.tsv"), bumps.join("\n") + "\n");

console.log(`npm reference: semver ${require("semver/package.json").version}`);
