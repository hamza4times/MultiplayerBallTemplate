extends Node3D

var game_started := false
var player_scene := preload("res://scenes/Player/Player.tscn")
var game_ui_scene := preload("res://scenes/UI/GameUI.tscn")
var it_peer_id := 0
var game_ui: CanvasLayer
var _contact_state := {}

@onready var spawner: MultiplayerSpawner = $MultiplayerSpawner

func _ready():
	spawner.spawn_function = _spawn_player
	game_ui = game_ui_scene.instantiate()
	add_child(game_ui)

	if multiplayer.is_server():
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		Lobby.players_loaded += 1
	else:
		Lobby.player_loaded.rpc_id(1)

func _process(delta):
	if not multiplayer.is_server() or game_started:
		return
	if Lobby.players_loaded >= Lobby.players.size() and Lobby.players.size() > 0:
		start_game()

func start_game():
	game_started = true
	spawn_all_players()

const SPAWN_RADIUS := 8.0
const SPAWN_HEIGHT := 1.0

func _spawn_player(data):
	var peer_id = data as int
	var player = player_scene.instantiate()
	player.name = str(peer_id)
	player.peer_id = peer_id
	player.set_multiplayer_authority(peer_id)
	var info = Lobby.players.get(peer_id, {})
	player.player_name = info.get("name", "Player " + str(peer_id))
	player.update_name_label(player.player_name)
	var keys = Lobby.players.keys()
	var idx = keys.find(peer_id)
	var total = keys.size()
	var angle = idx * (TAU / total)
	player.position = Vector3(sin(angle) * SPAWN_RADIUS, SPAWN_HEIGHT, cos(angle) * SPAWN_RADIUS)
	return player

func spawn_all_players():
	for id in Lobby.players:
		spawner.spawn(id)
	if Lobby.players.size() >= 2:
		it_peer_id = Lobby.players.keys()[randi() % Lobby.players.size()]
		broadcast_it_change.rpc(it_peer_id)

@rpc("authority", "call_local", "reliable")
func broadcast_it_change(target_peer_id: int):
	it_peer_id = target_peer_id
	for child in get_children():
		var p = child as Player
		if p:
			p.set_it(p.peer_id == target_peer_id)
	if game_ui:
		game_ui.update_it_label(it_peer_id)
		game_ui.update_player_list()

func _physics_process(delta):
	if not multiplayer.is_server() or not game_started:
		return
	check_tag()

func check_tag():
	var it_node = get_node_or_null(str(it_peer_id)) as Player
	if not it_node:
		return
	for child in get_children():
		var p = child as Player
		if not p or p == it_node or p.peer_id == it_peer_id:
			continue
		var touching: bool = it_node.global_position.distance_to(p.global_position) < 1.5
		var key: String = _contact_key(it_peer_id, p.peer_id)
		var was_touching: bool = _contact_state.get(key, false)
		if touching and not was_touching:
			it_peer_id = p.peer_id
			_set_contact(key, true)
			broadcast_it_change.rpc(it_peer_id)
			break
		_set_contact(key, touching)

func _contact_key(a: int, b: int) -> String:
	return str(mini(a, b)) + "_" + str(maxi(a, b))

func _set_contact(key: String, value: bool):
	if value:
		_contact_state[key] = true
	else:
		_contact_state.erase(key)

func _on_peer_connected(id):
	pass

func _on_peer_disconnected(id):
	var player = get_node_or_null(str(id))
	if player:
		player.queue_free()
