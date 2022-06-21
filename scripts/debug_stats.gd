extends MarginContainer


class Property:
	var num_format: String = "%4.2f"
	var object: Object
	var property: NodePath
	var label_ref: Label
	var display: String

	func _init(_object: Object, _property: NodePath,
		_label: Label, _display: String) -> void:
		object = _object
		property = _property
		label_ref = _label
		display = _display

	func set_label():
		var s = object.name + "/" + property + " : "
		var p = object.get_indexed(property)
		match display:
			"":
				s += str(p)

			"length":
				s += num_format % p.length()

			"round":
				match typeof(p):
					TYPE_INT, TYPE_REAL:
						s += num_format % p
					TYPE_VECTOR2, TYPE_VECTOR3:
						s += str(p.round())

		label_ref.text = s


var props = []


func _process(_delta):
	if not visible:
		return

	for prop in props:
		prop.set_label()


func add_property(object, property, display):
	var label = Label.new()
#	label.set("custom_fonts/font", load("res://debug/roboto_16.tres"))
	$stats.add_child(label)
	props.append(Property.new(object, property, label, display))


func remove_property(object, property):
	for prop in props:
		if prop.object == object and prop.property == property:
			props.erase(prop)

