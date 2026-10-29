#!/usr/bin/env python3
"""Capture a recipe page as a small test fixture for RecipiKit.

Downloads a page (or reads a saved one) and keeps only the parts the
importer reads: the <html> tag (for lang and AMP markers), the title, the
og:/twitter: image and description tags, canonical and amphtml links, every
JSON-LD block, and the recipe card markup (a schema.org microdata Recipe,
WP Recipe Maker or Tasty Recipes container). Everything else is dropped.

Run it on your own machine when a site doesn't import, then add the result
to Packages/RecipiKit/Tests/RecipiKitTests/Fixtures/ with a row in
FixtureCorpusTests.swift describing what it should import as.

    python3 scripts/capture_fixture.py https://example.com/some-recipe/ \\
        -o Packages/RecipiKit/Tests/RecipiKitTests/Fixtures/site-pattern.html

Name the fixture after the markup pattern it shows (e.g. wprm-no-jsonld.html)
and check the trimmed file before committing it: remove anything personal,
and keep it small. Uses only the Python 3 standard library.
"""

import argparse
import datetime
import html.parser
import os
import re
import sys
import urllib.request

USER_AGENT = (
    "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 "
    "(KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
)

META_KEYS = {
    "og:title", "og:description", "og:image", "og:image:width", "og:image:height",
    "og:image:secure_url", "twitter:image", "twitter:image:src", "description",
}
LINK_RELS = {"canonical", "amphtml"}
CARD_CLASSES = {"wprm-recipe-container", "tasty-recipes"}
VOID_ELEMENTS = {
    "area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta",
    "source", "track", "wbr",
}


def fetch(url):
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=30) as response:
        data = response.read()
        charset = response.headers.get_content_charset()
        return decode(data, charset), response.geturl()


def decode(data, charset=None):
    if not charset:
        match = re.search(rb"""<meta[^>]*charset\s*=\s*["']?([\w-]+)""", data[:2048], re.I)
        charset = match.group(1).decode("ascii") if match else None
    for candidate in (charset, "utf-8", "latin-1"):
        if not candidate:
            continue
        try:
            return data.decode(candidate)
        except (LookupError, UnicodeDecodeError):
            continue
    return data.decode("utf-8", errors="replace")


class RecipeMarkupFinder(html.parser.HTMLParser):
    """Records where the interesting elements start and end in the source."""

    def __init__(self, source):
        super().__init__(convert_charrefs=False)
        self.source = source
        self.line_starts = [0]
        for match in re.finditer("\n", source):
            self.line_starts.append(match.end())
        self.html_tag = None
        self.title = None
        self.head_tags = []
        self.json_ld = []
        self.cards = []
        self._stack = []  # (tag, start offset, kind)
        self._in_card = 0
        self._title_start = None

    def source_offset(self):
        line, column = self.getpos()
        return self.line_starts[line - 1] + column

    def handle_starttag(self, tag, attrs):
        start = self.source_offset()
        text = self.get_starttag_text() or ""
        values = {name: (value or "") for name, value in attrs}
        if tag == "html" and self.html_tag is None:
            self.html_tag = text
        elif tag == "title" and self.title is None:
            self._title_start = start + len(text)
        elif tag == "meta":
            key = (values.get("property") or values.get("name") or "").lower()
            if key in META_KEYS or "charset" in values:
                self.head_tags.append(text)
        elif tag == "link":
            rels = set(values.get("rel", "").lower().split())
            if rels & LINK_RELS:
                self.head_tags.append(text)

        if tag in VOID_ELEMENTS:
            return
        kind = None
        if tag == "script" and "ld+json" in values.get("type", "").lower():
            kind = "json-ld"
        elif not self._in_card:
            classes = set(values.get("class", "").split())
            is_recipe_item = "itemscope" in values and values.get("itemtype", "").rstrip("/").endswith("schema.org/Recipe")
            if classes & CARD_CLASSES or is_recipe_item:
                kind = "card"
                self._in_card += 1
        self._stack.append((tag, start, kind))

    def handle_startendtag(self, tag, attrs):
        # <meta ... /> and friends: record them like an opening tag.
        self.handle_starttag(tag, attrs)
        if tag not in VOID_ELEMENTS and self._stack and self._stack[-1][0] == tag:
            self._stack.pop()

    def handle_endtag(self, tag):
        end = self.source_offset()
        end_of_tag = self.source.find(">", end) + 1 or len(self.source)
        if tag == "title" and self._title_start is not None and self.title is None:
            self.title = self.source[self._title_start:end].strip()
        # Pop up to the matching open tag, tolerating unclosed elements.
        for index in range(len(self._stack) - 1, -1, -1):
            if self._stack[index][0] != tag:
                continue
            _, start, kind = self._stack[index]
            del self._stack[index:]
            if kind == "json-ld":
                self.json_ld.append(self.source[start:end_of_tag])
            elif kind == "card":
                self._in_card -= 1
                self.cards.append(self.source[start:end_of_tag])
            break


def trim_card(markup):
    """Drops scripts, styles, SVG icons and comments from a recipe card."""
    markup = re.sub(r"(?is)<script\b(?![^>]*ld\+json).*?</script\s*>", "", markup)
    markup = re.sub(r"(?is)<style\b.*?</style\s*>", "", markup)
    markup = re.sub(r"(?is)<svg\b.*?</svg\s*>", "", markup)
    markup = re.sub(r"(?s)<!--.*?-->", "", markup)
    markup = re.sub(r"\n\s*\n+", "\n", markup)
    return markup.strip()


def build_fixture(source, page_url):
    finder = RecipeMarkupFinder(source)
    finder.feed(source)
    finder.close()

    today = datetime.date.today().isoformat()
    lines = [
        "<!DOCTYPE html>",
        f"<!-- Captured from {page_url} on {today} with scripts/capture_fixture.py,",
        "     trimmed to the recipe markup. Describe the pattern it shows here. -->",
        finder.html_tag or "<html>",
        "<head>",
    ]
    if finder.title is not None:
        lines.append(f"<title>{finder.title}</title>")
    lines.extend(finder.head_tags)
    lines.extend(block.strip() for block in finder.json_ld)
    lines.append("</head>")
    lines.append("<body>")
    lines.extend(trim_card(card) for card in finder.cards)
    lines.append("</body>")
    lines.append("</html>")
    return "\n".join(lines) + "\n", finder


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("source", help="the page URL, or the path of a page you saved")
    parser.add_argument("-o", "--output", help="where to write the fixture (default: print it)")
    args = parser.parse_args()

    if os.path.exists(args.source):
        with open(args.source, "rb") as file:
            source = decode(file.read())
        page_url = os.path.basename(args.source)
    else:
        source, page_url = fetch(args.source)

    fixture, finder = build_fixture(source, page_url)
    if not finder.json_ld and not finder.cards:
        print("warning: no JSON-LD or recipe card markup found; the page may build it with JavaScript", file=sys.stderr)

    if args.output:
        with open(args.output, "w", encoding="utf-8") as file:
            file.write(fixture)
        print(
            f"wrote {args.output}: {len(finder.json_ld)} JSON-LD block(s), "
            f"{len(finder.cards)} recipe card(s), {len(fixture.encode('utf-8')) // 1024} KB",
            file=sys.stderr,
        )
    else:
        sys.stdout.write(fixture)


if __name__ == "__main__":
    main()
