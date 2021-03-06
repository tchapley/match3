extends Node2D

enum board_state {
	PLAYING,
	DELETING,
	REFILLING,
	SWAPPING
}

const TILE_SIZE = 64

export(int) var width = 10
export(int) var height = 10
export(int) var x_start = TILE_SIZE
export(int) var y_start = (TILE_SIZE * height) + TILE_SIZE
export(int) var offset = TILE_SIZE / 2
export(Array, PackedScene) var pieces_scenes

var pieces := []
var touch_start := Vector2.ZERO
var touch_end := Vector2.ZERO
var controlling := false
var current_state = board_state.PLAYING

onready var l_arrow: Line2D = $l_arrow
onready var r_arrow: Line2D = $r_arrow

func _ready() -> void:
	DebugStats.add_property(self, "current_state", "")
	randomize()
	_create_grid()


func _process(_delta: float) -> void:
	var mouse_pos := get_global_mouse_position()
	var grid_pos := _pixel_to_grid(mouse_pos.x, mouse_pos.y)

	if current_state != board_state.PLAYING:
		return

	_swipe()

	if Input.is_action_just_pressed("right_click"):
		print(_pixel_to_grid(get_global_mouse_position().x, get_global_mouse_position().y))
		_delete_row(grid_pos.y)
#		_delete_col(grid_pos.x)
#		_random_delete(10)


func _create_grid() -> void:
	pieces = []
	for x in width:
		var col := []
		for y in height:
			col.append(null)
		pieces.append(col)

	for x in width:
		for y in height:
			pieces[x][y] = _create_piece(x, y, pieces_scenes, true)


func _create_piece(col: int, row: int, possible_pieces: Array, prevent_match: bool) -> Node2D:
	if possible_pieces.size() == 0:
		return null

	var rand = floor(rand_range(0, possible_pieces.size()))
	var piece: Node2D = possible_pieces[rand].instance()
	if prevent_match and _will_cause_match(col, row, piece):
		var temp_pieces: Array = [] + possible_pieces
		temp_pieces.remove(rand)
		piece = _create_piece(col, row, temp_pieces, true)
		return piece

	add_child(piece)
	piece.position = _grid_to_pixel(col, height)
	piece.move(_grid_to_pixel(col, row))
	return piece


func _delete_piece(col: int, row: int, must_match: bool) -> void:
	var piece: Node2D = pieces[col][row]
	if piece != null and (piece.matched or !must_match):
		piece.delete()
		pieces[col][row] = null


func _select_piece(col: float, row: float) -> Node2D:
	if _in_grid(col, row):
		return pieces[col][row]
	return null


func _pixel_to_grid(x: float, y: float) -> Vector2:
	var col: float = floor((x - x_start) / TILE_SIZE)
	var row: float = floor(((y - y_start) / TILE_SIZE) * -1)
	return Vector2(col, row)


func _grid_to_pixel(col: float, row: float) -> Vector2:
	var x: int = x_start + (col * TILE_SIZE) + offset
	var y: int = y_start - (row * TILE_SIZE) - offset
	return Vector2(x, y)


func _in_grid(col: float, row: float) -> bool:
	if col < 0 or col >= width:
		return false
	if row < 0 or row >= height:
		return false
	return true


func _check_match(col: int, row: int) -> bool:
	var found_match := false
	if _select_piece(col, row) == null:
		return found_match

	var piece: Node2D = _select_piece(col, row)
	var color: String = piece.color

	var left_piece: Node2D = _select_piece(col - 1, row)
	var right_piece: Node2D = _select_piece(col + 1, row)

	if (left_piece != null and right_piece != null) \
	   and (left_piece.color == color and right_piece.color == color):
		found_match = true
		left_piece.matched = true
		right_piece.matched = true
		piece.matched = true

	var bottom_piece: Node2D = _select_piece(col, row - 1)
	var top_piece: Node2D = _select_piece(col, row + 1)

	if (bottom_piece != null and top_piece != null) \
	   and (bottom_piece.color == color and top_piece.color == color):
		found_match = true
		bottom_piece.matched = true
		top_piece.matched = true
		piece.matched = true

	return found_match


func _will_cause_match(col: int, row: int, piece: Node2D) -> bool:
	if col < 2 and row < 2:
		return false

	var most_left: Node2D = _select_piece(col - 2, row)
	var left: Node2D = _select_piece(col - 1, row)
	var lowest: Node2D = _select_piece(col, row - 2)
	var lower: Node2D = _select_piece(col, row - 1)

	if (most_left != null and left != null) \
	   and (piece.color == most_left.color and left.color):
		return true

	if (lowest != null and lower != null) \
	   and (piece.color == lowest.color and lower.color):
		return true
	return false


func _find_matches(from_swap: bool) -> void:
	var found_matches := false
	for x in width:
		for y in height:
			if _check_match(x, y):
				found_matches = true

	if !found_matches:
		if from_swap:
			yield(get_tree().create_timer(1.0), "timeout")
			_swap_pieces(touch_end, touch_start, true)
			yield(get_tree().create_timer(0.5), "timeout")
		current_state = board_state.PLAYING
		return

	$collapse_timer.start()


func _collapse_grid() -> void:
	for x in width:
		for y in height:
			_delete_piece(x, y, true)

	$refill_timer.start()


# TODO: Fix how pieces spawn
func _refill_grid() -> void:
	if current_state == board_state.DELETING:
		return

	current_state = board_state.REFILLING
	for x in width:
		for y in height:
			var piece: Node2D = _select_piece(x, y)
			if piece == null:
				for i in range(y + 1, height):
					var new_piece: Node2D = _select_piece(x, i)
					if new_piece != null:
						piece = new_piece
						pieces[x][y] = new_piece
						pieces[x][i] = null
						break

	for x in width:
		for y in height:
			var piece: Node2D = _select_piece(x, y)
			if piece == null:
				pieces[x][y] = _create_piece(x, y, pieces_scenes, false)
			else:
				piece.move(_grid_to_pixel(x, y))

	yield(get_tree().create_timer(1.0), "timeout")
	_find_matches(false)


func _swipe() -> void:
	var mouse_pos := get_global_mouse_position()
	var grid_pos := _pixel_to_grid(mouse_pos.x, mouse_pos.y)
	if _in_grid(grid_pos.x, grid_pos.y):
		if Input.is_action_just_pressed("left_click"):
			controlling = true
			print("Start: " + str(grid_pos))
			touch_start = grid_pos
		if Input.is_action_just_released("left_click") and controlling:
			touch_end = grid_pos
			print("Start " + str(touch_start) + " -- End " + str(touch_end))
			_swap_pieces(touch_start, touch_end, false)
			controlling = false


func _swap_pieces(start: Vector2, end: Vector2, swap_back: bool) ->  void:

	var direction := end - start
	direction = direction.normalized()
	var swap := start + direction
	var swap_piece: Node2D = _select_piece(swap.x, swap.y)
	if (direction.x != 0 and direction.y != 0) or (direction == Vector2.ZERO):
		return
	current_state = board_state.SWAPPING
	print("Swapping with: " + str(start + direction))
	print(direction)
	pieces[swap.x][swap.y] = _select_piece(start.x, start.y)
	pieces[start.x][start.y] = swap_piece
	pieces[start.x][start.y].move(_grid_to_pixel(start.x, start.y))
	pieces[swap.x][swap.y].move(_grid_to_pixel(swap.x, swap.y))

	if !swap_back:
		_find_matches(true)


func _delete_row(row: int) -> void:
	var middle: float = (float(width) / 2.0)
	var jump := 1
	if middle - int(middle) != 0:
		middle = int(middle)
		jump = 2
	else:
		middle -= 1
	while middle >= 0:
		current_state = board_state.DELETING
		l_arrow.clear_points()
		l_arrow.add_point(Vector2(get_viewport_rect().size.x / 2, get_viewport_rect().size.y))
		l_arrow.add_point(Vector2(_grid_to_pixel(middle, row)))
		l_arrow.show()
		if middle != width / 2:
			r_arrow.clear_points()
			r_arrow.add_point(Vector2(get_viewport_rect().size.x / 2, get_viewport_rect().size.y))
			r_arrow.add_point(Vector2(_grid_to_pixel(middle + jump, row)))
			r_arrow.show()
		yield(get_tree().create_timer(1.0), "timeout")
		_delete_piece(middle, row, false)
		l_arrow.hide()
		if middle != width / 2:
			_delete_piece(middle + jump, row, false)
			jump += 2
			r_arrow.hide()
		middle -= 1
		yield(get_tree().create_timer(1.0), "timeout")


	$refill_timer.start()


func _delete_col(col: int) -> void:
	for y in height:
		_delete_piece(col, y, false)

	$refill_timer.start()


func _random_delete(cells_to_delete: int) -> void:
	for i in range(cells_to_delete):
		var deleted := false
		while !deleted:
			var col := rand_range(0, width)
			var row := rand_range(0, height)
			if pieces[col][row] != null:
				deleted = true
				_delete_piece(col, row, false)

	$refill_timer.start()


func _on_collapse_timer_timeout() -> void:
	_collapse_grid()


func _on_refill_timer_timeout() -> void:
	current_state = board_state.PLAYING
	_refill_grid()
