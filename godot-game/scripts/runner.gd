class_name TrailRun
extends RefCounted

## Same lane runner as the web app. Three lanes, coins, rocks, barriers, mud, boost.
## Three hits ends the run. dt is clamped so a hitch cannot skip a hazard.

var z := 0.0
var lane := 1
var lane_pos := 1.0
var hits := 0
var coins := 0
var boost := 0.0
var mud := 0.0
var invuln := 0.0
var elapsed := 0.0
var status := "running"
var resolved := {}


func step(track: Dictionary, move: int, dt: float) -> Array:
	if status != "running":
		return []
	var tick := clampf(dt, 0.0, 0.05)
	if move < 0:
		lane = maxi(0, lane - 1)
	elif move > 0:
		lane = mini(2, lane + 1)
	lane_pos = lane_pos + (float(lane) - lane_pos) * minf(1.0, tick * 12.0)
	var speed := float(track["speed"])
	if boost > 0.0:
		speed *= 1.45
	if mud > 0.0:
		speed *= 0.6
	var next_z := z + speed * tick
	var events: Array = []
	boost = maxf(0.0, boost - tick)
	mud = maxf(0.0, mud - tick)
	invuln = maxf(0.0, invuln - tick)
	for entity in track["entities"]:
		var id := str(entity["id"])
		if resolved.has(id):
			continue
		var ez := float(entity["z"])
		if ez <= z or ez > next_z:
			continue
		resolved[id] = true
		if int(entity["lane"]) != lane:
			continue
		var kind := str(entity["kind"])
		if kind == "coin":
			coins += 1
			events.append("coin")
		elif kind == "mud":
			mud = 1.15
			events.append("mud")
		elif kind == "boost":
			boost = 1.45
			events.append("boost")
		elif invuln <= 0.0:
			hits += 1
			invuln = 0.85
			events.append("hit")
	if hits >= 3:
		status = "crashed"
		events.append("crash")
	elif next_z >= float(track["length"]):
		z = float(track["length"])
		status = "finished"
		events.append("finish")
		elapsed += tick
		return events
	z = next_z
	elapsed += tick
	return events


func bail() -> void:
	if status == "running":
		status = "bailed"


func settle(track: Dictionary) -> Dictionary:
	var distance := int(floor(z))
	var finished := status == "finished"
	var clean := finished and hits == 0
	var payout := coins * 10 + int(floor(float(distance) * 0.28))
	if finished:
		payout += 120
	if clean:
		payout += 280
	var end_status := status if status != "running" else "bailed"
	return {
		"track_id": str(track["id"]),
		"distance": distance,
		"hits": hits,
		"coins": payout,
		"finished": finished,
		"clean": clean,
		"status": end_status,
	}
