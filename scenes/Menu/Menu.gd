extends Control

@onready var name_input := $VBoxContainer/NameInput
@onready var host_button := $VBoxContainer/HostButton
@onready var ip_input := $VBoxContainer/HBoxContainer/IPInput
@onready var join_button := $VBoxContainer/HBoxContainer/JoinButton
@onready var player_list := $VBoxContainer/PlayerList
@onready var start_button := $VBoxContainer/StartButton
@onready var status_label := $VBoxContainer/StatusLabel

func _ready():
	Lobby.player_connected.connect(_on_player_connected)
	Lobby.player_disconnected.connect(_on_player_disconnected)
	Lobby.server_disconnected.connect(_on_server_disconnected)
	start_button.hide()
	update_player_list()

func _on_host_pressed():
	if name_input.text.strip_edges().is_empty():
		status_label.text = "Enter a name first!"
		return
	Lobby.player_info["name"] = name_input.text.strip_edges()
	var error = Lobby.create_game()
	if error:
		status_label.text = "Failed to host: " + error_string(error)
		return
	host_button.disabled = true
	join_button.disabled = true
	start_button.show()
	status_label.text = "Hosting on port 7000..."

func _on_join_pressed():
	if name_input.text.strip_edges().is_empty():
		status_label.text = "Enter a name first!"
		return
	Lobby.player_info["name"] = name_input.text.strip_edges()
	var address = ip_input.text.strip_edges()
	var error = Lobby.join_game(address)
	if error:
		status_label.text = "Failed to join: " + error_string(error)
		return
	host_button.disabled = true
	join_button.disabled = true
	status_label.text = "Connecting..."

func _on_start_pressed():
	Lobby.load_game.rpc("res://scenes/Game/World.tscn")

func _on_player_connected(peer_id, info):
	update_player_list()
	status_label.text = str(Lobby.players.size()) + " player(s) connected"

func _on_player_disconnected(peer_id):
	update_player_list()
	status_label.text = "Player disconnected"

func _on_server_disconnected():
	host_button.disabled = false
	join_button.disabled = false
	start_button.hide()
	update_player_list()
	status_label.text = "Disconnected from server"

func update_player_list():
	var text = ""
	for id in Lobby.players:
		var name_str = Lobby.players[id].get("name", "Unknown")
		text += "P" + str(id) + ": " + name_str + "\n"
	player_list.text = text
