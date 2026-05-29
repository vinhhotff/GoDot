extends StaticBody3D

var prompt_message: String = ""

func interact(player_node) -> void:
	if has_meta("interact_callable"):
		var callable = get_meta("interact_callable")
		callable.call(player_node)
