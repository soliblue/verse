---
id: "meta-sam-audio-2025"
kind: "paper"
topic_ids: ["audiovisual-techniques","sound-design","meta-ai-research"]
source_name: "AI at Meta"
source_url: "https://ai.meta.com/research/publications/sam-audio-segment-anything-in-audio/"
published_at: "2025-12-16T00:00:00Z"
reading_minutes: 3
related_story_ids: []
related_event_ids: []
cover: "assets/meta-sam-audio-2025.png"
cover_prompt: "Minimal abstract pixel universe cover with generous negative space, no text, no logos, no faces. Quiet spatial form inspired by Prompt a sound by naming it, pointing at it, or marking its time and audiovisual techniques, sound design, meta ai research."
cover_model: "builtin-imagegen"
cover_width: 1122
cover_height: 1402
cover_fallback: false
model_provider: null
model_name: null
prompt_version: null
researched_at: null
---

# Prompt a sound by naming it, pointing at it, or marking its time

> SAM Audio unifies text, visual-mask, and temporal-span prompts in one source-separation model for speech, music, instruments, and general sound.

Source separation normally begins with a fixed category or a single kind of prompt. SAM Audio instead lets the target be specified in three ways: describe it in text, mark the corresponding object in a video frame, or identify a time span in which it is audible. A flow-matching diffusion transformer then isolates the requested source from a mixture spanning general sounds, speech, music, and instruments.

Meta reports state-of-the-art results across its evaluation suite and introduces a real-world benchmark with human-labeled multimodal prompts plus a reference-free evaluation model. More important for creative work is the interaction pattern. A visual prompt can express what language cannot, while a short clean temporal example can disambiguate an otherwise vague sound. The released repository includes inference code and notebooks, though model checkpoints require access approval and a CUDA-capable GPU is recommended.

## Why this was selected

Multimodal prompting turns source separation into a more direct editing gesture, especially when the desired sound is visible but difficult to name.

## Sources

- [SAM Audio: Segment Anything in Audio](https://ai.meta.com/research/publications/sam-audio-segment-anything-in-audio/) | AI at Meta | 2025-12-16T00:00:00Z
- [SAM Audio: Segment Anything in Audio](https://arxiv.org/abs/2512.18099) | arXiv | 2025-12-19T22:14:23Z
- [SAM-Audio inference code and notebooks](https://github.com/facebookresearch/sam-audio) | Meta Research on GitHub | null
