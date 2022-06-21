extends Node2D

export(String) var color

var matched := false setget _set_matched

func delete() -> void:
	$tween.interpolate_property(self, "scale", scale, Vector2(.3, .3), .3, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	$tween.start()
	yield($tween, "tween_completed")
	queue_free()


func move(target: Vector2) -> void:
	$tween.interpolate_property(self, "position", position, target, .3, Tween.TRANS_BOUNCE, Tween.EASE_OUT)
	$tween.start()


func _dim() -> void:
	$sprite.modulate = Color(1, 1, 1, .3)


func _set_matched(value: bool) -> void:
	matched = value
	if matched:
		_dim()
