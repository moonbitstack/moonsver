// Expected results from the Rust `semver` crate, for the corpus in a cases directory.
//
//   cargo run --quiet -- <cases-dir> <out-dir>
//
// Rows are index based so that the case text never has to be quoted.

use std::env;
use std::fs;
use std::path::{Path, PathBuf};

fn lines(cases: &Path, name: &str) -> Vec<String> {
    let text = fs::read_to_string(cases.join(name)).expect("a case file");
    let mut parts: Vec<String> = text.split('\n').map(|s| s.to_string()).collect();
    if parts.last().map(|s| s.is_empty()).unwrap_or(false) {
        parts.pop();
    }
    parts
}

fn main() {
    let args: Vec<String> = env::args().collect();
    let cases = PathBuf::from(&args[1]);
    let out = PathBuf::from(&args[2]);
    fs::create_dir_all(&out).expect("an output directory");

    // Version acceptance, as the crate reads the spec.
    let body: Vec<String> = lines(&cases, "versions.txt")
        .iter()
        .enumerate()
        .map(|(i, text)| format!("{}\t{}", i, semver::Version::parse(text).is_ok()))
        .collect();
    fs::write(out.join("versions.tsv"), body.join("\n") + "\n").expect("versions.tsv");

    // Precedence of every ordered pair, build metadata left out.
    let parsed: Vec<semver::Version> = lines(&cases, "precedence.txt")
        .iter()
        .map(|text| semver::Version::parse(text).unwrap_or_else(|e| panic!("{}: {}", text, e)))
        .collect();
    let mut pairs = Vec::new();
    for i in 0..parsed.len() {
        for j in (i + 1)..parsed.len() {
            let sign = match parsed[i].cmp_precedence(&parsed[j]) {
                std::cmp::Ordering::Less => -1,
                std::cmp::Ordering::Equal => 0,
                std::cmp::Ordering::Greater => 1,
            };
            pairs.push(format!("{}\t{}\t{}", i, j, sign));
        }
    }
    fs::write(out.join("precedence.tsv"), pairs.join("\n") + "\n").expect("precedence.tsv");

    // Requirement acceptance and matching.
    let versions: Vec<semver::Version> = lines(&cases, "range_versions.txt")
        .iter()
        .map(|text| semver::Version::parse(text).unwrap_or_else(|e| panic!("{}: {}", text, e)))
        .collect();
    let mut rows = Vec::new();
    for (ri, text) in lines(&cases, "ranges_cargo.txt").iter().enumerate() {
        match semver::VersionReq::parse(text) {
            Err(_) => rows.push(format!("{}\t-1\tERR", ri)),
            Ok(req) => {
                for (vi, version) in versions.iter().enumerate() {
                    rows.push(format!("{}\t{}\t{}", ri, vi, req.matches(version)));
                }
            }
        }
    }
    fs::write(out.join("ranges_cargo.tsv"), rows.join("\n") + "\n").expect("ranges_cargo.tsv");

    println!("rust reference: semver 1.0.27");
}
