import json
from datetime import UTC, datetime
from email.utils import parsedate_to_datetime
from html.parser import HTMLParser
from xml.etree import ElementTree


class JSONLDParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.active = False
        self.parts: list[str] = []
        self.documents: list[object] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        attributes = dict(attrs)
        if tag == "script" and attributes.get("type", "").lower() == "application/ld+json":
            self.active = True
            self.parts = []

    def handle_data(self, data: str) -> None:
        if self.active:
            self.parts.append(data)

    def handle_endtag(self, tag: str) -> None:
        if tag == "script" and self.active:
            self.documents.append(json.loads("".join(self.parts)))
            self.active = False
            self.parts = []


def local_name(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def element_text(element: ElementTree.Element | None) -> str | None:
    if element is None:
        return None
    text = "".join(element.itertext()).strip()
    return text or None


def child(element: ElementTree.Element, *names: str) -> ElementTree.Element | None:
    return next(
        (node for name in names for node in element if local_name(node.tag) == name),
        None,
    )


def timestamp(value: str | None) -> str | None:
    if not value:
        return None
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        parsed = parsedate_to_datetime(value)
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=UTC)
    return parsed.astimezone(UTC).isoformat(timespec="seconds").replace("+00:00", "Z")


def parse_json_feed(data: bytes) -> list[dict]:
    document = json.loads(data)
    return [
        {
            "external_id": item.get("id") or item.get("url"),
            "title": item.get("title"),
            "url": item.get("url") or item.get("external_url"),
            "author": (item.get("author") or {}).get("name") if isinstance(item.get("author"), dict) else None,
            "published_at": timestamp(item.get("date_published") or item.get("date_modified")),
            "content": item.get("content_text") or item.get("content_html") or item.get("summary"),
        }
        for item in document.get("items", [])
    ]


def parse_xml_feed(data: bytes) -> list[dict]:
    root = ElementTree.fromstring(data)
    entries = [node for node in root.iter() if local_name(node.tag) in {"item", "entry"}]
    parsed = []
    for entry in entries:
        link = child(entry, "link")
        url = link.get("href") if link is not None and link.get("href") else element_text(link)
        parsed.append(
            {
                "external_id": element_text(child(entry, "id", "guid")) or url,
                "title": element_text(child(entry, "title")),
                "url": url,
                "author": element_text(child(entry, "author", "creator")),
                "published_at": timestamp(element_text(child(entry, "published", "updated", "pubDate", "date"))),
                "content": element_text(child(entry, "content", "encoded", "description", "summary")),
            }
        )
    return parsed


def parse_json_ld_html(data: bytes) -> list[dict]:
    parser = JSONLDParser()
    parser.feed(data.decode("utf-8"))
    documents = []
    for document in parser.documents:
        values = document if isinstance(document, list) else document.get("@graph", [document]) if isinstance(document, dict) else []
        documents.extend(value for value in values if isinstance(value, dict))
    events = []
    for value in documents:
        types = value.get("@type", [])
        types = [types] if isinstance(types, str) else types
        if not any(str(kind).endswith("Event") for kind in types):
            continue
        location = value.get("location") if isinstance(value.get("location"), dict) else {}
        description = value.get("description") or ""
        content = f"{description} Location: {location.get('name')}." if location.get("name") else description
        events.append(
            {
                "external_id": value.get("id") or value.get("@id") or value.get("url"),
                "title": value.get("name"),
                "url": value.get("url"),
                "author": None,
                "published_at": timestamp(value.get("startDate")),
                "content": content,
            }
        )
    return events
