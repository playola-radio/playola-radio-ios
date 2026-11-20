"""Resets the staging data the add-show-to-series case needs. Run it just before recording:

    python3 qa/ux/add-show-to-series/prepare.py && make ux-evidence CASE=add-show-to-series

Uses the saved staging session (make ux-evidence-ios-login). Earlier runs' Series are renamed
"... old <n>"; their Shows lose their future airings and are deleted (renamed if they have aired), so
every run starts from the same data and the flow's slots are always the next ones from now.
"""
import json
import os
import re
import sys
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo

BASE = "https://admin-api-staging.playola.fm"
STATION = "06cdc91a-eb7b-490e-bafb-873df63b1415"  # 8750 Radio, the station picker's first row
SONG = "84232359-7876-43c6-b5e2-6eace134b68c"  # Play a Train Song
VOICE = "4abb52a8-5f06-4bad-b992-bdefddd937ca"
CENTRAL = ZoneInfo("America/Chicago")
SONGBOOK, DRIVE = "Saturday Night Songbook", "Friday Afternoon Drive"
SHOW_NAMES = [
    "Tour Stories", "Back Porch Requests", "Holiday Hangout", "Songs From the Road", "Empty Draft",
]

with open(os.path.expanduser("~/.config/playola-ux/ios-staging-auth.json")) as auth_file:
    JWT = json.load(auth_file)["jwt"]


def api(method, path, body=None, allow_failure=False):
    request = urllib.request.Request(
        BASE + path, method=method,
        data=json.dumps(body).encode() if body is not None else None,
        headers={"Authorization": f"Bearer {JWT}", "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(request) as response:
            text = response.read()
    except urllib.error.HTTPError as error:
        if allow_failure:
            return False
        sys.exit(f"{method} {path}: HTTP {error.code} {error.read().decode()[:300]}")
    return json.loads(text) if text else None


now = datetime.now(CENTRAL)
# The flow expects the Songbook's first slot (Saturday 8pm) to be outside the six-hour lock.
if now.weekday() == 5 and now.hour >= 12:
    sys.exit("Saturday afternoon: the Songbook's first slot is too close. Record another day.")

stamp = str(int(now.timestamp()) % 100000)
def is_earlier_run(title, names):
    return title in names or any(re.fullmatch(re.escape(n) + r" old \d+", title) for n in names)


all_series = api("GET", f"/v1/shows?stationIds={STATION}")
old_series = [s for s in all_series if s["title"] in (SONGBOOK, DRIVE)]
old_series_ids = {s["id"] for s in all_series if is_earlier_run(s["title"], (SONGBOOK, DRIVE))}
for series in old_series:
    api("PUT", f"/v1/shows/{series['id']}", {"title": f"{series['title']} old {stamp}", "rrule": None})
for episode in api("GET", f"/v1/episodes?stationIds={STATION}&includeAirings=true"):
    if not is_earlier_run(episode["title"], SHOW_NAMES) and episode["showId"] not in old_series_ids:
        continue
    for airing in episode.get("airings", []):
        if datetime.fromisoformat(airing["airtime"].replace("Z", "+00:00")) > now:
            api("DELETE", f"/v1/airings/{airing['id']}")
    # Earlier runs' Shows would otherwise pile up in the Add a show list. Only never-aired Shows can
    # be deleted; an aired one is renamed instead.
    if api("DELETE", f"/v1/episodes/{episode['id']}", allow_failure=True) is False \
            and episode["title"] in SHOW_NAMES:
        api("PUT", f"/v1/episodes/{episode['id']}", {"title": f"{episode['title']} old {stamp}"})

# "Friday Afternoon Drive" (despite its name) repeats at the next whole hour 2-3 hours away, so its
# first slot is inside the six-hour lock.
near = (now + timedelta(hours=3)).replace(minute=0, second=0, microsecond=0)
near_day = ["MO", "TU", "WE", "TH", "FR", "SA", "SU"][near.weekday()]
api("POST", "/v1/shows", {"stationId": STATION, "title": SONGBOOK,
                          "rrule": "FREQ=WEEKLY;BYDAY=SA;BYHOUR=20;BYMINUTE=0"})
api("POST", "/v1/shows", {"stationId": STATION, "title": DRIVE,
                          "rrule": f"FREQ=WEEKLY;BYDAY={near_day};BYHOUR={near.hour};BYMINUTE=0"})


def standalone(title, blocks):
    created = api("POST", "/v1/shows", {"stationId": STATION, "title": title, "isOneTime": True})
    episode = created["episodes"][0]
    if blocks:
        api("POST", f"/v1/episodes/{episode['id']}/segments", {"audioBlockIds": blocks, "position": 0})
    return episode


standalone("Tour Stories", [VOICE, SONG])
porch = standalone("Back Porch Requests", [VOICE, SONG, SONG])
# Scheduled the Wednesday after the first Saturday slot, at 8pm; the flow moves it into a slot.
first_saturday = (now + timedelta(days=(5 - now.weekday()) % 7)).replace(
    hour=20, minute=0, second=0, microsecond=0)
wednesday = first_saturday + timedelta(days=4)
api("POST", "/v1/airings", {"episodeId": porch["id"], "stationId": STATION,
                            "airtime": wednesday.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.000Z")})
standalone("Holiday Hangout", [VOICE, SONG])
standalone("Songs From the Road", [SONG, VOICE, SONG])
standalone("Empty Draft", [])
print(f"Ready. Songbook's first slot: {first_saturday:%a %b %d %I%p}; "
      f"Friday Afternoon Drive's: {near:%a %b %d %I%p}.")
