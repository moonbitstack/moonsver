"""Write docs/api.html from the package's interface file and the `///` (and
`//`) comments in its sources, so the reference follows the code.

Usage, from the repository root:

    python scripts/gen_api.py

The output is deterministic: run it twice and `git diff --exit-code docs/api.html`
stays empty.
"""

import html
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "src"

PACKAGES = [
    (
        "moonsver",
        ".",
        "moonbitstack/moonsver",
        "Semantic Versioning 2.0.0: parsing, printing, precedence, bumping and "
        "version ranges, with the range grammar as a setting.",
    ),
]

DECL = re.compile(
    r"^pub(?:\((?:all|open)\))?\s+(fn|let|struct|enum|suberror|trait|type)\s+"
    r"([A-Za-z_]\w*(?:::[A-Za-z_]\w*)?)"
)

# trait wiring we do not repeat as separate entries
BOILERPLATE = re.compile(
    r"::(equal|not_equal|output|to_repr|hash|hash_combine|op_lt|op_le|op_gt|op_ge)\("
)

DEFAULT_DOCS = {
    "to_string": "The canonical text form, from `Show`.",
    "compare": "A total order that `sort` uses: precedence first, then build metadata.",
    "to_json": "Serialise as a JSON string.",
    "from_json": "Read back from a JSON string, through the same parser.",
}

FIRST = {
    "new", "from_bigint", "parse", "any", "default", "npm", "cargo", "ruby",
    "strict", "from_name", "parse_version",
}


def sources(folder):
    for path in sorted((SRC / folder).glob("*.mbt")):
        if not path.name.endswith("_test.mbt"):
            yield path.read_text(encoding="utf-8").splitlines()


def docs_of(folder):
    """Doc text by declared name; enum variants and struct fields included."""
    out = {}
    for lines in sources(folder):
        pending = []
        owner = None
        for line in lines:
            s = line.strip()
            if s == "///|":
                pending = []
                continue
            if s.startswith("///"):
                pending.append(s[3:].strip())
                continue
            if owner is not None:
                if s.startswith("}"):
                    owner = None
                    pending = []
                    continue
                if s.startswith("//"):
                    pending.append(s[2:].strip())
                    continue
                m = re.match(r"([A-Za-z_]\w*)\s*(?::|\(|$)", s)
                if m:
                    note = "\n".join(pending).strip()
                    if not note:
                        trail = re.search(r"//\s*(.+)$", s)
                        note = trail.group(1).strip() if trail else ""
                    if note:
                        out[owner + "." + m.group(1)] = note
                    pending = []
                    continue
                pending = []
                continue
            m = DECL.match(line)
            if m:
                name = m.group(2)
                if pending:
                    out[name] = "\n".join(pending).strip()
                if m.group(1) in ("enum", "suberror") and line.rstrip().endswith("{"):
                    owner = name
                elif m.group(1) == "struct" and line.rstrip().endswith("{") and "pub(all)" in line:
                    owner = name
                pending = []
                continue
            pending = []
    return out


def items_of(folder):
    """Declarations from the interface file, in the order it lists them."""
    lines = (SRC / folder / "pkg.generated.mbti").read_text(encoding="utf-8").splitlines()
    items, block = [], None
    for line in lines:
        if block is not None:
            if line.startswith("}"):
                items.append(block)
                block = None
            else:
                block["variants"].append(line.strip())
            continue
        m = re.match(r"pub(\((?:all|open)\))?\s+(enum|struct|suberror)\s+(\w+)", line)
        if m:
            block = {
                "kind": m.group(2),
                "name": m.group(3),
                "all": bool(m.group(1)),
                "sig": line.rstrip().rstrip(" {").strip(),
                "variants": [],
            }
            if not line.rstrip().endswith("{"):
                items.append(block)
                block = None
            continue
        m = re.match(r"pub fn (\w+)::(\w+)", line)
        if m:
            items.append(
                {"kind": "method", "name": m.group(1) + "::" + m.group(2), "sig": line, "owner": m.group(1)}
            )
            continue
        m = re.match(r"pub fn (\w+)", line)
        if m:
            items.append({"kind": "fn", "name": m.group(1), "sig": line})
            continue
        m = re.match(r"pub impl (\w+) for (\w+)", line)
        if m:
            items.append({"kind": "impl", "name": m.group(1), "sig": line, "owner": m.group(2)})
            continue
    return items


def inline(text):
    return re.sub(r"`([^`]+)`", r"<code>\1</code>", html.escape(text, quote=False))


def prose(text):
    if not text:
        return ""
    blocks, para, bullets = [], [], []

    def flush_para():
        if para:
            blocks.append("<p>" + inline(" ".join(para)) + "</p>")
            para.clear()

    def flush_bullets():
        if bullets:
            blocks.append("<ul>" + "".join("<li>" + inline(b) + "</li>" for b in bullets) + "</ul>")
            bullets.clear()

    for raw in text.split("\n"):
        s = raw.strip()
        if not s:
            flush_para()
            flush_bullets()
        elif s.startswith("- "):
            flush_para()
            bullets.append(s[2:].strip())
        else:
            flush_bullets()
            para.append(s)
    flush_para()
    flush_bullets()
    return "".join(blocks)


def sig(text):
    return f'<pre class="sig">{html.escape(text.strip(), quote=False)}</pre>'


def anchor(pkg, name):
    return f"{pkg}-{name}".replace("::", "-").replace(".", "-").lower()


def member_order(name):
    short = name.split("::")[-1]
    return (0 if short in FIRST else 1, short)


def render_package(pkg, folder, route, intro):
    docs = docs_of(folder)
    items = items_of(folder)
    types = [i for i in items if i["kind"] in ("enum", "struct", "suberror")]
    fns = [i for i in items if i["kind"] == "fn"]
    methods, impls = {}, {}
    for i in items:
        if i["kind"] == "method" and not BOILERPLATE.search(i["sig"]):
            methods.setdefault(i["owner"], []).append(i)
        if i["kind"] == "impl":
            impls.setdefault(i["owner"], []).append(i["name"])

    errors = [t for t in types if t["kind"] == "suberror"]
    plain = sorted((t for t in types if t["kind"] != "suberror"), key=lambda t: t["name"].lower())

    nav, body = [], []

    def group(key, title, blurb, entries, render_entry):
        if not entries:
            return
        nav.append(f'<li><a href="#g-{key}">{title}</a><ul class="sub">')
        for e in entries:
            nav.append(f'<li><a href="#{anchor(pkg, e["name"])}">{e["name"]}</a></li>')
        nav.append("</ul></li>")
        body.append(f'<section class="ref-group" id="g-{key}">')
        body.append(f'<h2>{title} <span class="count">{len(entries)}</span></h2>')
        body.append(f"<p>{blurb}</p>")
        for e in entries:
            body.append(render_entry(e))

    def render_fn(e):
        out = [f'<div class="type-card" id="{anchor(pkg, e["name"])}">']
        out.append(
            f'<h3><span class="kind">fn</span>{e["name"]}'
            f'<a class="anchor-link" href="#{anchor(pkg, e["name"])}">#</a></h3>'
        )
        out.append(sig(e["sig"]))
        out.append(prose(docs.get(e["name"], "")))
        out.append("</div>")
        return "".join(out)

    def render_type(t):
        name = t["name"]
        out = [f'<div class="type-card" id="{anchor(pkg, name)}">']
        out.append(
            f'<h3><span class="kind">{t["kind"]}</span>{name}'
            f'<a class="anchor-link" href="#{anchor(pkg, name)}">#</a></h3>'
        )
        out.append(prose(docs.get(name, "")))
        out.append(sig(t["sig"] + (" {" if t["variants"] else "")))
        if t["variants"] and (t["kind"] != "struct" or t["all"]):
            out.append('<ul class="variants">')
            for v in t["variants"]:
                vname = re.match(r"([A-Za-z_]\w*)", v)
                note = docs.get(f'{name}.{vname.group(1)}', "") if vname else ""
                out.append(
                    f"<li>{html.escape(v)}"
                    + (f"<small>{inline(note)}</small>" if note else "")
                    + "</li>"
                )
            out.append("</ul>")
        if impls.get(name):
            names = ", ".join(f"<code>{n}</code>" for n in impls[name])
            out.append(f'<p class="impls">Implements {names}.</p>')
        for m in sorted(methods.get(name, []), key=lambda x: member_order(x["name"])):
            short = m["name"].split("::")[-1]
            note = docs.get(m["name"], "") or DEFAULT_DOCS.get(short, "")
            out.append('<div class="member">')
            out.append(
                f'<div class="mhead"><span class="mname">{short}</span>'
                f'<span class="mk">method</span>'
                f'<a class="anchor-link" href="#{anchor(pkg, m["name"])}">#</a></div>'
            )
            out.append(sig(m["sig"]))
            out.append(prose(note))
            out.append("</div>")
        out.append("</div>")
        return "".join(out)

    group("functions", "Functions", "Values that are not tied to a type.", fns, render_fn)
    group("errors", "Errors", "One error type, raised by every parser.", errors, render_type)
    group("types", "Types", "The values the package works with.", plain, render_type)
    return nav, body


def render():
    nav, body = [], []
    for pkg, folder, route, intro in PACKAGES:
        n, b = render_package(pkg, folder, route, intro)
        nav += n
        body += b
    page = (ROOT / "docs" / "api.template.html").read_text(encoding="utf-8")
    page = page.replace("<!-- nav -->", "\n".join(nav))
    page = page.replace("<!-- body -->", "\n".join(body))
    (ROOT / "docs" / "api.html").write_text(page, encoding="utf-8", newline="\n")


render()
print("wrote docs/api.html")
