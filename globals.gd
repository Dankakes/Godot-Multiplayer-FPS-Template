extends Node

## Team Class
class Team:
	var name
	var players_array : Dictionary
	func _init(Name):
		name = Name
	func add_player(Player:CharacterBody3D):
		players_array[Player.name]=Player
	func remove_player(Player:CharacterBody3D):
		players_array.erase(Player.name)
	func has_player(Player:CharacterBody3D):
		return players_array.has(Player.name)
	static var teams = ["Team1", "Team2", "Spectators"]
	static var players = teams[0]
	static var monsters = teams[1]
	static var spectators = teams[1]
## Defined Game Modes
class GameModes:
	static var modes = ["Practice", "Multiplayer"]
	static var practice = modes[0]
	static var multi_player = modes[1]
## Defined Player Statuses
class PlayerStatus:
	static var statuses = ["Stable", "Injured", "Incapacitated", "Stunned", "Confused", "Dead"]
	static var stable = statuses[0]
	static var injured = statuses[1]
	static var incapacitated = statuses[2]
	static var stunned = statuses[3]
	static var confused = statuses[4]
	static var dead = statuses[5]

var Spectators = Team.new("Spectators")
var Team1 = Team.new("Team1")
var Team2 = Team.new("Team2")

var Teams : Array = [Spectators, Team1, Team2]

var GameMode
func set_gamemode(gamemode):
	assert(gamemode in GameModes.modes)
	GameMode = gamemode

## Set Players Team
@rpc("any_peer")
func set_players_team(Player : CharacterBody3D, Team : String):
	if is_multiplayer_authority():
		remove_player_from_team(Player)
	else:
		remove_player_from_team.rpc(Player)
	for team in Globals.Teams:
		if team.name == Team:
			team.add_player(Player)
## Remove Player from Team
@rpc("any_peer")
func remove_player_from_team(Player:CharacterBody3D):
	for team in Globals.Teams:
		if team.has_player(Player):
			team.remove_player(Player)

## Ilicitly Spawns in a Player Object regardless of settings.
func spawn_player():
	var Player = load("res://assets/players/player.tscn")
	var player : CharacterBody3D = Player.instantiate()
	get_tree().add_child(player)

## Return Team Object by Team Name
func get_team_obj_by_name(teamname : String):
	for team in Teams:
		if team.name == teamname:
			return team

## Return Team Object by Peer Id (INT)
func get_team_obj_by_peer_id(peer_id : int):
	for team in Teams:
		var player_array = team.players_array
		for key in player_array.keys():
			if str(key) == str(peer_id):
				return team

## Return Team Object by Player (CharacterPlayer3D)
func get_team_obj_by_player(Player : CharacterBody3D):
	for team in Teams:
		if team.has_player(Player):
			return team
