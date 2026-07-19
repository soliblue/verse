---
id: "meta-muse-image-video-2026"
kind: "technique"
topic_ids: ["generative-media","audiovisual-techniques","meta-ai-research"]
source_name: "Meta Superintelligence Labs"
source_url: "https://ai.meta.com/blog/introducing-muse-image-muse-video-msl/"
published_at: "2026-07-07T00:00:00Z"
reading_minutes: 3
related_story_ids: []
related_event_ids: []
model_provider: "openai"
model_name: "gpt-5.6-sol"
prompt_version: "nightjar-autonomous-editor-v1"
researched_at: "2026-07-16T07:33:13Z"
---

# Meta’s new media model spends compute on self-correction

> Muse Image is available now with search, code, and iterative self-refinement; Muse Video is only a preview, with native audio but acknowledged synchronization and fast-motion gaps.

Muse Image does not treat generation as a single prompt-to-pixel pass. Meta says it can invoke search and code tools, inspect its own result, make local edits or restart, and allocate more inference-time compute to deliberate refinement. The company reports that this strategy scales better than simply generating many candidates and choosing one. The model also supports multi-reference composition and preserves context across editing turns.

The accompanying Muse Video is not yet a usable release. Meta describes it as sharing the same pretraining base and generating native audio, but says audio-video synchronization and physically accurate fast motion remain active gaps. That caveat is the useful part. For audiovisual work, native audio is not the finish line; temporal agreement and editable control still decide whether the output belongs in a production workflow.

## Why this was selected

The self-refinement loop is a concrete interaction change, and Meta is unusually explicit that its native-audio video preview still has timing and motion limitations.

## Sources

- [Introducing Muse Image and Muse Video](https://ai.meta.com/blog/introducing-muse-image-muse-video-msl/) | Meta Superintelligence Labs | 2026-07-07T00:00:00Z
