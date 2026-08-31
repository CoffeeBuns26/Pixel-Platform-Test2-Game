extends Node2D

@export_file("*.tscn") var next_scene := "res://main.tscn"

func _ready() -> void:
	add_to_group("level_manager")

func check_all_slimes_defeated() -> void:
	if get_tree().get_nodes_in_group("enemies").is_empty():
		get_tree().change_scene_to_file(next_scene)
