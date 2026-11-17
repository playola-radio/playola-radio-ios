# 002 — Manage series

A station curator can open their Series from Upcoming → "Series", see each Series' upcoming Shows and open weekly slots, create a Series, and open a Series page to edit its name and schedule. From any open slot — or the page's "Add a Show" button — they can record a new Show for the Series or put one of their existing Shows into it. This completes the recorded-shows feature.

**Words used here:** a **Show** is one recorded program (backend `Episode`); a **Series** is a named group of Shows with an optional weekly schedule (backend `Show`). A **draft** is a Show that isn't scheduled. A **slot** is a time the Series' weekly schedule suggests; it is **open** when no Show on the station airs at that time. Slots are suggestions only — an empty slot plays the station's regular programming.

**Builds on:** design 001 (Series picker and the New Series sheet), the Show builder, and the Schedule sheet (PR #493). Upcoming's "Series" row is on screen but does nothing yet; this design makes it work.

**Throughout:** loading uses the app's standard progress view; a failed load shows a toast and keeps what was shown; a failed action shows an alert with the server's message, then the screen refreshes from the server. Times are in the station's time zone (Central for every station), not the phone's. Hidden one-time Series (which hold standalone Shows) never appear. Aired Shows are not listed anywhere in this design. Shows with more than one airing (made on the website) are never offered in the Add a show sheet.

**Schedules in words:** a weekly schedule reads like "Every Sunday at 7pm" or "Every Tuesday and Thursday at 8pm". A Series with no schedule has no schedule badge, no open slots, and no slots note. A Series whose schedule the app can't read shows "Custom schedule" and offers no open slots.

## Screens

### Series list — Default

![Series list — default](screenshots/series-list--default.png)

- **What it is:** the station's Series as cards, titled "Series". Each card is styled like the listener app's Radio Shows card:
  - the Series name with a chevron;
  - the amber schedule badge ("Every Sunday at 7pm");
  - "UPCOMING SHOWS" with a count of what the card shows ("2 shows · 1 open");
  - the next 3 items in date order, mixing scheduled Shows and open slots:
    - a scheduled Show: a calendar tile, its name and "Sunday the 8th at 7pm";
    - an open slot: a grey calendar tile, "Sunday the 22nd · open" and "+ Add show".

  Drafts are not on the cards. A "Create a New Series" button sits at the bottom.
- **Reached by:** Upcoming → "Series".
- **State meaning:** the station has at least one Series.
- **Leaves by:**
  - A card's name → Series page.
  - A Show on a card → that Show's builder.
  - A slot's "+ Add show" → Add a show sheet for that slot.
  - "Create a New Series" → Series details sheet, New Series (see design 001's screenshot). Saving adds the new Series to the list.
  - Back → Upcoming.

### Series list — Empty (no mockup, described only)

- **State meaning:** the station has no Series yet.
- **What it shows:** the "Series" title and only the "Create a New Series" button — no cards.
- **Leaves by:** "Create a New Series" → New Series; saving shows the list with that Series' card. Back → Upcoming.

### Series page — Default

![Series page — default](screenshots/series-page--default.png)

- **What it is:** one Series, titled with its name, with "Edit" at the top right. From top to bottom:
  - the amber schedule badge;
  - the note "Open slots are only suggestions. If you leave one empty, your station plays as usual.";
  - **NOT SCHEDULED YET:** this Series' drafts (pencil tile, name, "Not scheduled yet · 20 min").
  - **UPCOMING:** this Series' scheduled Shows ("Sunday · 7:00 PM · 38 min") and its next 8 open slots ("Open", "Sunday · 7:00 PM", "+ Add show"), together in date order.
  - an "Add a Show" button at the bottom.
- **Reached by:** Series list → a card's name.
- **State meaning:** always this state.
- **Leaves by:**
  - "Edit" → Series details sheet, Edit Series.
  - A Show (either section) → that Show's builder; coming back shows any changes.
  - A slot's "+ Add show" → Add a show sheet for that slot.
  - "Add a Show" → Add a show sheet with no slot.
  - Back → Series list.

### Series page — Empty sections (no mockup, described only)

- **State meaning:** one or both sections have nothing to list. NOT SCHEDULED YET is empty when the Series has no drafts. UPCOMING is empty only when the Series has no scheduled Shows and no open slots, which means it has no schedule or a "Custom schedule". A weekly schedule always has open slots.
- **What it shows:** the section heading stays. Under it, in place of rows, is one line of grey text:
  - NOT SCHEDULED YET: "No drafts in this series."
  - UPCOMING: "No upcoming shows."

  The rest of the page, including "Add a Show", is unchanged.
- **Leaves by:** the same ways as the default state.

### Series details sheet — Edit Series

![Series details sheet — edit series](screenshots/series-details-sheet--edit-series.png)

- **What it is:** the New Series sheet from design 001, titled "Edit Series" and filled in with the Series' name, Repeats, Days and Time. The note reads "Changing the schedule only changes your open slots. Shows that are already scheduled keep their times."
- **Reached by:** Series page → "Edit".
- **State meaning:** editing an existing Series. Save is disabled while the name is empty, or while "Every week" is chosen with no day selected. Choosing "No schedule" hides Days and Time and clears the schedule on Save.
- **Leaves by:**
  - Save → saves and closes. The page shows the new name and schedule, and its open slots follow the new schedule. Shows already scheduled keep their times.
  - Cancel or swipe down → closes; nothing changes.

### Series details sheet — Custom schedule (no mockup, described only)

- **State meaning:** editing a Series whose schedule the app can't read.
- **What it shows:** the Edit Series sheet with the Name field editable. In place of Repeats, Days and Time is a read-only "Custom schedule".
- **Leaves by:** Save → renames the Series and leaves its schedule exactly as it was. Cancel or swipe down → nothing changes.

### Add a show sheet — From a slot

![Add a show sheet — from a slot](screenshots/add-a-show-sheet--from-a-slot.png)

- **What it is:** a sheet titled "Add a show", with a subtitle naming the Series and the slot ("This One's For You · Sunday, Nov 22 at 7pm"). It contains:
  - a "Record a New Show — Start from scratch for this slot" row;
  - under "OR ADD ONE OF YOUR SHOWS", the Shows that can go in this slot, each with "Add":
    - drafts with at least one piece of audio ("Not scheduled yet · 18 min");
    - scheduled Shows that aren't locked ("Moves here from Sun, Nov 8 · 42 min").

  Shows may be standalone or in another Series; adding one moves it into this Series. This Series' own Shows are not offered. Locked Shows are not offered (airing within 6 hours, on air, or aired), and neither are Shows with more than one airing.
- **Reached by:** a slot's "+ Add show" on the Series list or the Series page.
- **State meaning:** adding to a specific slot.
- **Leaves by:**
  - "Record a New Show" → the builder for a new Show in this Series; its Schedule step offers this slot first. Nothing is saved until the first change in the builder.
  - "Add" on a draft → schedules it at the slot's time, then puts it in this Series; the sheet closes and the screen behind it refreshes.
  - "Add" on a scheduled Show → moves it to the slot's time, then puts it in this Series; the sheet closes and the screen refreshes.
  - "Add" when the slot is less than 6 hours away → opens the Schedule sheet set to that slot instead (next screen); scheduling there finishes the add.
  - If scheduling or moving is refused, an alert shows the server's message and the Show is unchanged.
  - If the Show is scheduled but putting it in the Series fails, an alert says so. The Show stays scheduled at the slot's time, outside this Series; the curator can fix that from the builder's Series row.
  - Swipe down → closes; nothing changes.

### Add a show sheet — No slot (no mockup, described only)

- **State meaning:** opened from the Series page's "Add a Show" button, with no slot.
- **What it shows:** the same sheet. The subtitle names only the Series. "Record a New Show" is followed by the same list of Shows, except that scheduled Shows show their own air time and length ("Sun, Nov 8 · 42 min") instead of "Moves here from …".
- **Leaves by:**
  - "Record a New Show" → the builder for a new Show in this Series; its time is picked in the Schedule step.
  - "Add" → puts the Show in this Series without changing its air time (a draft stays a draft); the sheet closes and the page refreshes.
  - Swipe down → closes.

### Add a show sheet — Nothing to offer (no mockup, described only)

- **State meaning:** no Show qualifies for the list, either from a slot or with no slot.
- **What it shows:** the title, subtitle and "Record a New Show" only. The "OR ADD ONE OF YOUR SHOWS" heading is hidden.

### Schedule sheet — Locks right away (opened from Add a show)

![Schedule sheet — locks right away](screenshots/schedule-sheet--locks-right-away.png)

- **What it is:** the existing Schedule sheet (PR #493). It is unchanged; the mockup happens to show it over the builder.
- **Reached by:** "Add" in the Add a show sheet when the slot is less than 6 hours away. It opens set to the slot's day and time, so the "Locks right away" note shows before anything is scheduled.
- **State meaning:** the picked time is less than 6 hours away, so the Show's content and time lock as soon as it is scheduled.
- **Leaves by:**
  - "Schedule" → schedules (or moves) the Show, then puts it in the Series, as in the slot flow above; both sheets close.
  - Cancel or swipe down → closes; nothing is scheduled.

## Done when

- [ ] Upcoming → "Series" opens the Series list, matching its mockup. With no Series it shows only "Create a New Series".
- [ ] Each card shows its next 3 items (scheduled Shows and open slots in date order) and a count that matches them. A slot already taken by any Show on the station is never shown as open.
- [ ] A Series with no schedule shows no badge, no slots and no slots note. An unreadable schedule shows "Custom schedule" and no slots.
- [ ] Open slots and times are correct in Central time regardless of the phone's time zone, including across both daylight-saving changes.
- [ ] A card's name opens the Series page, matching its mockup: drafts under NOT SCHEDULED YET; scheduled Shows plus the next 8 open slots under UPCOMING, in date order.
- [ ] An empty section keeps its heading and shows its message ("No drafts in this series." / "No upcoming shows.") in place of rows.
- [ ] Creating a Series from the list adds its card. Editing a Series' name or schedule updates the page and its open slots, and leaves already-scheduled Shows' times alone.
- [ ] Edit Series' Save is disabled while the name is empty, or while "Every week" has no day. A "Custom schedule" Series can be renamed without changing its schedule.
- [ ] From a slot, adding a draft schedules it at that time and puts it in the Series; adding a scheduled Show moves it there and puts it in the Series. Both then show in that slot on the page.
- [ ] If joining the Series fails after scheduling succeeds, an alert says so and the Show stays scheduled at the slot's time.
- [ ] A slot less than 6 hours away opens the Schedule sheet at that slot with "Locks right away" showing.
- [ ] The Add a show sheet never offers locked Shows, Shows with more than one airing, drafts without audio, or this Series' own Shows.
- [ ] "Add a Show" with no slot puts the chosen Show in the Series without changing its time.
- [ ] "Record a New Show" from a slot opens the builder for a new Show in the Series, with the slot offered first in its Schedule step. Backing out without changes leaves nothing behind.
