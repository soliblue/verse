# Berlin culture explore

## Goal

Make the Berlin discoveries useful inside Verse: show a small, current list of nearby events, retain promising venues as places to watch, and learn from attendance and reactions without turning the app into an infinite event feed.

## Status

Implemented for v0. Dedicated venue adapters and a map remain optional follow-ups.

## Product outcome

- Today may include at most one or two urgent Berlin picks when they genuinely deserve space in the edition.
- Explore is a separate finite view for Tonight, Tomorrow, Weekend, and Later.
- Places shows watched venues and their next worthwhile event.
- Past events remain available only as attended history and ranking evidence.
- Exact home location is private configuration and is never checked into the repository or emitted in logs.
- Proximity is calculated from a private local anchor. Positive fixtures describe qualities such as nearby, free, social, independent, and culturally surprising without recording personal location history.

## What the app should understand

### Event

An event is time-sensitive and may have several occurrences. It needs:

- Stable identifier and dedupe key.
- Name, short description, categories, and selection reason.
- Start and end time in `Europe/Berlin`.
- Venue identifier and organizer when different.
- Address, coordinates, and a coarse distance band from the private anchor.
- Price, reduced price, free flag, RSVP requirement, booking URL, and sold-out state.
- Languages, accessibility notes, age limits, and outdoor or weather dependency when known.
- Official source URL, source name, checked timestamp, and supporting evidence.
- Recurring-series identifier for events such as Open Screening, Berlin Beats, and Sky Sounds.
- State: upcoming, happening, ended, cancelled, or unknown.
- Novelty state: new, meaningful update, final chance, or previously reported.

### Venue

A venue is a durable place worth monitoring. It needs:

- Stable identifier, name, address, coordinates, neighborhood, and official URL.
- Event-calendar URLs and any trusted secondary sources.
- Typical formats and why the place matches the user's taste.
- Distance band from the private anchor: walkable, short ride, or destination.
- Watch state: favorite, watch, muted, or archived.
- Last successful check and next scheduled check.
- Known access details such as entrance, nearest station, and cashless-only rules.

### Personal signals

- Interested.
- Going.
- Attended.
- Loved.
- Not for me.
- Too far.
- Too expensive.
- Sold out before I could book.
- More from this venue.
- More events like this.

The first positive regression fixture is a nearby independent screening marked attended and loved.

## Explore experience

### Entry point

Add `Explore` to the existing pixel navigation menu and keep the hidden `TabView` plus one `NavigationStack` per tab. Do not add persistent navigation chrome.

### Main view

Show no more than 12 live choices, grouped only when useful:

- Tonight.
- Tomorrow.
- This weekend.
- Later, limited to unusually strong advance-booking or one-off events.

Each row shows title, date and time, venue, distance, price, and one short reason. Free and sold-out states must be immediately visible.

Default ordering:

1. Happening soon and still attendable.
2. Strong taste match.
3. Walkable or short bicycle ride.
4. Free or inexpensive.
5. Unusual, participatory, independent, or one-off.
6. Newly announced or final chance.

### Places view

Explore includes a Places switch rather than a separate permanent tab. Each place shows:

- Why it is watched.
- Distance band.
- Next strong event.
- Recent attended event when relevant.
- Official calendar link.
- `More from here` and `Mute this place` actions.

Start with a list, not a map. Add a map only after the list proves that spatial browsing materially helps.

### Calendar view

Explore includes a Calendar switch alongside List and Places.

- Default to a compact week view centered on today.
- Mark dates containing events and show that day's finite event list below the calendar.
- Include every verified upcoming occurrence in the calendar index, even when it is not selected for the 12-item featured list.
- Allow browsing future weeks containing verified events without creating an infinite scrolling feed.
- Use the same event occurrence objects, filters, dedupe rules, sold-out state, and event detail as the main list.
- Keep past dates visually quiet; attended events may remain visible as personal history, while unattended expired events disappear from the default view.
- Show Berlin-local dates consistently even when the phone is temporarily in another timezone.

### Event detail

Keep it operational:

- Exact date, doors and start time.
- Price and booking status.
- Route button to the venue through Apple Maps. The phone supplies routing context locally.
- Official source and last-checked time.
- Why it was selected.
- Going, attended, loved, and dismiss actions.
- Add to Calendar action.
- Related venue and the next two non-duplicate events there.

### Apple Calendar integration

Use EventKit and the native event editor rather than building calendar synchronization on the server.

- `Add to Calendar` is available on event rows, event detail, and any article linked to an event occurrence.
- The native editor is prefilled with title, start and end time, venue address, official URL, price or RSVP note, and a short Verse selection reason.
- The user chooses the destination calendar and confirms the save; Verse never silently writes an event.
- Request calendar write access only when the user first taps the action, not during app launch.
- If permission is denied, show a short explanation and a Settings link while preserving an `Open official event` fallback.
- Store the resulting EventKit identifier locally against the occurrence so the button becomes `View in Calendar` and repeated taps do not create duplicates.
- If the occurrence changes after export, show `Event updated` with explicit choices to update the phone event or leave it unchanged.
- If an event is cancelled, warn the user but never delete the phone-calendar entry automatically.
- Calendar identifiers remain device-local and are not placed in API payloads or Nightjar content.

### Event-related articles

- A `StoryItem` may reference one or more event occurrence identifiers through an optional `related_event_ids` field.
- An event-related article shows a compact date, venue, price, and booking-status block above its normal story actions.
- Its `Add to Calendar` button resolves the same occurrence used by Explore, so export state and updates remain consistent everywhere.
- Articles remain readable after an event ends, but their action changes from `Add to Calendar` to `Event ended` or `Mark attended`.

## Editorial rules

- The normal horizon is tonight plus six days.
- Weekday evenings and weekends rank above weekday daytime listings.
- Prefer audiovisual installations, light and sound art, experimental film, short-film programs, open houses, artist talks, Arabic poetry or music, street music, exceptional markets, participatory happenings, free park concerts, public gatherings, and astronomical one-offs.
- Check Hamburger Bahnhof, Gropius Bau, Neue Nationalgalerie, and similar institutions, but do not overfill Explore with ordinary exhibitions.
- A newly opened exhibition may appear once. Repeat only for a meaningful update, a particularly relevant program date, or final chance.
- Recurring series receive one series identity and separate occurrences; do not rediscover them as unrelated events.
- Venue pages are authoritative for time, price, RSVP, sold-out state, and access.
- Expired events never remain in the live list.
- Generic club nights, commercial concerts, and broad recurring markets are omitted unless there is a specific exceptional edition.

## Seed event inventory

This inventory preserves everything surfaced during the initial research. Past items are taste evidence and regression fixtures, not upcoming recommendations.

### Film and moving image

- Sputnik Open Screening, Sputnik Kino: monthly open short-film screening.
- Artist Films, Kantine am Berghain: artist moving-image program.
- British Shorts Summer Edition: curated short-film program.
- Berlin Short Film Festival: independent short-film festival.
- Shortcutz Berlin: recurring short-film screening and filmmaker gathering.
- Niñxs - Das Leben glitzert, Freiluftkino Hasenheide, 17 July 2026.
- It's Never Over, Jeff Buckley, Freiluftkino Hasenheide, 22 July 2026.
- American Movie Nights, Neulich Biergarten at THF, 21 to 23 July 2026: `Elvis`, `A Complete Unknown`, and `Walk the Line`; free.
- Mini-Kino auf Rädern, Park am Buschkrug, 24 July 2026: tiny mobile cinema with a short science-fiction animation; free.
- Scherbenland, Freiluftkino Hasenheide, 30 July 2026: Ton Steine Scherben, Kreuzberg, music, poetry, and resistance.
- Get Fucked in Hasenheide with Olympia Bukkakis, Freiluftkino Hasenheide, 1 August 2026.
- Kuzunguka video evening, Kunstverein Neukölln, 5 August 2026: works by Anders Bigum and Jakob Kirchheim.

### Sound, music, and audiovisual work

- SOUND AND FLUIDS: Lolina, Julia Stoschek Foundation, 14 July 2026: spatial live Berlin premiere; free RSVP and sold out.
- Berlin Beats: GiGi FM, Hamburger Bahnhof garden, 16 July 2026; free.
- Honey Lou x Gato-Sapato, THF Tower, 16 July 2026: Brazilian music with a Berlin touch.
- KafaNar, THF Tower, 17 July 2026: Kaval, Duduk, Caglama, Anatolian vocals, and loops.
- DayDreamLab by Transmission, THF Tower, 18 July 2026: inclusive all-ages rooftop rave and community gathering.
- FIREFLY Sound Festival, 25 July 2026.
- Konrad Kuechenmeister, Park am Buschkrug, 24 July 2026: live looping and improvised sound worlds; free.
- Oran Ray - The Drummer, THF Tower, 23 July 2026: live jungle and breakbeat built with drums and hardware electronics.
- Jamila & The Other Heroes, Luftschloss Tempelhofer Feld, 25 July 2026: Arabic and English psychedelic desert rock.
- Sound Experience - Alte Instrumente. Neue Sounds. Open Jam, THF Tower, 30 July 2026: classical instruments, live electronics, and audience jam.
- Sky Sounds with Neoangin aka Jim Avignon, THF Tower, 31 July 2026.
- Activist Sonic Storytelling, Spore Initiative, 1 August 2026: participatory sound, spoken word, movement, and collective composition; free with registration.
- Salsa Azul, Luftschloss Tempelhofer Feld, 2 August 2026: free 15-piece salsa concert and dancing.
- NUN x THF, THF Tower, 6 August 2026: live music, DJs, and interactive art.
- Nauti Siren x Super DJ Dmitry, THF Tower, 7 August 2026.
- LAZ BRUJAZ & amigas, Luftschloss Tempelhofer Feld, 8 August 2026: immersive jazz, Spanish and Latin music, dance, improvisation, and flamenco.
- Sky Sounds with Grateful Cat, THF Tower, 14 August 2026.
- Schwarzes Gold, THF Tower, 27 August 2026: bring a favorite record and share its story.
- Sky Sounds with Mittekill, THF Tower, 28 August 2026.
- A-Side Berlin, THF Tower, 29 August 2026: BIPoC and queer house-music community gathering.

### Exhibitions, open houses, and artist programs

- UdK Rundgang 2026, multiple UdK sites, 17 to 19 July 2026: free annual open house.
- Gabriele Stoetzer exhibition, Gropius Bau.
- 10 Years KINDL, KINDL Centre for Contemporary Art, 18 July 2026.
- Pomo Weavers Society, 19 July 2026.
- Nach Bild - Under Stimulation, Galerie im Saalbau, from 11 July 2026: participatory eclipse film, infrasound, retinal afterimages, and robot-controlled massage beds.
- Nach Bild artist talk, Galerie im Saalbau, 24 July 2026; free.
- Berlin, the Bitch and the Witch, Kunstbruecke am Wildenbruch, 13 June to 23 August 2026.
- Berlin, the Bitch and the Witch performances, Kunstbruecke am Wildenbruch, 25 July 2026; free.
- IBA Berlin 2034-37 opening exhibition, Alte Feuerwache at THF Tower, 1 to 26 July 2026; free.
- Lebende Infrastruktur - 8 Years Floating University, Floating University Berlin.
- Floating Open Thursday, Floating University Berlin, 16 July 2026.
- Weirder, Louder, Taller, Uglier - For Weeds to Rewild, Galerie im Koernerpark.
- Um|Benennen - Neukoelln und seine Strassennamen, Museum Neukoelln.

### Public, participatory, and neighborhood events

- Dein Sommer im Park, Neukoelln parks, including 17 and 24 July 2026; free performances and concerts.
- Playfight in Hasenheide, 19 and 26 July 2026: weather-dependent community sessions.
- Tausch- und Sperrmuellmarkt, Herrfurthplatz, 22 July 2026; free.
- Soil Social Club, Atelier Gardens, 21 July 2026: participatory gardening and compost session; free with RSVP.
- berlin:mixed, Tempelhofer Feld, 24 to 26 July 2026: world's largest all-gender bike-polo tournament; free.
- Observant Nature, Spore Initiative, 26 July 2026: bilingual guided attention practice; free with registration.
- IBA neighborhood and architecture exhibition activity at THF Tower.
- Berlin Bicycle Market, Campus Ruetli, 1 August 2026: used bicycles, repairs, and children's swap.
- Get-together and screenings associated with the U.S. Embassy's American Movie Nights.
- Jordan flea market at Lohmuehlenstrasse and Jordanstrasse, 19 July 2026: vintage, design, books, music, and live bands.

### Poetry, spoken word, and performance

- Poetry Slam with Kunst & Krawall, THF Tower, 9 July 2026.
- Impro mit den Gorillas - Alles im Eimer, Luftschloss Tempelhofer Feld, 16 July 2026.
- Kiezpoeten: Best of Poetry Slam, Luftschloss Tempelhofer Feld, 7 August 2026.
- Gender Punks reading with Kuku Schrapnell, THF Tower, 13 August 2026.

## Seed venue inventory

### Immediate neighborhood and short ride

- Sputnik Kino, Hasenheide 54: independent cinema and Open Screening; highest-priority watch venue.
- Freiluftkino Hasenheide: outdoor cinema and special participatory screenings.
- Volkspark Hasenheide: public gatherings, playfight, park culture, and one-off observations.
- Genezarethkirche and Startbahn, Herrfurthplatz: neighborhood gatherings, music, workshops, and community programs.
- Herrfurthplatz: swap markets and neighborhood happenings.
- Tempelhofer Feld: unusual public gatherings, bike polo, concerts, ecology, and participatory events.
- Floating University Berlin: experimental architecture, ecology, installations, and public programs.
- KINDL Centre for Contemporary Art: contemporary exhibitions, performances, and open-house dates.
- Galerie im Saalbau: experimental and participatory exhibitions and artist talks.
- Kunstverein Neukoelln: experimental film, artist-run exhibitions, and video evenings.
- Kunstbruecke am Wildenbruch: small public art venue and performance program.
- Spore Initiative, Hermannstrasse 86: workshops, ecological practice, sound, movement, and political art.
- Museum Neukoelln: local history and socially engaged exhibitions.
- Galerie im Koernerpark: municipal contemporary art exhibitions.
- Atelier Gardens, Oberlandstrasse 26-35: film, creative practice, gardening, and community programming.
- Park am Buschkrug: free district-funded theater, mobile cinema, and concerts.
- Campus Ruetli: bicycle market and neighborhood exchange.
- Lohmuehlenstrasse and Jordanstrasse market area: exceptional flea-market editions and live music.
- Wolf Kino, Weserstrasse 59: independent cinema, filmmaker events, and workshops.
- IL Kino: independent and international cinema.
- Moviemento: independent cinema and festival venue.
- Klunkerkranich: rooftop music and occasional cultural programs.

### Tempelhof cultural cluster

- THF Tower, Tempelhofer Damm 45: rooftop music, performance, sound art, readings, exhibitions, and views.
- Neulich Biergarten at THF: free screenings, festivals, music, and public gatherings.
- Luftschloss Tempelhofer Feld: open-air theater, concerts, poetry, comedy, and free special programs.
- Alte Feuerwache at THF Tower: architecture and urban-development exhibitions.
- Flughafen Tempelhof visitor center and hangars: exhibitions, open-house events, screenings, and large cultural programs.

### Destination institutions and recurring sources

- Hamburger Bahnhof: contemporary art and the free Berlin Beats garden series.
- Gropius Bau: major contemporary exhibitions and performance programs.
- Neue Nationalgalerie: priority museum for newly opened relevant exhibitions.
- Julia Stoschek Foundation Berlin: moving image, spatial sound, and performance; entrance on Jerusalemer Strasse.
- UdK Berlin sites, especially Hardenbergstrasse: annual Rundgang and public student work.
- Kantine am Berghain: artist film and experimental programs.
- silent green: sound, film, festivals, and interdisciplinary work.
- Haus der Kulturen der Welt: exhibitions, discourse, sound, performance, and moving image.
- P61 Gallery: digital and audiovisual art.
- Deutsche Oper Berlin: technically ambitious music theater.
- SAVVY Contemporary: sound, performance, decolonial practice, and Sonic Pluriverse.

## Collection and ranking

### Sources

- Poll watched venue calendars first.
- Use Berlin.de, visitBerlin, Umweltkalender, and district culture pages for discovery.
- Treat aggregators only as leads; verify every selected event on the venue or organizer page.
- Preserve the exact source excerpt that supports time, price, access, and booking state.
- Recheck urgent events on the day they appear in Today or Explore.

### Dedupe

- Normalize titles, venue, organizer, and occurrence time before enrichment.
- Link multiple source pages to one event occurrence.
- Keep series identity separate from occurrence identity.
- Store `first_reported_at` and `last_meaningful_update_at` so Nightjar can enforce the no-repeat rule.
- Treat changed price, new ticket release, sold-out status, cancellation, added performance, and final weekend as meaningful updates.

### Ranking profile

Initial positive weights:

- Within walking distance or a short bicycle ride.
- Free or under EUR 10.
- Independent cinema and short film.
- Audiovisual, spatial sound, light, installation, and experimental moving image.
- Public, participatory, community-run, open-house, or one-off.
- Arabic poetry, Arabic music, diaspora culture, and multilingual programs.
- Artist talks and events where the work can be experienced rather than only viewed.
- Government-funded park culture and genuinely exceptional markets.

Initial negative weights:

- Generic recurring nightlife.
- Ordinary commercial concerts.
- Broad listings with no verified official page.
- Events already shown without an update.
- Long travel for a weak match.
- Sold-out events unless marked as attended, booked, or waitlist-relevant.

## Storage direction

The event feature must work whether Verse keeps SQLite or adopts the file-first direction in plan 05.

### Transport contracts

- Add `EventItem`, `EventOccurrence`, `Venue`, `EventFeedback`, and `ExplorePayload` JSON contracts.
- Add optional `related_event_ids` to `StoryItem`; absence preserves compatibility with ordinary articles.
- `ExplorePayload` is materialized nightly with no more than 12 featured events, watched-place summaries, and a compact calendar index containing all verified occurrences in the configured planning horizon.
- Cache the payload locally so Explore works offline.
- Send event feedback through the existing mutation-outbox pattern.
- Keep EventKit identifiers and calendar permission state in device-local storage only.

### SQLite option

- `venues` stores durable place metadata and watch state.
- `event_series` stores recurring identity.
- `event_occurrences` stores time-sensitive instances and booking state.
- `event_sources` stores evidence and checked timestamps.
- `event_feedback_events` stores append-only personal signals.
- `explore_snapshots` stores validated materialized payloads.

### File-first content

```text
content/
  places.md
  events/
    upcoming/
    archive/
  explore/
    current.json
```

Human-editable event and venue files remain authoritative; `current.json` is generated transport output. SQLite retains event and venue feedback, watch state, relations, and materialized snapshots.

## API direction

- `GET /v1/explore` returns the current finite Explore payload.
- `GET /v1/venues` returns watched venues and their next strong event.
- `POST /v1/event-feedback` records going, attended, loved, dismissal, distance, and price signals.
- Topic editing continues to manage broad interests; venue watch state is managed from Explore.
- Do not add accounts, social features, public sharing, background location, or push notifications in the first version.

## Implementation sequence

1. Finalize event, occurrence, venue, source-evidence, and feedback contracts.
2. Convert the seed inventories above into editable fixtures without committing the private home address.
3. Add venue-calendar collectors for Sputnik, Freiluftkino Hasenheide, Floating University, KINDL, THF, Luftschloss, Spore, municipal Neukölln galleries, and the four priority museums.
4. Normalize times to `Europe/Berlin`, deduplicate series and occurrences, and expire ended events.
5. Add distance bands using a locally configured anchor and avoid storing route histories.
6. Materialize a maximum-12-item Explore payload with novelty and no-repeat enforcement.
7. Add the Explore tab with List, Calendar, and Places modes, plus event detail, route, and feedback actions.
8. Add optional event references to articles and render the shared event summary block.
9. Add EventKit export through the native event editor, device-local identifier persistence, duplicate protection, and update handling.
10. Add offline caching and the pending-mutation outbox for event feedback.
11. Feed attended and loved signals into Nightjar ranking while keeping article and event feedback distinguishable.
12. Test with the Sputnik outcome, a free nearby event, a paid rooftop event, a sold-out event, a recurring series, a cancellation, an updated occurrence, and an expired event.
13. Run backend contract tests, Swift decoding tests, EventKit adapter tests, UI tests, simulator smoke launch, and screenshot review.
14. Use it privately for several nightly editions before deciding whether a map or reminders are justified.

## Acceptance criteria

- Explore never shows more than 12 live events.
- The 12-item limit applies to the featured list; Calendar can expose every verified occurrence in its planning horizon.
- Tonight and weekend items are correct for Berlin local time.
- Ended and cancelled events cannot appear as attendable.
- Free, price, RSVP, and sold-out states are visible without opening detail.
- The same occurrence is not repeated unless its status meaningfully changes.
- A recurring series does not flood the list.
- A nearby independent screening can be marked attended and loved, and that signal improves similar future rankings.
- The exact home address is absent from tracked files, API payloads, diagnostics, and screenshots.
- Venue pages show the next strong event and can be watched or muted.
- Calendar mode shows the same deduplicated occurrences as List mode and uses Berlin-local dates.
- An event can be added to a user-selected Apple Calendar from Explore or from a related article.
- Calendar access is requested only after an explicit tap, and Verse never silently saves, edits, or deletes a calendar event.
- Repeated export taps cannot create duplicate phone-calendar entries.
- A changed or cancelled source occurrence produces a warning without silently mutating the user's calendar.
- Explore remains readable offline.
- Today remains a finite morning edition rather than becoming an event feed.

## Decisions

- Events are first-class time-aware objects, not `StoryItem` variants.
- Explore is a hidden-tab destination reached through the existing navigation menu.
- The first UI is a finite List, Calendar, and Places view, not a map.
- Proximity uses a private configured anchor and coarse displayed distance.
- The initial horizon is seven days, with a small Later section only for exceptional advance-planning items.
- Apple Calendar export uses EventKit's native confirmation UI and stores linkage only on the device.
- Articles and Explore share the same event occurrence contract and calendar-export state.
- Past research is retained as seed and taste evidence but never presented as current without re-verification.
- Nightjar reads the calendar URLs in `content/places.md` during each isolated run. Dedicated deterministic adapters remain deferred until a source proves stable enough to justify one.

## Log

- 2026-07-16: Captured the request to translate the Berlin event research and discovered venues into Verse.
- 2026-07-16: Chose first-class events, a finite Explore view, a venue watchlist, and private proximity ranking.
- 2026-07-16: Recorded the initial public event and venue inventory while keeping personal history in private configuration.
- 2026-07-16: Added an in-app week calendar and explicit Apple Calendar export from both events and event-related articles.
- 2026-07-16: Implemented Markdown events and places, the finite Explore payload, SQLite relations and feedback, offline iOS caching, List, Calendar, Places, EventKit export, and Today's two-event cap.
- 2026-07-16: Materialized 8 featured choices, 10 calendar occurrences, watched places, and bounded attended history from durable feedback.
- 2026-07-16: Enforced cross-night occurrence and series suppression with exceptions for meaningful updates and final chances.
- 2026-07-16: Completed explicit EventKit handling for new, changed, cancelled, and ended occurrences without silently writing or deleting phone events.
- 2026-07-16: Verified decoding, ranking, expiry, feedback, calendar state, UI behavior, offline use, simulator smoke launch, and visual screenshots in CI.
