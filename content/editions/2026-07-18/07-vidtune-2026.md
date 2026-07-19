---
id: "vidtune-2026"
kind: "paper"
topic_ids: ["audiovisual-techniques","sound-design","creative-tooling","adobe-research"]
source_name: "Adobe Research"
source_url: "https://research.adobe.com/publication/vidtune-creating-video-soundtracks-with-generative-music-and-video-based-thumbnails/"
published_at: "2026-01-17T21:45:44Z"
reading_minutes: 4
related_story_ids: ["adobe-soundstager-2026","adobe-mosound-2026"]
related_event_ids: []
model_provider: "openai"
model_name: "gpt-5.6-sol"
prompt_version: "nightjar-articles-v2"
researched_at: "2026-07-18T04:40:49Z"
---

# Browse candidate music with pictures tied to the cut

> VidTune turns generated soundtrack options into contextual animated thumbnails and a similarity map, helping an editor compare music before listening linearly to every candidate.

The system extracts a representative subject from the selected video scene, then maps each track's valence, energy, genre, and instruments into visual cues around that subject. Animated thumbnails sample at 0.5 frames per second and change when instruments enter, while movement and effects approximate tempo and energy.

Editors can preview tracks in sync, inspect reusable prompt terms, request natural-language variations, filter the history, or browse a two-dimensional map built from audio-embedding similarity. The research began with eight formative-study participants and was evaluated in a twelve-person controlled study plus six exploratory cases. Its main contribution is not music generation itself but a denser review interface for many plausible alternatives.

## Why this was selected

Comparing options is a neglected bottleneck in generative audio, and the thumbnail-plus-map approach is concrete enough to adapt to ordinary music libraries.

## Sources

- [VidTune: Creating Video Soundtracks with Generative Music and Video-Based Thumbnails](https://research.adobe.com/publication/vidtune-creating-video-soundtracks-with-generative-music-and-video-based-thumbnails/) | Adobe Research | 2026-04-13T00:00:00Z
- [VidTune project page](https://minahuh.com/VidTune/) | Mina Huh and collaborators | 2026-01-17T21:45:44Z
- [VidTune paper](https://arxiv.org/abs/2601.12180) | arXiv | 2026-01-17T21:45:44Z
