@icon("res://addons/drag-drop-area-3d/drag_drop_area_3d_icon.svg")
@tool
## A 3D area that acts as a drag-and-drop zone, projecting its bounds onto the 2D screen.[br]
## Useful for creating 3D UI drop zones or spatial drag interactions.[br]
## Godot 4.2+ compatible.[br]
## [b]Warning:[/b] This class is specifically designed for drag-and-drop interactions and is [b]not recommended[/b] 
## for general-purpose [Area3D] use cases. It automatically modifies its [member collision_layer] in [method _ready] 
## to accommodate raycasting, and it carries additional performance overhead due to the 2D projection calculations.[br]
## Use a standard [Area3D] for regular physics or trigger detection.
class_name DragDropArea3D
extends Area3D

## The 3D dimensions of the drag-and-drop area.[br]
## Modifying this at runtime will automatically call [method queue_update] to refresh the collision shape and debug visuals.
@export_custom(PROPERTY_HINT_LINK, "") var size: Vector3 = Vector3.ONE:
	set(v):
		size = v
		queue_update()
## A [PackedScene] of a [Control] node to instantiate and display as a visual preview while dragging.
@export var drag_preview_scene: PackedScene = null

@export_group("Performance")
## If [code]true[/code], the area will continuously update its projected polygon during runtime.[br]
## Disable this for better performance if the area and camera are mostly static.
@export var continuous_update: bool = true
## The number of frames to skip between continuous updates.[br]
## Higher values improve performance but may cause visual lag in debug overlays.
@export_range(0, 60, 1) var frame_skip_count: int = 3
## Offsets the frame skip counter, useful for staggering updates across multiple instances.
@export_range(0, 60, 1) var frame_offset: int = 0
## If [code]true[/code], [method is_mouse_inside] will perform a 3D physics raycast to verify 
## that the mouse is actually hovering over this specific [Area3D] and not occluded by other colliders.[br]
## If [code]false[/code], it relies solely on the 2D screen-projected polygon check, which is faster 
## but does not account for 3D occlusion.
@export var use_ray_casts: bool = true
## The 3D physics collision mask used for the raycast query.[br]
## [b]Note:[/b] This mask is also automatically added to the node's [member collision_layer] in [method _ready] 
## to ensure the raycast can detect this specific area.
@export_flags_3d_physics var raycast_mask: int = 1 << 7
## The maximum distance from the camera at which this area can be interacted with.[br]
## Used as the raycast length when [member use_ray_casts] is [code]true[/code], 
## and as a fallback distance check when [member use_ray_casts] is [code]false[/code].
@export_range(1.0, 4096.0, 0.001) var max_distance: float = 32.0

@export_group("Debug", "debug_")
## Master toggle for all debug visualizations. If [code]false[/code], no debug overlays will be drawn.
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "") var debug_enabled: bool = true
## If [code]true[/code], draws the projected 2D polygon on the screen for debugging purposes.[br]
## Only visible in debug builds and when [member debug_enabled] is [code]true[/code].
@export var debug_projected_polygon: bool = true
## If [code]true[/code], draws a bounding rect of the projected 2D polygon on the screen for debugging purposes.[br]
## Only visible in debug builds and when [member debug_enabled] is [code]true[/code].
@export var debug_control_rect: bool = false
## The fill [Color] used when drawing the debug projected polygon.
@export var debug_fill_color: Color = Color(0.4, 0.7, 0.9, 0.4)
## The [Color] used for the border of the debug projected polygon.
@export var debug_border_color: Color = Color(0.3, 0.85, 0.95, 0.9)
## The fill [Color] used when drawing the debug projected polygon's bounding rect.
@export var debug_rect_fill_color: Color = Color(0.9, 0.5, 0.1, 0.3)
## The [Color] used for the border of the debug projected polygon's bounding rect.
@export var debug_rect_border_color: Color = Color(0.9, 0.5, 0.1, 0.6)
## The thickness of the border drawn around the debug projected polygon and its bounding rect.
@export_range(0.0, 32.0) var debug_border_width: float = 4.0

## The custom data payload that will be dragged from this area.[br]
## [b]Note:[/b] Variant types cannot be exported in the inspector, so set this via code.
var data: Variant = null

var _collision_shape: CollisionShape3D = null
var _debug_mesh: MeshInstance3D = null
var _canvas_layer: CanvasLayer = null
var _control: Panel = null
var _empty_stylebox: StyleBoxEmpty = null
var _default_stylebox: StyleBoxFlat = null
var _projected_polygon: PackedVector2Array = []
var _bounding_rect: Rect2 = Rect2()
var _updating: bool = false
var _frame_index: int = 0

func _ready() -> void:
	collision_layer |= raycast_mask
	_update_debug_instances()
	queue_update()
	_frame_index = frame_offset

func _process(_delta: float) -> void:
	_frame_index = wrapi(_frame_index + 1, 0, frame_skip_count + 1) # Should skip the first update (intended)
	if not Engine.is_editor_hint() and continuous_update and _frame_index == 0:
		queue_update()

## Queues an asynchronous update for the collision shape, 2D projected polygon, and debug meshes.[br]
## This is automatically called when [member size] changes or when [member continuous_update] is active.
func queue_update() -> void:
	if _updating:
		return
	
	_updating = true
	_update.call_deferred()

## Checks if the given 2D [param mouse_position] is inside the screen-projected bounds of this 3D area.[br]
## First, it checks if the point is inside the 2D projected polygon.[br]
## If [member use_ray_casts] is [code]true[/code], it performs a 3D physics raycast (up to [member max_distance]) 
## using [member raycast_mask] to ensure the mouse is actually hitting this [Area3D] and not occluded.[br]
## If [member use_ray_casts] is [code]false[/code], it falls back to a simple distance check, 
## returning [code]false[/code] if the area is further than [member max_distance] from the camera.[br]
## Returns [code]true[/code] if the position is valid and passes the enabled checks.
func is_mouse_inside(mouse_position: Vector2) -> bool:
	if _projected_polygon.size() < 3:
		return false
	
	if not Geometry2D.is_point_in_polygon(mouse_position, _projected_polygon):
		return false
	
	var viewport: Viewport = get_viewport()
	if not viewport:
		return false
	
	var camera: Camera3D = viewport.get_camera_3d()
	if not camera:
		return false
	
	if use_ray_casts:
		var world_3d: World3D = get_world_3d()
		if not world_3d:
			return false
		
		var projected_position: Vector3 = camera.project_ray_origin(mouse_position)
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			projected_position,
			projected_position + camera.project_ray_normal(mouse_position) * max_distance
		)
		query.collide_with_areas = true  # off by default
		query.collision_mask = collision_layer | raycast_mask  # All what can be detected plus similar areas
		var result: Dictionary = world_3d.direct_space_state.intersect_ray(query)
		return result.get("collider") == self
	
	else:
		var to_camera: Vector3 = camera.global_position - global_position
		if to_camera.length_squared() > max_distance * max_distance:
			return false
	
	return true

func _get_polygon_bounding_rect(polygon: PackedVector2Array) -> Rect2:
	if polygon.size() < 3:
		return Rect2()
	
	var rect: Rect2 = Rect2(polygon[0], Vector2.ZERO)
	for vertex: Vector2 in polygon:
		rect = rect.expand(vertex)
	
	return rect

func _update() -> void:
	_updating = false
	_update_shape()
	_update_projected_polygon()
	_update_control()
	_update_debug_mesh()

func _update_control() -> void:
	if not _canvas_layer:
		if _control:
			_control.queue_free()
		
		_canvas_layer = CanvasLayer.new()
		_control = Panel.new()
		_canvas_layer.add_child(_control)
		_control.mouse_filter = Control.MOUSE_FILTER_PASS
		_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_control.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_control.draw.connect(_on_control_draw)
		_control.set_drag_forwarding(_get_drag_data, _control_can_drop_data, _drop_data)
		add_child.call_deferred(_canvas_layer, false, Node.InternalMode.INTERNAL_MODE_FRONT)
	
	@warning_ignore("incompatible_ternary")
	var target_stylebox: StyleBox = _default_stylebox if debug_enabled and debug_control_rect and OS.is_debug_build() else _empty_stylebox
	if _control.get_theme_stylebox(&"panel") != target_stylebox:
		_control.add_theme_stylebox_override(&"panel", target_stylebox)
	
	_control.position = _bounding_rect.position
	_control.size = _bounding_rect.size
	_control.queue_redraw()

func _update_shape() -> void:
	if not _collision_shape:
		_collision_shape = CollisionShape3D.new()
		_collision_shape.shape = BoxShape3D.new()
		add_child.call_deferred(_collision_shape, false, Node.InternalMode.INTERNAL_MODE_FRONT)
	
	_collision_shape.shape.size = size

func _update_projected_polygon() -> void:
	if size.is_zero_approx():
		_projected_polygon.clear()
		_bounding_rect = Rect2()
		return
	
	var viewport: Viewport = get_viewport()
	if not viewport:
		_projected_polygon.clear()
		_bounding_rect = Rect2()
		return
	
	var camera: Camera3D = viewport.get_camera_3d()
	if not camera:
		_projected_polygon.clear()
		_bounding_rect = Rect2()
		return
	
	var vertices: PackedVector3Array = [
		Vector3(1, 1, 1),
		Vector3(-1, 1, 1),
		Vector3(1, -1, 1),
		Vector3(-1, -1, 1),
		Vector3(1, 1, -1),
		Vector3(-1, 1, -1),
		Vector3(1, -1, -1),
		Vector3(-1, -1, -1),
	]
	var points: PackedVector2Array = []
	var half_size: Vector3 = size / 2.0
	for vertex_index: int in vertices.size():
		var vertex: Vector3 = vertices[vertex_index]
		var transformed_vertex: Vector3 = global_transform * (vertex * half_size)
		if camera.is_position_behind(transformed_vertex):
			_projected_polygon.clear() # Absolutely unwanted behavior
			_bounding_rect = Rect2()
			return
		
		points.push_back(camera.unproject_position(transformed_vertex))
	
	if points.size() < 3:
		_projected_polygon.clear()
		_bounding_rect = Rect2()
		return
	
	_projected_polygon = Geometry2D.convex_hull(points)
	_bounding_rect = _get_polygon_bounding_rect(_projected_polygon)

func _update_debug_instances() -> void:
	_empty_stylebox = StyleBoxEmpty.new()
	_default_stylebox = StyleBoxFlat.new()
	_default_stylebox.bg_color = debug_rect_fill_color
	_default_stylebox.border_color = debug_rect_border_color
	_default_stylebox.set_border_width_all(int(debug_border_width))

func _update_debug_mesh() -> void:
	if not Engine.is_editor_hint():
		return
	
	if not _debug_mesh:
		_debug_mesh = MeshInstance3D.new()
		_debug_mesh.mesh = BoxMesh.new()
		_debug_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = debug_fill_color
		_debug_mesh.material_override = mat
		add_child.call_deferred(_debug_mesh, false, Node.InternalMode.INTERNAL_MODE_FRONT)
	
	_debug_mesh.mesh.size = size

func _control_can_drop_data(at_position: Vector2, dragged_data: Variant) -> bool:
	at_position = at_position + _control.position
	if not is_mouse_inside(at_position):
		return false
	
	return _can_drop_data(at_position, dragged_data)

## Virtual method. Override this to define custom logic determining if the [param dragged_data] can be dropped.[br]
## By default, it returns [code]true[/code] if the mouse is inside the area.
func _can_drop_data(_at_position: Vector2, _dragged_data: Variant) -> bool:
	return true

func _get_drag_data(at_position: Vector2) -> Variant:
	at_position = at_position + _control.position
	if not is_mouse_inside(at_position):
		return null
	
	if drag_preview_scene and drag_preview_scene.can_instantiate():
		var preview: Control = drag_preview_scene.instantiate() as Control
		if preview:
			_control.set_drag_preview(preview)
	
	return data

## Virtual method. Override this to handle the drop event and process the [param dragged_data].
## Called when valid data is dropped within the area's bounds.
func _drop_data(_at_position: Vector2, _dragged_data: Variant) -> void:
	pass

func _on_control_draw() -> void:
	if _projected_polygon.size() < 3:
		return
	
	if debug_enabled and debug_projected_polygon and OS.is_debug_build() and _control:
		var local_polygon: PackedVector2Array = PackedVector2Array()
		local_polygon.resize(_projected_polygon.size())
		for i: int in _projected_polygon.size():
			local_polygon[i] = _projected_polygon[i] - _control.position
		_control.draw_polygon(local_polygon, [debug_fill_color])
		_control.draw_polyline(local_polygon, debug_border_color, debug_border_width)

