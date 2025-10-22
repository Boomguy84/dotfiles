#!/usr/bin/env python3
"""
Waybar output for London Transit (GTFS-RT protobuf)
- Prints one JSON line: {"text": "...", "tooltip": "...", "class": "..."}
- Uses nearest stop on the chosen route from your lat/lon
- Tooltip shows next 3 trips with *scheduled* times (and realtime if different)
- Robust to LTC's stop_id/stop_code mismatch; retries network; no extra packages beyond gtfs-realtime-bindings.

Requires: pip install gtfs-realtime-bindings
"""

import argparse, io, os, sys, zipfile, math, time, json, csv, random, gzip, re
from datetime import datetime, timezone
from urllib.request import urlopen, Request
from urllib.error import URLError, HTTPError
from google.transit import gtfs_realtime_pb2  # pip install gtfs-realtime-bindings

# ---------- defaults ----------
DEFAULT_LAT = 43.00505396346479
DEFAULT_LON = -81.27550853770616

# LTC protobuf feeds
GTFS_ZIP_URL      = "https://www.londontransit.ca/gtfsfeed/google_transit.zip"
TRIP_UPDATES_PB   = "http://gtfs.ltconline.ca/TripUpdate/TripUpdates.pb"
VEH_POSITIONS_PB  = "http://gtfs.ltconline.ca/Vehicle/VehiclePositions.pb"

# HTTP settings
REQUEST_HEADERS = {
    "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) GTFS-Client/waybar",
    "Accept": "application/x-google-protobuf, */*;q=0.1",
    "Accept-Encoding": "gzip, deflate",
    "Connection": "close",
}
DEFAULT_TIMEOUT = 12
MAX_RETRIES = 4
BACKOFF_BASE = 0.5

# ---------- utils ----------
def read_csv_from_zip(zf: zipfile.ZipFile, name: str):
    with zf.open(name) as f:
        txt = io.TextIOWrapper(f, encoding="utf-8-sig")
        return list(csv.DictReader(txt))

def haversine_km(lat1, lon1, lat2, lon2):
    R = 6371.0088
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dphi = p2 - p1
    dl = math.radians(lon2 - lon1)
    a = math.sin(dphi/2)**2 + math.cos(p1)*math.cos(p2)*math.sin(dl/2)**2
    return 2*R*math.asin(math.sqrt(a))

def now_epoch(): return int(time.time())

def epoch_to_local_str(ts):
    dt = datetime.fromtimestamp(ts, tz=timezone.utc).astimezone()
    return dt.strftime("%Y-%m-%d %I:%M:%S %Z")

def hhmm_local(ts):
    dt = datetime.fromtimestamp(ts, tz=timezone.utc).astimezone()
    return dt.strftime("%I:%M")

def http_get(url, timeout=DEFAULT_TIMEOUT, debug=False):
    last_err = None
    for attempt in range(MAX_RETRIES):
        try:
            req = Request(url, headers=REQUEST_HEADERS, method="GET")
            with urlopen(req, timeout=timeout) as r:
                data = r.read()
                if r.headers.get("Content-Encoding","").lower() == "gzip":
                    data = gzip.decompress(data)
                return data
        except (HTTPError, URLError, OSError) as e:
            last_err = e
            if debug:
                sleep_s = BACKOFF_BASE*(2**attempt) + random.uniform(0,0.2)
                print(f"[debug] GET error on {url}: {e} (retry {attempt+1}/{MAX_RETRIES} in {sleep_s:.2f}s)", file=sys.stderr)
                time.sleep(sleep_s)
            else:
                time.sleep(0.2)
    raise last_err

def ensure_gtfs_local(cache_path="gtfs_cache.zip", debug=False):
    if os.path.exists(cache_path) and os.path.getsize(cache_path) > 0:
        try:
            with zipfile.ZipFile(cache_path) as z:
                if "stops.txt" in z.namelist() and "routes.txt" in z.namelist():
                    return cache_path
        except zipfile.BadZipFile:
            pass
    data = http_get(GTFS_ZIP_URL, timeout=30, debug=debug)
    with open(cache_path, "wb") as f:
        f.write(data)
    return cache_path

def load_static_gtfs(cache_path="gtfs_cache.zip"):
    zf = zipfile.ZipFile(cache_path)
    routes     = read_csv_from_zip(zf, "routes.txt")
    trips      = read_csv_from_zip(zf, "trips.txt")
    stops      = read_csv_from_zip(zf, "stops.txt")
    stop_times = read_csv_from_zip(zf, "stop_times.txt")
    return routes, trips, stops, stop_times

def find_route_ids_by_short_name(routes, short_name: str):
    return {r["route_id"] for r in routes if r.get("route_short_name","") == short_name}

def stops_for_route(route_ids, trips, stop_times):
    trip_ids = {t["trip_id"] for t in trips if t["route_id"] in route_ids}
    stop_ids = {st["stop_id"] for st in stop_times if st["trip_id"] in trip_ids}
    return stop_ids, trip_ids

def nearest_stops_on_route(user_lat, user_lon, route_stop_ids, stops, k=6):
    cand = []
    for s in stops:
        if s["stop_id"] in route_stop_ids:
            try:
                lat=float(s["stop_lat"]); lon=float(s["stop_lon"])
            except Exception:
                continue
            cand.append((haversine_km(user_lat,user_lon,lat,lon), s))
    cand.sort(key=lambda x:x[0])
    return cand[:k]

def build_stop_maps(stops):
    by_id   = {s["stop_id"]: s for s in stops}
    by_code = {}
    for s in stops:
        code = (s.get("stop_code") or "").strip()
        if code: by_code[str(code)] = s
    return by_id, by_code

def build_sched_lookup(stop_times):
    def hms_to_sec(s):
        h,m,sec = [int(x) for x in s.split(":")]
        return h*3600 + m*60 + sec
    sched={}
    for st in stop_times:
        tid=st["trip_id"]; sid=st["stop_id"]
        at = st.get("arrival_time") or st.get("departure_time") or ""
        if at:
            try: sched[(tid,sid)] = hms_to_sec(at)
            except: pass
    return sched

def local_midnight_epoch(y,mo,d):
    return int(time.mktime((y,mo,d,0,0,0,-1,-1,-1)))

# ---------- protobuf fetch & parse ----------
def fetch_tripupdates_pb(debug=False):
    raw = http_get(TRIP_UPDATES_PB, debug=debug)
    feed = gtfs_realtime_pb2.FeedMessage(); feed.ParseFromString(raw)
    header_ts = int(feed.header.timestamp) if feed.header.HasField("timestamp") else None
    return feed, header_ts

def fetch_vehiclepositions_pb(debug=False):
    raw = http_get(VEH_POSITIONS_PB, debug=debug)
    feed = gtfs_realtime_pb2.FeedMessage(); feed.ParseFromString(raw)
    return feed

def parse_tripupdates_for_route_pb(route_ids, sched_lookup, static_stop_id, static_stop_code, debug=False):
    """
    Returns:
      etas: list of dicts:
        {
          'eta_min': int,            # realtime minutes (rounded down)
          'when': 'HH:MM TZ',        # realtime absolute
          'trip_id': str,
          'sched_hhmm': 'HH:MM',     # scheduled arrival if available
          'delay_min': int|None      # positive=late, negative=early
        }
      seen_rt_stop_ids: set of RT stop_ids seen for this route
    """
    try:
        feed, header_ts = fetch_tripupdates_pb(debug=debug)
    except Exception as e:
        if debug: print(f"[debug] TripUpdates.pb fetch error: {e}", file=sys.stderr)
        return [], set()

    accepted_stop_keys = {str(static_stop_id)}
    if static_stop_code: accepted_stop_keys.add(str(static_stop_code))
    now_ts = header_ts or now_epoch()
    etas=[]; seen_rt_stop_ids=set()

    for ent in feed.entity:
        if not ent.HasField("trip_update"): continue
        tu = ent.trip_update
        rid = tu.trip.route_id
        if rid not in route_ids: continue
        tid = tu.trip.trip_id
        start_date = tu.trip.start_date  # 'YYYYMMDD' or ''

        for stu in tu.stop_time_update:
            sid_rt = stu.stop_id
            if sid_rt: seen_rt_stop_ids.add(str(sid_rt))
            if not sid_rt or str(sid_rt) not in accepted_stop_keys:
                continue

            # Prefer absolute time, fallback to delay-based reconstruction
            ts = None
            if stu.arrival.HasField("time"):   ts = int(stu.arrival.time)
            elif stu.departure.HasField("time"): ts = int(stu.departure.time)
            delay = None
            if ts is None:
                if stu.arrival.HasField("delay"):   delay = int(stu.arrival.delay)
                elif stu.departure.HasField("delay"): delay = int(stu.departure.delay)
                if delay is not None and tid and start_date:
                    sched_sec = sched_lookup.get((tid, str(static_stop_id))) or sched_lookup.get((tid, str(sid_rt)))
                    if sched_sec is not None:
                        y,mo,d = int(start_date[:4]), int(start_date[4:6]), int(start_date[6:8])
                        ts = local_midnight_epoch(y,mo,d) + int(sched_sec) + delay

            if ts is not None:
                eta_min = max(0,(ts-now_ts)//60)
                # scheduled time (if we have it)
                sched_sec = sched_lookup.get((tid, str(static_stop_id))) or sched_lookup.get((tid, str(sid_rt)))
                sched_hhmm = None
                if sched_sec is not None and start_date:
                    y,mo,d = int(start_date[:4]), int(start_date[4:6]), int(start_date[6:8])
                    sched_ts = local_midnight_epoch(y,mo,d) + int(sched_sec)
                    sched_hhmm = hhmm_local(sched_ts)
                    if delay is None:
                        # derive delay if both real and sched available
                        delay = int((ts - sched_ts) // 60)
                etas.append({
                    "eta_min": int(eta_min),
                    "when": hhmm_local(ts),
                    "trip_id": tid or "?",
                    "sched_hhmm": sched_hhmm,
                    "delay_min": delay if delay is not None else None
                })

    etas.sort(key=lambda x:x["eta_min"])
    return etas, seen_rt_stop_ids

def pick_nearest_rt_stop_for_route(rt_stop_ids, stops_by_id, stops_by_code, user_lat, user_lon):
    best=None; best_d=float("inf")
    for sid in rt_stop_ids:
        s = stops_by_code.get(str(sid)) or stops_by_id.get(str(sid))
        if not s: continue
        try:
            lat=float(s["stop_lat"]); lon=float(s["stop_lon"])
        except: 
            continue
        d = haversine_km(user_lat,user_lon,lat,lon)
        if d<best_d: best, best_d = s, d
    return best, best_d if best else (None, None)

# ---------- de-duplication ----------
def dedupe_etas(etas):
    """
    De-duplicate ETA entries:
      1) collapse by trip_id (prefer entry with realtime/delay, then earlier 'when')
      2) collapse by realtime minute ('when' string like 'HH:MM')
    Returns a new, sorted list.
    """
    if not etas:
        return etas[:]

    # 1) collapse by trip_id
    by_trip = {}
    for e in etas:
        key = e.get("trip_id") or f"noid:{e.get('when','')}"
        cur = by_trip.get(key)
        if cur is None:
            by_trip[key] = e
            continue
        cur_has_rt = cur.get("delay_min") is not None
        new_has_rt = e.get("delay_min") is not None
        if new_has_rt and not cur_has_rt:
            by_trip[key] = e
        elif new_has_rt == cur_has_rt:
            # earlier realtime time wins
            if e.get("when","") < cur.get("when",""):
                by_trip[key] = e

    # 2) collapse by realtime minute (HH:MM)
    seen_minute = set()
    unique = []
    for e in sorted(by_trip.values(), key=lambda x: (x.get("when",""), x.get("eta_min", 9999))):
        minute = e.get("when","")
        if minute in seen_minute:
            continue
        seen_minute.add(minute)
        unique.append(e)

    return unique

# ---------- Waybar JSON helpers ----------
def class_for_eta(eta_min):
    if eta_min is None: return "none"
    if eta_min <= 8: return "soon"
    if eta_min <= 20: return "coming"
    return "far"

def build_waybar_json(route, stop, etas, offset_min=0):
    """
    Pick soonest ETA; build text + tooltip for Waybar
    """
    # Apply offset to display only (if user wants a nudge)
    adj = lambda m: max(0, (m or 0) + offset_min)

    # --- NEW: de-dupe before building output ---
    etas = dedupe_etas(etas)

    if etas:
        soonest = etas[0]
        eta_text = f"{route}: {adj(soonest['eta_min'])}m"
        cls = class_for_eta(adj(soonest['eta_min']))
    else:
        eta_text = f"{route}: --"
        cls = "none"

    # Tooltip: stop name + next 3 entries with sched & realtime
    tip_lines = []
    if stop:
        name = stop["stop_name"]
        # remove trailing " - #digits" (like " - #141")
        name = re.sub(r"\s*-\s*#\d+$", "", name)
        tip_lines.append(name)
    show = etas[:3]
    if not show:
        tip_lines.append("No realtime arrivals found.")
    else:
        for e in show:
            part_sched = e["sched_hhmm"] or "—"
            rt = e["when"]
            if e["sched_hhmm"] and e["sched_hhmm"] != rt:
                # show both when they differ: HH:MM (sched) → HH:MM (rt, +Xd)
                dm = f"{e['delay_min']:+d}m" if e["delay_min"] is not None else ""
                tip_lines.append(f"{part_sched} → {rt}  ({dm})")
            else:
                # only realtime shown
                tip_lines.append(rt)

    tooltip = "\n".join(tip_lines)
    return {"text": eta_text, "tooltip": tooltip, "class": cls}

# ---------- main ----------
def main():
    ap = argparse.ArgumentParser(description="Waybar JSON for LTC ETA")
    ap.add_argument("--route", required=True, help="Route short name (e.g., 34)")
    ap.add_argument("--lat", type=float, default=DEFAULT_LAT)
    ap.add_argument("--lon", type=float, default=DEFAULT_LON)
    ap.add_argument("--gtfs-cache", default="gtfs_cache.zip")
    ap.add_argument("--offset-min", type=int, default=0, help="Display offset in minutes (e.g., 3 to show later)")
    ap.add_argument("--debug", action="store_true")
    ap.add_argument("--waybar", action="store_true", help="Output Waybar JSON then exit")
    args = ap.parse_args()

    cache = ensure_gtfs_local(args.gtfs_cache, debug=args.debug)
    routes, trips, stops, stop_times = load_static_gtfs(cache)
    sched_lookup = build_sched_lookup(stop_times)
    stops_by_id, stops_by_code = build_stop_maps(stops)

    route_ids = find_route_ids_by_short_name(routes, args.route)
    if not route_ids:
        # waybar wants valid JSON; show error class
        out = {"text": f"{args.route}: err", "tooltip": "Route not found", "class": "none"}
        print(json.dumps(out, ensure_ascii=False))
        return 2

    route_stop_ids, _ = stops_for_route(route_ids, trips, stop_times)
    cand = nearest_stops_on_route(args.lat, args.lon, route_stop_ids, stops, k=8)
    stop = None; etas_all = []; seen_rt = set()

    # try nearest candidates first
    for d, s in cand:
        scode = (s.get("stop_code") or "").strip()
        etas, rt_ids = parse_tripupdates_for_route_pb(route_ids, sched_lookup, s["stop_id"], scode, debug=args.debug)
        seen_rt |= rt_ids
        if etas:
            stop = s
            etas_all = etas
            break

    # fallback: choose nearest RT-active stop on route
    if not etas_all and seen_rt:
        s2, _ = pick_nearest_rt_stop_for_route(seen_rt, stops_by_id, stops_by_code, args.lat, args.lon)
        if s2:
            scode = (s2.get("stop_code") or "").strip()
            etas2, _ = parse_tripupdates_for_route_pb(route_ids, sched_lookup, s2["stop_id"], scode, debug=args.debug)
            if etas2:
                stop = s2; etas_all = etas2

    # --- NEW: de-dupe just before output (covers both branches) ---
    etas_all = dedupe_etas(etas_all)

    # Waybar output
    if args.waybar:
        out = build_waybar_json(
            args.route,
            stop or (cand[0][1] if cand else {"stop_name":"Unknown"}),
            etas_all,
            offset_min=args.offset_min
        )
        print(json.dumps(out, ensure_ascii=False))
        return 0

    # legacy stdout (for manual runs)
    name = stop['stop_name'] if stop else (cand[0][1]['stop_name'] if cand else "Unknown")
    print(f"Route {args.route}  @ {name}")
    if etas_all:
        print("Next buses:")
        for e in etas_all[:3]:
            if e["sched_hhmm"] and e["sched_hhmm"] != e["when"]:
                dm = f"{e['delay_min']:+d}m" if e["delay_min"] is not None else ""
                print(f"  {e['sched_hhmm']} → {e['when']}  ({dm})  ~{e['eta_min']}m")
            else:
                print(f"  {e['when']}  ~{e['eta_min']}m")
    else:
        print("  No realtime arrivals.")
    return 0

if __name__ == "__main__":
    sys.exit(main())
