class_name Catalog
extends RefCounted

## Fictional garage catalog. Names match the web app. Nothing here is a real brand.

const PAINTS: Array[Dictionary] = [
	{"id": "copper", "name": "Kiln Copper", "hex": "#c4622d"},
	{"id": "ivory", "name": "Bone Ivory", "hex": "#e6e0d4"},
	{"id": "ink", "name": "Night Ink", "hex": "#1b1e26"},
	{"id": "sage", "name": "Sage Alloy", "hex": "#7e8d72"},
	{"id": "sea", "name": "Harbor Teal", "hex": "#1d6e76"},
	{"id": "sand", "name": "Dune Sand", "hex": "#c4a56d"},
	{"id": "crimson", "name": "Brake Crimson", "hex": "#8d2e2e"},
	{"id": "ice", "name": "Glacier", "hex": "#c5d0dc"},
	{"id": "violet", "name": "Signal Violet", "hex": "#3d2b58"},
	{"id": "lime", "name": "Pit Lime", "hex": "#c6d24a"},
	{"id": "porcelain", "name": "Porcelain", "hex": "#f4f4f1"},
	{"id": "switch", "name": "Switchback", "hex": "#e36b2c"},
]

const FINISHES: Array[Dictionary] = [
	{"id": "gloss", "name": "Gloss", "metal": 0.12, "rough": 0.18, "coat": 1.0, "coat_rough": 0.06, "iridescence": 0.0},
	{"id": "metallic", "name": "Metallic", "metal": 0.86, "rough": 0.28, "coat": 0.7, "coat_rough": 0.12, "iridescence": 0.0},
	{"id": "matte", "name": "Matte", "metal": 0.04, "rough": 0.82, "coat": 0.02, "coat_rough": 0.55, "iridescence": 0.0},
	{"id": "satin", "name": "Satin", "metal": 0.42, "rough": 0.45, "coat": 0.32, "coat_rough": 0.24, "iridescence": 0.0},
	{"id": "pearl", "name": "Pearl", "metal": 0.24, "rough": 0.16, "coat": 1.0, "coat_rough": 0.04, "iridescence": 1.0},
]

const TRUCKS: Array[Dictionary] = [
	{"id": "ridgehaul-summit", "brand": "Ridgehaul", "model": "Summit", "role": "Half-ton", "blurb": "The half-ton you take when the day is ordinary and the road is not.", "paint": "copper", "plate": "SMIT 150", "wheelbase": 3.4, "track": 1.56, "front_over": 0.78, "rear_over": 0.78, "width": 1.86, "clearance": 0.26, "belt": 0.96, "roof": 1.58, "cab_front": 1.18},
	{"id": "veldt-meridian", "brand": "Veldt", "model": "Meridian", "role": "Desert hauler", "blurb": "A long bed and tall arches for sand that never agreed to be a road.", "paint": "sand", "plate": "VLDT 4", "wheelbase": 3.55, "track": 1.7, "front_over": 0.86, "rear_over": 1.15, "width": 1.98, "clearance": 0.32, "belt": 1.04, "roof": 1.7, "cab_front": 1.05},
	{"id": "northline-harbor", "brand": "Northline", "model": "Harbor", "role": "City utility", "blurb": "Upright cab, square corners, happier with a ladder than a trophy.", "paint": "ice", "plate": "HBR 220", "wheelbase": 3.2, "track": 1.52, "front_over": 0.7, "rear_over": 0.9, "width": 1.82, "clearance": 0.28, "belt": 1.0, "roof": 1.82, "cab_front": 0.92},
	{"id": "kestrel-talon", "brand": "Kestrel", "model": "Talon", "role": "Sport truck", "blurb": "Low roof, long hood, and no interest in staying behind anything.", "paint": "violet", "plate": "TLN X", "wheelbase": 3.15, "track": 1.66, "front_over": 0.95, "rear_over": 0.58, "width": 1.94, "clearance": 0.22, "belt": 0.9, "roof": 1.36, "cab_front": 0.95},
]

const PARTS: Array[Dictionary] = [
	{"id": "wh-steel", "slot": "wheel", "name": "Steel Dish", "rarity": "common", "blurb": "Plain stamped steel. Honest, heavy, easy to hose off.", "coins": 0, "cores": 0, "look": {"color": "#8d939c", "metal": 0.7, "rough": 0.38}},
	{"id": "wh-five", "slot": "wheel", "name": "Five-Spoke", "rarity": "common", "blurb": "Five thick spokes. The look the Summit leaves the bay with.", "coins": 0, "cores": 0, "look": {"color": "#d5dde6", "metal": 0.95, "rough": 0.18}},
	{"id": "wh-deep", "slot": "wheel", "name": "Deep Lip", "rarity": "rare", "blurb": "A polished outer lip that catches the bay lights.", "coins": 980, "cores": 14, "look": {"color": "#e7edf4", "metal": 1.0, "rough": 0.08}},
	{"id": "wh-bead", "slot": "wheel", "name": "Beadlock", "rarity": "rare", "blurb": "A bolted ring for airing down without the tire walking off.", "coins": 1180, "cores": 16, "look": {"color": "#3a3e46", "metal": 0.75, "rough": 0.32}},
	{"id": "wh-mesh", "slot": "wheel", "name": "Forged Mesh", "rarity": "epic", "blurb": "A dense mesh face, machined rather than cast.", "coins": 2500, "cores": 34, "look": {"color": "#c9d2dc", "metal": 1.0, "rough": 0.12}},
	{"id": "wh-turbine", "slot": "wheel", "name": "Solar Turbine", "rarity": "legendary", "blurb": "Twisted spokes with a warm metal that looks lit from inside.", "coins": 5400, "cores": 70, "look": {"color": "#e3c07a", "metal": 1.0, "rough": 0.14}},
	{"id": "wh-aero", "slot": "wheel", "name": "Aero Lattice", "rarity": "epic", "blurb": "Thin spokes and two hoops. A mesh you can see the caliper through.", "coins": 3050, "cores": 42, "look": {"color": "#d7dee6", "metal": 1.0, "rough": 0.1}},
	{"id": "wh-blade", "slot": "wheel", "name": "Vector Blade", "rarity": "legendary", "blurb": "Nine blades, all swept the same way, wide where they meet the lip.", "coins": 5100, "cores": 68, "look": {"color": "#e8eef5", "metal": 1.0, "rough": 0.1}},
	{"id": "wh-split", "slot": "wheel", "name": "Split Dish", "rarity": "rare", "blurb": "A deep barrel and five spokes that fork before the lip.", "coins": 1420, "cores": 20, "look": {"color": "#f2f5f8", "metal": 1.0, "rough": 0.07}},
	{"id": "wh-mono", "slot": "wheel", "name": "Monoblock", "rarity": "epic", "blurb": "Five broad faces in a shallow cone. The slots are the only gaps.", "coins": 2280, "cores": 32, "look": {"color": "#b7c0ca", "metal": 0.95, "rough": 0.16}},
	{"id": "ti-hwy", "slot": "tire", "name": "Highway Rib", "rarity": "common", "blurb": "Quiet ribs for pavement and the long way home.", "coins": 0, "cores": 0, "look": {"radius": 0.38}},
	{"id": "ti-at", "slot": "tire", "name": "All-Terrain", "rarity": "common", "blurb": "A compromise tread that still knows what gravel is.", "coins": 240, "cores": 4, "look": {"radius": 0.4}},
	{"id": "ti-mud", "slot": "tire", "name": "Mud Claw", "rarity": "rare", "blurb": "Chunky lugs that throw dirt and don't apologize.", "coins": 860, "cores": 12, "look": {"radius": 0.43}},
	{"id": "ti-paddle", "slot": "tire", "name": "Paddle Cut", "rarity": "epic", "blurb": "Wide scoops for loose sand, noisy everywhere else.", "coins": 2300, "cores": 32, "look": {"radius": 0.45}},
	{"id": "lf-0", "slot": "lift", "name": "Stock Height", "rarity": "common", "blurb": "Factory ride. The fenders still know the tires.", "coins": 0, "cores": 0, "look": {"amount": 0.0}},
	{"id": "lf-2", "slot": "lift", "name": "Trail 2\"", "rarity": "common", "blurb": "A modest spacer. Room for a thicker tire, not a parade.", "coins": 360, "cores": 6, "look": {"amount": 0.1}},
	{"id": "lf-4", "slot": "lift", "name": "Ridge 4\"", "rarity": "rare", "blurb": "Daylight under the rocker and a longer shock.", "coins": 1100, "cores": 16, "look": {"amount": 0.2}},
	{"id": "lf-6", "slot": "lift", "name": "Dune 6\"", "rarity": "epic", "blurb": "The body sits up like it heard a rumor about rocks.", "coins": 2200, "cores": 32, "look": {"amount": 0.32}},
	{"id": "bp-factory", "slot": "bumper", "name": "Factory Bar", "rarity": "common", "blurb": "Body-color and tidy. It matches because it never left.", "coins": 0, "cores": 0, "look": {"kind": "factory"}},
	{"id": "bp-tube", "slot": "bumper", "name": "Tube Guard", "rarity": "rare", "blurb": "A black hoop with two uprights. Brush, not boulevard.", "coins": 980, "cores": 14, "look": {"kind": "tube"}},
	{"id": "bp-winch", "slot": "bumper", "name": "Winch Plate", "rarity": "epic", "blurb": "A flat plate and a drum, for the day the wash wins.", "coins": 2400, "cores": 34, "look": {"kind": "winch"}},
	{"id": "bp-pre", "slot": "bumper", "name": "Prerunner Hoop", "rarity": "legendary", "blurb": "Tubes pushed forward, with a skid plate underneath.", "coins": 4900, "cores": 68, "look": {"kind": "prerunner"}},
	{"id": "lt-pods", "slot": "light", "name": "Fog Pods", "rarity": "common", "blurb": "Two warm pods on the valence. Enough for a trailhead.", "coins": 0, "cores": 0, "look": {"kind": "pods"}},
	{"id": "lt-bar", "slot": "light", "name": "Roof Bar", "rarity": "rare", "blurb": "A single cool bar above the windshield.", "coins": 900, "cores": 14, "look": {"kind": "bar"}},
	{"id": "lt-dual", "slot": "light", "name": "Horizon Dual", "rarity": "epic", "blurb": "Roof bar plus the pods. The desert gets no shadows.", "coins": 2100, "cores": 30, "look": {"kind": "dual"}},
	{"id": "ex-stock", "slot": "exhaust", "name": "Tucked Pipe", "rarity": "common", "blurb": "One pipe, hidden until you crouch.", "coins": 0, "cores": 0, "look": {"kind": "stock"}},
	{"id": "ex-side", "slot": "exhaust", "name": "Side Exit", "rarity": "rare", "blurb": "A thick tip ahead of the rear tire.", "coins": 780, "cores": 12, "look": {"kind": "side"}},
	{"id": "ex-stack", "slot": "exhaust", "name": "Twin Stack", "rarity": "legendary", "blurb": "Two chrome stacks rising behind the cab.", "coins": 4600, "cores": 64, "look": {"kind": "stack"}},
	{"id": "sp-none", "slot": "spoiler", "name": "Clean Tail", "rarity": "common", "blurb": "No wing. The tailgate is allowed to be a tailgate.", "coins": 0, "cores": 0, "look": {"kind": "none"}},
	{"id": "sp-lip", "slot": "spoiler", "name": "Deck Lip", "rarity": "rare", "blurb": "A low lip on the tailgate. Mostly a drawing.", "coins": 720, "cores": 10, "look": {"kind": "lip"}},
	{"id": "sp-wing", "slot": "spoiler", "name": "Span Wing", "rarity": "epic", "blurb": "Pedestals and a wide plane. It means the sport truck.", "coins": 2000, "cores": 28, "look": {"kind": "wing"}},
	{"id": "wr-clean", "slot": "wrap", "name": "Bare", "rarity": "common", "blurb": "Paint only. Panel gaps do the talking.", "coins": 0, "cores": 0, "look": {"kind": "clean", "accent": "#ffffff"}},
	{"id": "wr-stripe", "slot": "wrap", "name": "Centerline", "rarity": "common", "blurb": "A beltline stripe and a hood spear in copper.", "coins": 280, "cores": 4, "look": {"kind": "stripe", "accent": "#ff8a3d"}},
	{"id": "wr-geo", "slot": "wrap", "name": "Breakline", "rarity": "rare", "blurb": "Broken chevrons along the doors.", "coins": 1240, "cores": 16, "look": {"kind": "geo", "accent": "#f2c56e"}},
	{"id": "wr-sunset", "slot": "wrap", "name": "Dusk Fade", "rarity": "epic", "blurb": "A warm fade that pools toward the rear quarter.", "coins": 2700, "cores": 36, "look": {"kind": "sunset", "accent": "#ff7a3c"}},
	{"id": "wr-circuit", "slot": "wrap", "name": "Myth Circuit", "rarity": "legendary", "blurb": "Thin luminous lines, like a map of a road that isn't real.", "coins": 5600, "cores": 74, "look": {"kind": "circuit", "accent": "#3dffe0"}},
]

const CATEGORIES: Array[Dictionary] = [
	{"id": "paint", "label": "Paint"},
	{"id": "wheel", "label": "Wheels"},
	{"id": "tire", "label": "Tires"},
	{"id": "lift", "label": "Lift"},
	{"id": "bumper", "label": "Bumpers"},
	{"id": "light", "label": "Lights"},
	{"id": "exhaust", "label": "Exhaust"},
	{"id": "spoiler", "label": "Spoilers"},
	{"id": "wrap", "label": "Wraps"},
]

const PRODUCTS: Array[Dictionary] = [
	{"id": "coins_pouch", "title": "Coin pouch", "detail": "1,500 coins. The same coins a trail pays, in a hurry.", "price": "$0.99", "kind": "consumable", "cores": 0, "coins": 1500, "parts": []},
	{"id": "coins_crate", "title": "Coin crate", "detail": "4,500 coins. A shortcut to a rare part, not a different catalog.", "price": "$1.99", "kind": "consumable", "cores": 0, "coins": 4500, "parts": []},
	{"id": "coins_vault", "title": "Coin vault", "detail": "12,000 coins. Still the parts the bay already sells.", "price": "$4.99", "kind": "consumable", "cores": 0, "coins": 12000, "parts": []},
	{"id": "cores_small", "title": "Core pouch", "detail": "80 Cores. Spend them on any part in the garage.", "price": "$0.99", "kind": "consumable", "cores": 80, "coins": 0, "parts": []},
	{"id": "cores_medium", "title": "Core crate", "detail": "200 Cores. A shortcut, not a different catalog.", "price": "$1.99", "kind": "consumable", "cores": 200, "coins": 0, "parts": []},
	{"id": "cores_large", "title": "Core vault", "detail": "550 Cores. Still the same parts the trail pays for.", "price": "$4.99", "kind": "consumable", "cores": 550, "coins": 0, "parts": []},
	{"id": "bundle_trail", "title": "Trail kit", "detail": "Deep Lip wheels, Mud Claw tires, and the Ridge 4\" lift.", "price": "$2.99", "kind": "nonconsumable", "cores": 0, "coins": 0, "parts": ["wh-deep", "ti-mud", "lf-4"]},
	{"id": "bundle_night", "title": "Night shift kit", "detail": "Horizon Dual lights, Side Exit exhaust, and the Breakline wrap.", "price": "$3.99", "kind": "nonconsumable", "cores": 0, "coins": 0, "parts": ["lt-dual", "ex-side", "wr-geo"]},
	{"id": "bundle_show", "title": "Showfield kit", "detail": "Solar Turbine wheels, Twin Stacks, the Prerunner Hoop, and Myth Circuit.", "price": "$6.99", "kind": "nonconsumable", "cores": 0, "coins": 0, "parts": ["wh-turbine", "ex-stack", "bp-pre", "wr-circuit"]},
]

const QUESTS: Array[Dictionary] = [
	{"id": "shake", "title": "Shake-down", "detail": "Take any trail far enough to count, or finish it.", "metric": "runs", "goal": 1, "coins": 400, "part": "", "duplicate_coins": 0},
	{"id": "regular", "title": "Three trips", "detail": "Log three runs that make it past the trailhead.", "metric": "runs", "goal": 3, "coins": 500, "part": "", "duplicate_coins": 0},
	{"id": "unmarked", "title": "Unmarked", "detail": "Finish a trail without taking a hit.", "metric": "clean", "goal": 1, "coins": 0, "part": "ex-side", "duplicate_coins": 900},
	{"id": "pocket", "title": "Full pockets", "detail": "Bank 500 coins in a single run.", "metric": "best_coins", "goal": 500, "coins": 350, "part": "", "duplicate_coins": 0},
	{"id": "haul", "title": "Long haul", "detail": "Cover 800 meters in one run.", "metric": "best_distance", "goal": 800, "coins": 0, "part": "lt-bar", "duplicate_coins": 800},
	{"id": "mod", "title": "First mod", "detail": "Buy any part with coins or Cores.", "metric": "parts", "goal": 1, "coins": 250, "part": "", "duplicate_coins": 0},
	{"id": "bay", "title": "Regular at the bay", "detail": "Claim the daily bay two different days.", "metric": "dailies", "goal": 2, "coins": 600, "part": "", "duplicate_coins": 0},
	{"id": "gulch", "title": "Gulch scout", "detail": "Finish Gulch.", "metric": "gulch", "goal": 1, "coins": 0, "part": "ti-mud", "duplicate_coins": 800},
]

const DAILY: Array[Dictionary] = [
	{"label": "Morning shift", "coins": 200, "part": "", "duplicate_coins": 0},
	{"label": "Second cup", "coins": 300, "part": "", "duplicate_coins": 0},
	{"label": "Overtime", "coins": 450, "part": "", "duplicate_coins": 0},
	{"label": "Deep Lip, or coins if you have it", "coins": 0, "part": "wh-deep", "duplicate_coins": 800},
	{"label": "Friday bay", "coins": 500, "part": "", "duplicate_coins": 0},
	{"label": "Long shift", "coins": 700, "part": "", "duplicate_coins": 0},
	{"label": "Tube Guard, or coins if you have it", "coins": 0, "part": "bp-tube", "duplicate_coins": 1000},
]

const RARITY_COLOR := {
	"common": "#b7c0cc",
	"rare": "#7eb6ff",
	"epic": "#c99bff",
	"legendary": "#f2c56e",
}

const SLEEK_RIMS: Array[String] = ["wh-aero", "wh-blade", "wh-split", "wh-mono"]

static var _tracks: Array[Dictionary] = []


static func tracks() -> Array[Dictionary]:
	if _tracks.is_empty():
		_tracks = [
			{"id": "switchback", "name": "Switchback", "blurb": "A dry riverbed with one safe lane at a time.", "length": 1120, "speed": 30.0, "unlock": 0, "entities": _entities("sw", [
				["coins", 1, 70, 4, 18], ["coins", 0, 150, 2, 18], ["rock", 1, 200], ["coins", 2, 240, 3, 18],
				["rock", 0, 310], ["coins", 2, 350, 2, 18], ["barrier", 2, 410], ["coins", 1, 450, 2, 18],
				["mud", 1, 510], ["coins", 0, 490, 3, 18], ["rock", 0, 580], ["coins", 2, 620, 3, 18],
				["boost", 2, 680], ["coins", 0, 730, 3, 18], ["barrier", 1, 800], ["coins", 1, 840, 3, 18],
				["rock", 2, 910], ["coins", 0, 950, 3, 18], ["barrier", 0, 1020], ["coins", 2, 1048, 3, 16],
			])},
			{"id": "gulch", "name": "Gulch", "blurb": "Two lanes close at once. The open one is the whole plan.", "length": 1080, "speed": 32.0, "unlock": 1, "entities": _entities("gu", [
				["coins", 1, 60, 4, 16], ["coins", 2, 150, 2, 16], ["rock", 0, 190], ["barrier", 1, 190],
				["coins", 0, 230, 2, 16], ["rock", 1, 270], ["rock", 2, 270], ["coins", 1, 310, 2, 16],
				["barrier", 0, 350], ["barrier", 2, 350], ["coins", 2, 390, 2, 16], ["rock", 0, 430],
				["rock", 1, 430], ["boost", 2, 470], ["coins", 0, 500, 2, 16], ["barrier", 1, 540],
				["barrier", 2, 540], ["coins", 1, 580, 2, 16], ["rock", 0, 620], ["rock", 2, 620],
				["coins", 0, 660, 2, 16], ["barrier", 1, 700], ["rock", 2, 700], ["coins", 2, 740, 2, 16],
				["rock", 0, 780], ["barrier", 1, 780], ["boost", 2, 820], ["coins", 1, 850, 2, 16],
				["rock", 0, 890], ["rock", 2, 890], ["coins", 0, 930, 3, 16], ["barrier", 1, 990],
				["barrier", 2, 990],
			])},
		]
	return _tracks


static func _entities(prefix: String, rows: Array) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	var n := 0
	for row in rows:
		if str(row[0]) == "coins":
			var lane := int(row[1])
			var start := float(row[2])
			var count := int(row[3])
			var gap := float(row[4])
			for i in count:
				n += 1
				list.append({"id": "%s-coin-%d" % [prefix, n], "kind": "coin", "lane": lane, "z": start + float(i) * gap})
		else:
			n += 1
			list.append({"id": "%s-%s-%d" % [prefix, str(row[0]), n], "kind": str(row[0]), "lane": int(row[1]), "z": float(row[2])})
	return list


static func truck(id: String) -> Dictionary:
	for item in TRUCKS:
		if item["id"] == id:
			return item
	return {}


static func part(id: String) -> Dictionary:
	for item in PARTS:
		if item["id"] == id:
			return item
	return {}


static func paint(id: String) -> Dictionary:
	for item in PAINTS:
		if item["id"] == id:
			return item
	return {}


static func finish(id: String) -> Dictionary:
	for item in FINISHES:
		if item["id"] == id:
			return item
	return {}


static func product(id: String) -> Dictionary:
	for item in PRODUCTS:
		if item["id"] == id:
			return item
	return {}


static func track(id: String) -> Dictionary:
	for item in tracks():
		if item["id"] == id:
			return item
	return {}


static func parts_for(slot: String) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for item in PARTS:
		if item["slot"] == slot:
			list.append(item)
	return list


static func is_free(item: Dictionary) -> bool:
	return int(item.get("coins", 0)) <= 0 and int(item.get("cores", 0)) <= 0


static func rarity_label(rarity: String) -> String:
	if rarity == "legendary":
		return "Legendary"
	if rarity.is_empty():
		return ""
	return rarity.substr(0, 1).to_upper() + rarity.substr(1)


static func starter_loadout(spec: Dictionary) -> Dictionary:
	return {
		"paint": str(spec.get("paint", "copper")),
		"finish": "gloss",
		"wheel": "wh-five",
		"tire": "ti-hwy",
		"lift": "lf-0",
		"bumper": "bp-factory",
		"light": "lt-pods",
		"exhaust": "ex-stock",
		"spoiler": "sp-none",
		"wrap": "wr-clean",
	}


static func mesh_part(id: String) -> bool:
	var item := part(id)
	if item.is_empty():
		return false
	var slot := str(item["slot"])
	if slot == "wrap" or slot == "lift":
		return false
	if id == "sp-none":
		return false
	return true


static func previous_day(key: String) -> String:
	var bits := key.split("-")
	if bits.size() != 3:
		return key
	var dict := {"year": int(bits[0]), "month": int(bits[1]), "day": int(bits[2]), "hour": 12, "minute": 0, "second": 0}
	var unix := Time.get_unix_time_from_datetime_dict(dict) - 86400
	var back := Time.get_datetime_dict_from_unix_time(unix)
	return "%04d-%02d-%02d" % [int(back["year"]), int(back["month"]), int(back["day"])]


static func commas(value: int) -> String:
	var negative := value < 0
	var digits := str(abs(value))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3, 3) + out
		digits = digits.substr(0, digits.length() - 3)
	out = digits + out
	return ("-" if negative else "") + out
