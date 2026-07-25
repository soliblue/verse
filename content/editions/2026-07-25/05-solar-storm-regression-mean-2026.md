---
id: "solar-storm-regression-mean-2026"
kind: "paper"
topic_ids: ["space-science","statistics"]
source_name: "Nature"
source_url: "https://www.nature.com/articles/s41586-026-10757-4"
published_at: "2026-07-15T00:00:00Z"
reading_minutes: 4
related_story_ids: []
related_event_ids: []
model_provider: "openai"
model_name: "gpt-5.6-sol"
prompt_version: "verse-articles-v3"
researched_at: "2026-07-25T20:05:05Z"
---

# Measurement error may have hidden how hard the Sun can hit Earth

> A supposed ceiling on Earth’s response to extreme solar wind may be a statistical mirage. Correcting uncertainty restores a linear response across the observed range, removing the comfort of an apparent natural brake.

Solar-wind measurements are taken far upstream from Earth, then matched to magnetic activity near the poles. Timing and magnitude change along that path, so a measured extreme is more likely to correspond to a less-extreme true value near Earth than the raw number suggests.

If those noisy extremes are used as the horizontal axis of a regression, their smaller responses are assigned to values that were too large. The resulting curve bends and looks saturated even when the underlying response remains linear.

Regression calibration produced a linear relation up to 15 millivolts per metre. The paper’s statement that impacts could be twice previous estimates comes from extrapolating to about 25 millivolts per metre; data above 15 are too sparse to rule out saturation there.

## Why this was selected

It explains how ordinary uncertainty can manufacture a physical law, and why the same mistake can distort conclusions about other rare extremes.

## Sources

- [Regression to the mean can explain saturation of geomagnetic storms](https://www.nature.com/articles/s41586-026-10757-4) | Nature | 2026-07-15T00:00:00Z
- [Demonstrating regression to the mean of extreme geomagnetic storms](https://nithinsivadas.github.io/polar-cap-saturation/) | Nithin Sivadas | null
