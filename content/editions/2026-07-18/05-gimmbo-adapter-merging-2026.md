---
id: "gimmbo-adapter-merging-2026"
kind: "paper"
topic_ids: ["generative-media","creative-tooling"]
source_name: "GimmBO project"
source_url: "https://gimmbo-project.github.io/"
published_at: "2026-01-26T15:32:16Z"
reading_minutes: 4
related_story_ids: ["inspiration-seeds-2026"]
related_event_ids: []
model_provider: "openai"
model_name: "gpt-5.6-sol"
prompt_version: "nightjar-articles-v2"
researched_at: "2026-07-18T04:40:49Z"
---

# Rank images instead of tuning twenty adapter sliders

> GimmBO searches combinations of image-model adapters from repeated user rankings, replacing a high-dimensional slider panel with comparative visual choices.

Adapters built on one diffusion model can be linearly merged, but choosing weights becomes unwieldy beyond a few styles. GimmBO uses preferential Bayesian optimization: it proposes batches of candidate images, records which ones the user prefers, and updates its model of the desired region.

Its two-stage search first explores a constrained weight space, then concentrates on the sparse set of adapters active in the strongest candidates. The authors evaluate it with simulated and real users and also demonstrate retrieval from much larger adapter collections, content-attribute merging, and reuse of a discovered style on new inputs. Code is available, while a ComfyUI node remains listed as forthcoming.

## Why this was selected

It treats subjective visual direction as an interactive optimization problem and offers a practical escape from fragile multi-slider tuning.

## Sources

- [GimmBO project page](https://gimmbo-project.github.io/) | University of Toronto and Vector Institute | 2026-01-26T15:32:16Z
- [GimmBO paper](https://arxiv.org/abs/2601.18585) | arXiv | 2026-01-26T15:32:16Z
