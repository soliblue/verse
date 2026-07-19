---
id: "inspiration-seeds-2026"
kind: "paper"
topic_ids: ["generative-media","creative-tooling"]
source_name: "Inspiration Seeds project"
source_url: "https://kfirgoldberg.github.io/InspirationSeeds/"
published_at: "2026-02-09T13:00:16Z"
reading_minutes: 4
related_story_ids: ["gimmbo-adapter-merging-2026"]
related_event_ids: []
model_provider: "openai"
model_name: "gpt-5.6-sol"
prompt_version: "nightjar-articles-v2"
researched_at: "2026-07-18T04:40:49Z"
---

# Combine references without first explaining them in words

> Inspiration Seeds takes two images and generates non-literal visual combinations, aiming at early ideation rather than prompt execution or object insertion.

The training problem is unusual because good pairs of inputs and inventive combinations are scarce. The authors reverse it: they begin with visually rich images, use sparse autoencoder features in CLIP space to split each into two visual aspects, and keep the original image as the known combination. This produces 2,085 training triplets for fine-tuning an image model on the inverse task.

The project also questions similarity-based evaluation, which rewards outputs that simply preserve the inputs. It measures description complexity as a proxy for how involved a visual relationship is and validates that proxy with a user study. The code, benchmark, training data, and an interactive demonstration are public.

## Why this was selected

It gives reference images a more exploratory role than style transfer and makes both its training construction and evaluation problem inspectable.

## Sources

- [Inspiration Seeds project page](https://kfirgoldberg.github.io/InspirationSeeds/) | Kfir Goldberg, Elad Richardson, and Yael Vinker | 2026-02-09T13:00:16Z
- [Inspiration Seeds paper](https://arxiv.org/abs/2602.08615) | arXiv | 2026-02-09T13:00:16Z
