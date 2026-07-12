import json
from pathlib import Path

from etl.validation import complete_edition, validate_edition, validate_topics


edition_source = Path("etl/seeds/first-edition.json")
topics_source = Path("etl/seeds/default-topics.json")
collectors_source = Path("etl/sources.json")
edition_resource = Path("apps/ios/src/Resources/first-edition.json")
topics_resource = Path("apps/ios/src/Resources/default-topics.json")

edition = json.loads(edition_source.read_text(encoding="utf-8"))
topics = json.loads(topics_source.read_text(encoding="utf-8"))
collectors = json.loads(collectors_source.read_text(encoding="utf-8"))
validate_edition(complete_edition(edition))
validate_topics(topics)

topic_ids = {topic["id"] for topic in topics["topics"]}
used_topic_ids = {topic_id for item in edition["items"] for topic_id in item["topic_ids"]}
unknown_topic_ids = used_topic_ids - topic_ids
if unknown_topic_ids:
    raise RuntimeError("edition references unknown topics: " + ", ".join(sorted(unknown_topic_ids)))
collector_topic_ids = {
    topic_id for source in collectors["sources"] for topic_id in source["topic_ids"]
}
unknown_collector_topic_ids = collector_topic_ids - topic_ids
if unknown_collector_topic_ids:
    raise RuntimeError(
        "collectors reference unknown topics: " + ", ".join(sorted(unknown_collector_topic_ids))
    )
if [topic["position"] for topic in topics["topics"]] != list(range(1, len(topics["topics"]) + 1)):
    raise RuntimeError("canonical topic positions must be contiguous from 1")
if any(
    not url.startswith("https://")
    for item in edition["items"]
    for url in [item["source_url"], *(citation["url"] for citation in item["citations"])]
):
    raise RuntimeError("canonical first-edition links must use HTTPS")

if edition_source.read_bytes() != edition_resource.read_bytes():
    raise RuntimeError("bundled first edition differs from the canonical seed")
if topics_source.read_bytes() != topics_resource.read_bytes():
    raise RuntimeError("bundled default topics differ from the canonical seed")

print(
    f"contracts valid: {len(edition['items'])} stories, "
    f"{sum(len(item['citations']) for item in edition['items'])} citations, "
    f"{len(topics['topics'])} topics"
)
