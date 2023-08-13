extends Node3D
@onready var practice_button = $"MenuCanvasLayer/Main Menu Container/MarginContainer/VBoxContainer/Practice"
@onready var multiplayer_button = $"MenuCanvasLayer/Main Menu Container/MarginContainer/VBoxContainer/Multiplayer"
@onready var settings_button = $"MenuCanvasLayer/Main Menu Container/MarginContainer/VBoxContainer/Settings"
@onready var quit_button = $"MenuCanvasLayer/Main Menu Container/MarginContainer/VBoxContainer/Quit Button"

@onready var main_menu_container = $"MenuCanvasLayer/Main Menu Container"
@onready var settings_menu_container = $"MenuCanvasLayer/Settings Menu Container"

## Called when the node enters the scene tree for the first time.
func _ready():
	pass
## Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_quit_button_pressed():
	get_tree().quit()


func _on_settings_pressed():
	main_menu_container.hide()
	settings_menu_container.show()


func _on_multiplayer_pressed():
	Globals.set_gamemode(Globals.GameModes.multi_player)
	get_tree().change_scene_to_file("res://levels/Main/Main.tscn")


func _on_practice_pressed():
	Globals.set_gamemode(Globals.GameModes.practice)
	var Level = load("res://levels/Main/Main.tscn")
	get_tree().change_scene_to_packed(Level)
