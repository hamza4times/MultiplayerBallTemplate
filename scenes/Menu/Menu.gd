extends Control

@onready var tab_container := $TabContainer
@onready var name_input := $TabContainer/Play/NameInput
@onready var host_button := $TabContainer/Play/HostButton
@onready var ip_input := $TabContainer/Play/HBoxContainer/IPInput
@onready var join_button := $TabContainer/Play/HBoxContainer/JoinButton
@onready var player_list := $TabContainer/Play/PlayerList
@onready var start_button := $TabContainer/Play/StartButton
@onready var status_label := $TabContainer/Play/StatusLabel

@onready var preview_mesh := $TabContainer/Locker/PreviewArea/SubViewportContainer/SubViewport/PreviewMesh
@onready var color_buttons_container := $TabContainer/Locker/PreviewArea/ColorButtons
@onready var save_button := $TabContainer/Locker/SaveContainer/SaveButton

var selected_color: Color
var preview_material: StandardMaterial3D

func _ready():
	Lobby.player_connected.connect(_on_player_connected)
	Lobby.player_disconnected.connect(_on_player_disconnected)
	Lobby.server_disconnected.connect(_on_server_disconnected)
	start_button.hide()
	update_player_list()

	tab_container.set_tab_title(0, "Play")
	tab_container.set_tab_title(1, "Locker")

	preview_material = StandardMaterial3D.new()
	selected_color = Lobby.player_info.get("color", Lobby.COLORS["Blue"])
	preview_material.albedo_color = selected_color
	preview_mesh.material_override = preview_material

	_build_color_buttons()

func _build_color_buttons():
	for color_name in Lobby.COLORS:
		var color = Lobby.COLORS[color_name]
		var btn = Button.new()
		btn.text = color_name
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var style = StyleBoxFlat.new()
		style.bg_color = color
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		btn.add_theme_stylebox_override("normal", style)
		if color.v > 0.5:
			btn.add_theme_color_override("font_color", Color.BLACK)
		btn.pressed.connect(_on_color_button_pressed.bind(color))
		color_buttons_container.add_child(btn)

func _on_color_button_pressed(color: Color):
	selected_color = color
	preview_material.albedo_color = color

func _on_save_pressed():
	Lobby.save_player_color(selected_color)
	save_button.text = "Saved!"
	await get_tree().create_timer(1.5).timeout
	save_button.text = "Save Color"

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