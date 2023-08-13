extends Node3D


@onready var main_menu_label = $"MenuCanvasLayer/Main Menu Container/Main Menu Label"
@onready var main_menu_container = $"MenuCanvasLayer/Main Menu Container"

@onready var server_disconnected_alert = $"MenuCanvasLayer/Server Disconnected"

@onready var pause_menu = $"MenuCanvasLayer/Pause Menu"

@onready var host_button = $"MenuCanvasLayer/Main Menu Container/MarginContainer/VBoxContainer/Host Button"
@onready var join_button = $"MenuCanvasLayer/Main Menu Container/MarginContainer/VBoxContainer/Join Button"
@onready var room_code = $"MenuCanvasLayer/Main Menu Container/MarginContainer/VBoxContainer/Room Code"
@onready var quit_button = $"MenuCanvasLayer/Main Menu Container/MarginContainer/VBoxContainer/Back Button"

@onready var chat_canvas_layer = $ChatCanvasLayer
@onready var chatbox = $"ChatCanvasLayer/ChatBox Container/Chatbox"
@onready var enter_text = $"ChatCanvasLayer/ChatBox Container/Enter Text"

@onready var chat_box_container = $"ChatCanvasLayer/ChatBox Container"

##Player Hud
@onready var player_hud = $PlayersHud

@onready var player_hud_health_panel = $PlayersHud/Control/HealthPanel
@onready var player_hud_health_count = $PlayersHud/Control/HealthPanel/HealthCount
@onready var player_hud_helath_label = $PlayersHud/Control/HealthPanel/HealthLabel


const PORT = 4001
var enet_peer = ENetMultiplayerPeer.new()
var CurrentLevel:StringName
var CurrentHud : Node
var SpawnedObjects : Array

## Called when the node enters the scene tree for the first time.
func _ready():
	if Globals.GameMode == Globals.GameModes.practice:
		add_level("Lobby")
		add_player(1)
		main_menu_container.hide()
		
## Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	update_current_hud()
 
## Handle Inputs
func _unhandled_input(event):
	if Input.is_action_just_pressed("Menu"): ##If Chatbox is visible, hide it with Menu button
		if chat_box_container.visible:
			chat_box_container.hide()
			Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
			return
		if !pause_menu.visible and !main_menu_container.visible: ##If Pause Menu is not Visible, Make it Visible
			pause_menu.show()
			Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
		elif pause_menu.visible and !main_menu_container.visible: ##If Pause Menu is visible, Hide it.
			pause_menu.hide()
			Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	if Input.is_action_just_pressed("Chat"): ##Reveals Chatbox
		if chat_box_container.hidden:
			Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
			chat_box_container.show()
	if chat_box_container.visible: ##Handles Sending Chat based on Player Authority
		if Input.is_action_just_pressed("ui_text_newline"):
			var text = enter_text.text
			enter_text.clear()
			if is_multiplayer_authority():
				send_chat_to_server(text)
			else:
				rpc_id(1, "send_chat_to_server", text)

##Quit Button from Multiplayer Menu
func _on_quit_button_pressed():
	enet_peer.close()
	get_tree().change_scene_to_file("res://levels/Menu/Menu.tscn")

##Quit Button on Pause Menu, Closes Server for Host, Kicks Player from server for Client, Sends to Multiplayer Menu
func _on_pause_menu_quit_button_pressed():
	if is_multiplayer_authority():
		close_server()
	else:
		rpc_id(1, "kick_player", multiplayer.get_unique_id())
		close_server()
	get_tree().change_scene_to_file("res://levels/Menu/Menu.tscn")

##Resumes Gameplay, Hides Pause Menu
func _on_resume_button_pressed():
	pause_menu.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

##Hides Multiplayer Menu, Hosts new Server
func _on_host_button_pressed():
	main_menu_container.hide()
	host_server()

##Connects to server on supplied IP address, defaults to 'localhost'
func _on_join_button_pressed():
	var roomcode = room_code.get("text")
	if roomcode == "":
		enet_peer.create_client("localhost", PORT)
	else:
		enet_peer.create_client(roomcode, PORT)
		print("connected to " + str(roomcode))
	multiplayer.multiplayer_peer = enet_peer
	multiplayer.server_disconnected.connect(server_disconnected)
	main_menu_container.hide()

func _on_player_button_pressed():
	inst_hud("Players")
	if is_multiplayer_authority():
		switch_character("player")
	else:
		switch_character.rpc("player")

func _on_switch_level_pressed():
	if is_multiplayer_authority():
		switch_level("Level1")
	else:
		rpc_id(1,"switch_level","Level1")

##Sent from Signal, Shows 'Server Disconnected' Menu
func server_disconnected():
	print("Server Disconnected")
	pause_menu.hide()
	server_disconnected_alert.show()

##Remotely Switch Level to supplied 'level'
@rpc("any_peer")
func switch_level(level:StringName):
	var peer_id = multiplayer.get_remote_sender_id()
	print("Level Change Sent By: " + str(peer_id))
	remove_level(CurrentLevel)
	add_level(level)

##Remotely Switch current player 'character' to supplied 'character'
@rpc("any_peer")
func switch_character(character="spectator"):
	var peer_id = multiplayer.get_remote_sender_id()
	if str(peer_id)=="0":peer_id = multiplayer.get_unique_id()
	var player = get_node_or_null(str(peer_id))
	if player:
		remove_child(player)
	if character == "player":
		add_player(peer_id)
#	elif character == "other":  ## use to have multiple player types (CharacterBody3D)
#		add_other(peer_id)
	else:
		add_player(peer_id)

##Remotely adds 'message' to ChatBox
@rpc("any_peer")
func send_chat_to_server(message : String):
	var peer_id = multiplayer.get_remote_sender_id()
	if str(peer_id)=="0":peer_id = multiplayer.get_unique_id()
	print("Message Sent By " + str(peer_id), ": ", message)
	chatbox.set("text", chatbox.get("text")+(str(peer_id) + ": " + message))

##Adds "Level" Scene to Tree
func add_level(level_name):
	var Level = load("res://levels/"+level_name+"/"+level_name+".tscn")
	var level = Level.instantiate()
	level.name = level_name
	CurrentLevel = level_name
	add_child(level)
	SpawnedObjects.append(level)
	print("Level Spawned: ", str(level_name))

##Despawns "Level" Scene from Tree
func remove_level(level_name):
	var Level = get_node_or_null(NodePath(level_name))
	if Level:
		remove_child(Level)
		SpawnedObjects.erase(Level)
	print("Level Despawned")

##Spawn in Player
func add_player(peer_id):
	var Player = load("res://assets/players/player.tscn")
	var player : CharacterBody3D = Player.instantiate()
	player.name = str(peer_id)
	player.CurrentTeam = Globals.Team.players
	add_child(player)
	SpawnedObjects.append(player)
	return player

##Spawn in Other
#func add_other(peer_id):
#	var Player = load("res://assets/players/other.tscn")
#	var player : CharacterBody3D = Player.instantiate()
#	player.name = str(peer_id)
#	player.CurrentTeam = Globals.Team.players
#	add_child(player)
#	SpawnedObjects.append(player)
#	return player

## Removes Player Object, Does not Disconnect Player Directly
func remove_player(peer_id):
	var player = get_node_or_null(str(peer_id))
	SpawnedObjects.erase(player)
	if player: 
		player.queue_free()

## Universal Plug N Play Setup, Outputs any Errors
func upnp_setup():
	var upnp = UPNP.new()
	
	var discover_result = upnp.discover()
	assert(discover_result == UPNP.UPNP_RESULT_SUCCESS, "UPNP Discover Failed! Error %s" % discover_result)

	assert(upnp.get_gateway() and upnp.get_gateway().is_valid_gateway(), "UPNP Invalid Gateway!")

	var map_result = upnp.add_port_mapping(PORT)
	assert(map_result == UPNP.UPNP_RESULT_SUCCESS, "UPNP Port Mapping Failed! Error %s" % map_result)
	
	print("Server Creation Success... Join Address: %s" % upnp.query_external_address())

## Remove the inputted peer from the multiplayer server
@rpc("any_peer")
func kick_player(peer_id:int):
	multiplayer.disconnect_peer(peer_id)

## Instance Desired HUD
func inst_hud(desired_hud:String):
#	## First Hide all PlayerHuds
#	for team in Globals.Teams:
#		get_node(team.name + "Hud").hide()
	## Then show the desired team hud if it exists.
	if desired_hud == "Spectators" : return
	CurrentHud = get_node(desired_hud + "Hud")
	CurrentHud.show()

## Open a new server instance on current IP address
func host_server():
	enet_peer.create_server(PORT)
	multiplayer.multiplayer_peer = enet_peer
	print("HOST Connected")
	multiplayer.peer_connected.connect(add_player)
	multiplayer.peer_disconnected.connect(remove_player)
	add_level("Lobby")
	switch_character()
	upnp_setup()

## Host Closes Server, Despawns all Elements
@rpc("any_peer", "call_remote")
func close_server():
	for object in SpawnedObjects:
		object.queue_free()
	pause_menu.hide()
	main_menu_container.show()
	var peers = multiplayer.get_peers()
	enet_peer.close()

## Update Current Hud to reflect Player Data
func update_current_hud():
	## Display Health
	var peer_id = multiplayer.get_unique_id()
	var player = get_node_or_null(str(peer_id))
	if player != null and CurrentHud != null:
		var playerhealth = player.get("Health")
		CurrentHud.get_node_or_null("Control").get_node_or_null("HealthPanel").get_node_or_null("HealthCount").set("text", playerhealth)

