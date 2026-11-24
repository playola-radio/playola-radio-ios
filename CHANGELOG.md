# Changelog

Don't edit this file in a pull request; add a file to changelog.d/ (see changelog.d/README.md).

## [Unreleased]

<!-- Don't add notes here. Each pull request adds a file to changelog.d/ (see changelog.d/README.md); scripts/release.sh collects them into a version section. -->

## [7.9.0] - 2026-11-23

### Changes

- Cancelling a message to the artist while recording now turns the microphone off and discards the recording, and "Try Again" can no longer be tapped while a message is sending.
- The "Message Sent!" confirmation no longer promises a notification when the reply airs.
- CarPlay now keeps showing what is playing, and the "Unable to Connect" message when a station fails, after you unplug and reconnect your car during the same listening session.
- Station owners can fill a series' open time slot by recording a new show for it or adding one of their existing shows, and can add an existing show to a series from its page.
- Tapping a prize giveaway just after it closes now tells you the giveaway has ended, instead of doing nothing.
- The giveaway tap button now goes away when the station cancels or reschedules the giveaway, and comes back at the new time.
- Giveaway tap messages now appear on the player screen instead of closing it.
- Station owners can now open Individual Shows from Upcoming to see every show that is not scheduled yet or still to air, with its day, time, length and series.
- Station owners can open Upcoming → Series to see each series' next shows and open weekly time slots, create a new series, and open a series to see its drafts and upcoming shows and edit its name and schedule.
- The note under your email on the Edit Profile screen now says it's linked to your sign-in account, instead of wrongly saying it's tied to an Apple ID when you signed in with Google.
- Removed the "…" button on the player screen that did nothing.
- The "…" button on each liked song is now read aloud as "More" by VoiceOver, and the station search clear button is read aloud as "Clear search".
- Tapping the empty space on Your Library now ends the presets edit mode.
- VoiceOver now announces the back button on Edit Profile and the edit button on your profile.
- Station owners can now build a recorded show from Individual Shows: add voicetracks, songs from their library and listener questions with answers, reorder or remove them, and rename the show, with every change saved automatically.
- Curators can now schedule a recorded show for a day and time, move it to a new time, and unschedule it from the show builder.
- Curators can now put a show in a series, move it to a different series, take it out of a series, or start a brand-new series right from the show builder.
- Siri no longer says a station is playing when it couldn't start; it now says it couldn't confirm the station started.
- In CarPlay on iOS 27, the Now Playing button opens the full Now Playing screen again, so you can stop playback from the car.
- The Station tab now groups its links into Shows (Live and Upcoming) and Library (Music and Breakers), and the Upcoming page lists how many series and individual shows are coming up.
- Fixed a song you unliked sometimes coming back as liked after your connection dropped while you were liking it.
