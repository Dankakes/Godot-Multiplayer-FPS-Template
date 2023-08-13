extends Control

@onready var tab_bodies = $TabBodies
@onready var tab_bar = $TabBar

@onready var General = $"TabBodies/General Settings"
@onready var Multiplayer = $"TabBodies/Multiplayer Settings"
@onready var Video = $"TabBodies/Video Settings"
@onready var Sound = $"TabBodies/Sound Settings"

@onready var settings_menu_container = $"."
@onready var main_menu_container = $"../Main Menu Container"

# Called when the node enters the scene tree for the first time.
func _ready():
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
	

func _on_tab_bar_tab_changed(tab):
	switch_tab(tab)

func switch_tab(tab):
	var TabBodies = [General, Multiplayer, Video, Sound]
	for index in TabBodies.size():
		TabBodies[index].hide()
	TabBodies[tab].show()


func _on_back_pressed():
	settings_menu_container.hide()
	main_menu_container.show()


func _on_save_pressed():
	settings_menu_container.hide()
	main_menu_container.show()
