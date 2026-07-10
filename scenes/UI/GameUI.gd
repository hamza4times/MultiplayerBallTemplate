extends CanvasLayer

@onready var it_label := $VBoxContainer/ItLabel
@onready var player_list := $VBoxContainer/PlayerList
@onready var leave_button := $VBoxContainer/LeaveButton

func _ready():
	Lobby.player_disconnected.connect(_on_player_disconnected)
	Lobby.server_disconnected.connect(_on_server_disconnected)
	update_player_list()

func update_it_label(it_peer_id: int):
	var local_id = multiplayer.get_unique_id()
	if it_peer_id == local_id:
		it_label.text = "YOU ARE IT!"
		it_label.modulate = Color.RED
	else:
		var name_str = Lobby.players.get(it_peer_id, {}).get("name", "Player")
		it_label.text = name_str + " is IT"
		it_label.modulate = Color.WHITE

func update_player_list():
	var text = ""
	for id in Lobby.players:
		var name_str = Lobby.players[id].get("name", "Unknown")
		var it_str = " (IT)" if id == get_parent().it_peer_id else ""
		text += name_str + it_str + "\n"
	player_list.text = text

func _on_leave_pressed():
	Lobby.remove_multiplayer_peer()
	get_tree().change_scene_to_file("res://scenes/Menu/Menu.tscn")

func _on_player_disconnected(_id):
	update_player_list()

func _on_server_disconnected():
	get_tree().change_scene_to_file("res://scenes/Menu/Menu.tscn")
