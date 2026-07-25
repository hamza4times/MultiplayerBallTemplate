extends Node

signal player_connected(peer_id, player_info)
signal player_disconnected(peer_id)
signal server_disconnected

const PORT = 7000
const DEFAULT_SERVER_IP = "127.0.0.1"
const MAX_CONNECTIONS = 12
const SAVE_PATH := "user://player_data.cfg"

const COLORS := {
	"Red": Color(0.9, 0.15, 0.15),
	"Orange": Color(1.0, 0.6, 0.0),
	"Yellow": Color(1.0, 0.9, 0.1),
	"Green": Color(0.2, 0.8, 0.2),
	"Blue": Color(0.2, 0.5, 1.0),
	"Purple": Color(0.6, 0.2, 0.8),
	"Pink": Color(1.0, 0.4, 0.7),
}

var players = {}
var player_info = {"name": "Player", "color": COLORS["Blue"]}
var players_loaded := 0

func _ready():
	load_player_data()
	_setup_inputs()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_ok)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func save_player_color(color: Color):
	player_info["color"] = color
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var({"color": color})
		file.close()

func load_player_data():
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var data = file.get_var()
		file.close()
		if data is Dictionary and data.has("color"):
			player_info["color"] = data["color"]

func _setup_inputs():
	if InputMap.has_action("move_left"):
		return
	var actions = {
		"move_left": KEY_A,
		"move_right": KEY_D,
		"move_forward": KEY_W,
		"move_back": KEY_S,
		"jump": KEY_SPACE,
	}
	for action_name in actions:
		InputMap.add_action(action_name)
		var event = InputEventKey.new()
		event.keycode = actions[action_name]
		InputMap.action_add_event(action_name, event)

func join_game(address = ""):
	if address.is_empty():
		address = DEFAULT_SERVER_IP
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, PORT)
	if error:
		return error
	multiplayer.multiplayer_peer = peer
	return OK

func create_game():
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, MAX_CONNECTIONS)
	if error:
		return error
	multiplayer.multiplayer_peer = peer
	players[1] = player_info
	player_connected.emit(1, player_info)
	return OK

func remove_multiplayer_peer():
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()
	players_loaded = 0

@rpc("call_local", "reliable")
func load_game(game_scene_path):
	players_loaded = 0
	get_tree().change_scene_to_file(game_scene_path)

@rpc("any_peer", "call_local", "reliable")
func player_loaded():
	if multiplayer.is_server():
		players_loaded += 1

func _on_peer_connected(id):
	pass

func _on_peer_disconnected(id):
	players.erase(id)
	player_disconnected.emit(id)

func _on_connected_ok():
	var id = multiplayer.get_unique_id()
	if players.has(id):
		return
	players[id] = player_info
	player_connected.emit(id, player_info)
	register_me.rpc_id(1, player_info)

func _on_connection_failed():
	remove_multiplayer_peer()

func _on_server_disconnected():
	remove_multiplayer_peer()
	server_disconnected.emit()

@rpc("any_peer", "reliable")
func register_me(info: Dictionary):
	var id = multiplayer.get_remote_sender_id()
	players[id] = info
	player_connected.emit(id, info)
	for pid in players:
		if pid != id:
			_add_player.rpc_id(pid, id, info)
	for pid in players:
		if pid != id:
			_add_player.rpc_id(id, pid, players[pid])

@rpc("authority", "reliable")
func _add_player(id: int, info: Dictionary):
	if not players.has(id):
		players[id] = info
		player_connected.emit(id, info)
