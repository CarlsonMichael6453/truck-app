extends Node

## Two-truck meetup sketch using Godot's high-level multiplayer (ENet).
## Press H to host and J to join 127.0.0.1:7777. The host pushes the driven
## truck. This is the whole relay: no account, no CCU fee. A web build would
## swap ENetMultiplayerPeer for WebSocketMultiplayerPeer.

const PORT := 7777

var _status := ""


func _ready() -> void:
	set_process(true)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_H:
		_host()
	elif event.keycode == KEY_J:
		_join("127.0.0.1")


func _host() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, 4)
	if err != OK:
		_status = "Host failed (%s)" % error_string(err)
		return
	multiplayer.multiplayer_peer = peer
	_status = "Hosting :%d" % PORT


func _join(ip: String) -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, PORT)
	if err != OK:
		_status = "Join failed (%s)" % error_string(err)
		return
	multiplayer.multiplayer_peer = peer
	_status = "Joining %s:%d" % [ip, PORT]


func status_line() -> String:
	return _status


func _process(_delta: float) -> void:
	if not _online():
		return
	var player := get_parent().get_node_or_null("Trucks/Player")
	if player == null or not multiplayer.is_server():
		return
	sync_truck.rpc(player.global_position, player.rotation.y)


func _online() -> bool:
	var peer := multiplayer.multiplayer_peer
	return peer is ENetMultiplayerPeer and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


@rpc("authority", "call_remote", "unreliable")
func sync_truck(pos: Vector3, yaw: float) -> void:
	var remote := get_parent().get_node_or_null("Trucks/Remote")
	if remote == null:
		return
	remote.global_position = pos
	remote.rotation.y = yaw
