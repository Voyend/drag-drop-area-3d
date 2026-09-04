# DragDropArea3D for Godot 4.2+

**Bridging the gap between 3D spatial interactions and Godot's native 2D GUI Drag & Drop system.**

![Godot 4.2+](https://img.shields.io/badge/Godot-4.2+-478CBF?logo=godot-engine&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-blue.svg)

## 🌟 Overview

Godot has an incredible native 2D Drag & Drop system, and a powerful 3D physics engine. But what if you want to combine them? What if you want to drag a 3D object from a 3D world into a 3D slot, using the native 2D UI drag preview?

Usually, developers end up reinventing the wheel: manually tracking `_input_event`, calculating drag thresholds, and building custom UI nodes.

**`DragDropArea3D` solves this elegantly.** It acts as a 3D `Area3D` that projects its bounding box onto the 2D screen as a convex hull polygon. It then creates a precisely-sized transparent `Panel` node that covers only the projected bounds and hooks directly into Godot's native drag-and-drop ecosystem. You get native drag previews, native drop signals, and seamless integration with existing 2D UI inventories—without writing a single custom drag-tracking loop.

> [!WARNING]
> **Not a general-purpose Area3D:** This class is specifically designed for drag-and-drop interactions. It automatically modifies its `collision_layer` in `_ready()` to accommodate raycasting and carries additional performance overhead due to 2D projection calculations. For regular physics or trigger detection, use a standard `Area3D`.

## ✨ Features

- **Native Integration:** Leverages Godot's built-in `Control` drag-and-drop via `set_drag_forwarding`. No custom input tracking required.
- **True 3D Occlusion:** Optional raycasting ensures the mouse is actually hovering over the 3D area and not blocked by other geometry.
- **Performance Optimized:** Features frame-skipping, deferred updates, and a tightly-fitted bounding rect so the overlay `Panel` only covers the necessary screen area.
- **Editor & Debug Tools:** Visualizes the 3D bounding box in the editor and the 2D projected polygon + bounding rect at runtime, all controlled by a master debug toggle.
- **Custom Previews:** Easily assign a `PackedScene` of a `Control` node to act as a custom drag preview.
- **Zero Dependencies:** Pure GDScript, works out of the box.

---

## 🎮 Perfect For... (Use Cases)

This plugin is a game-changer for genres that blend 3D worlds with inventory/management mechanics:

1. **Isometric / ARPG (Diablo-like):** Drag 3D loot from the ground directly into a 3D stash or crafting grid.
2. **RTS / Base Builders:** Drag 3D units from a 2D sidebar and drop them into a 3D deployment zone on the map.
3. **Escape Room / Puzzle Games:** Drag a 3D key and drop it into a 3D keyhole.
4. **Tabletop / Card Games:** Drag 2D/3D hybrid cards from a hand and play them onto a 3D board.
5. **Simulation / Management:** Drag 3D items into 3D shelves, racks, or containers.

---

## 📥 Installation

1. Download or clone this repository.
2. Copy the `addons/drag_drop_area_3d` folder into your Godot project's `res://addons/` directory.
3. Go to **Project > Project Settings > Plugins** and enable **DragDropArea3D**.

---

## 🚀 Quick Start

### 1. Setup the Area
Add a `DragDropArea3D` node to your 3D scene. Adjust the **Size** property in the inspector to define the 3D bounds.

### 2. Assign Data
In your script, assign the data you want to be dragged:
```gdscript
func _ready() -> void:
    # This is the payload that will be passed to the drop target
    data = {"item_id": "health_potion", "quantity": 5}
```

### 3. Handle the Drop
To handle drops, extend the `DragDropArea3D` class and override the virtual methods:

```gdscript
extends DragDropArea3D

# Override to check if the dropped data is valid for this specific area
func _can_drop_data(_at_position: Vector2, dragged_data: Variant) -> bool:
    if dragged_data is Dictionary and dragged_data.has("item_id"):
        return dragged_data["item_id"] == "health_potion"
    return false

# Override to process the data once it is successfully dropped
func _drop_data(_at_position: Vector2, dragged_data: Variant) -> void:
    print("Dropped item: ", dragged_data["item_id"])
    # Add your logic here (e.g., add to inventory, consume item, etc.)
```

### 4. (Optional) Set a Drag Preview
Assign a `PackedScene` containing a `Control` node to show a custom visual while dragging:
```gdscript
func _ready() -> void:
    drag_preview_scene = preload("res://ui/drag_preview.tscn")
```

---

## ⚙️ Inspector Properties

The inspector is neatly organized into logical groups to help you tune the plugin for your specific needs.

### Core Properties
| Property | Type | Description |
|---|---|---|
| **Size** | `Vector3` | The 3D dimensions of the drag-and-drop area. Modifying this at runtime automatically refreshes the collision shape and debug visuals. |
| **Drag Preview Scene** | `PackedScene` | A scene containing a `Control` node to instantiate and display as a visual preview while dragging. |
| **Data** | `Variant` | The custom payload that will be dragged. *(Set via code, as Variants cannot be exported in the inspector.)* |

### Performance Group
| Property | Type | Default | Description |
|---|---|---|---|
| **Continuous Update** | `bool` | `true` | If `true`, the area continuously updates its projected polygon during runtime. Disable if the area and camera are mostly static. |
| **Frame Skip Count** | `int` | `3` | Number of frames to skip between updates (0–60). Higher values = better performance, lower values = smoother tracking. |
| **Frame Offset** | `int` | `0` | Stagger updates across multiple instances to distribute the CPU load (0–60). |
| **Use Ray Casts** | `bool` | `true` | If `true`, performs a 3D physics raycast to verify the mouse is actually hitting this `Area3D` and not occluded by other 3D objects. If `false`, relies solely on the 2D screen projection (faster, but ignores depth occlusion). |
| **Max Distance** | `float` | `32.0` | The maximum distance from the camera at which this area can be interacted with. Used as the raycast length or fallback distance check. |
| **Raycast Mask** | `int` | `1 << 7` | The 3D physics collision mask used for the raycast query. Automatically added to the node's collision layer on ready. |

### Debug Group
All debug properties are gated behind a master toggle for easy on/off switching.

| Property | Type | Default | Description |
|---|---|---|---|
| **Debug Enabled** | `bool` | `true` | Master toggle for all debug visualizations. If `false`, no debug overlays will be drawn. |
| **Debug Projected Polygon** | `bool` | `true` | Draws the projected 2D convex hull polygon on the screen. Only visible in debug builds. |
| **Debug Control Rect** | `bool` | `false` | Draws the bounding rectangle of the projected polygon (i.e., the actual `Panel` area). Only visible in debug builds. |
| **Debug Fill Color** | `Color` | `(0.4, 0.7, 0.9, 0.4)` | Fill color for the projected polygon overlay. |
| **Debug Border Color** | `Color` | `(0.3, 0.85, 0.95, 0.9)` | Border color for the projected polygon overlay. |
| **Debug Rect Fill Color** | `Color` | `(0.9, 0.5, 0.1, 0.3)` | Fill color for the bounding rect overlay. |
| **Debug Rect Border Color** | `Color` | `(0.9, 0.5, 0.1, 0.6)` | Border color for the bounding rect overlay. |
| **Debug Border Width** | `float` | `4.0` | Thickness of borders for both the polygon and bounding rect overlays (0–32). |

---

## 🏗️ How It Works

1. **Projection:** The 8 corners of the 3D bounding box are transformed into world space and unprojected onto the 2D screen via the active `Camera3D`.
2. **Convex Hull:** The 2D points are passed through `Geometry2D.convex_hull()` to form a tight polygon.
3. **Bounding Rect:** A `Rect2` is computed from the polygon to precisely size and position a transparent `Panel` node on a `CanvasLayer`.
4. **Drag Forwarding:** The `Panel` uses `set_drag_forwarding()` to intercept Godot's native drag-and-drop callbacks and route them through `is_mouse_inside()` for accurate hit-testing.
5. **Occlusion & Distance Check:** Optionally, a 3D physics raycast confirms the mouse is truly over this `Area3D` and not blocked by another collider. If raycasts are disabled, it falls back to a fast distance check, ignoring the area if it's further than `max_distance` from the camera.

---

## ⚠️ Known Limitations

* **Camera Panning During Drag:** Because Godot's native drag events are tied to the initial mouse-down position, panning the 3D camera *while* actively holding the drag will not update the drag's origin. (Standard behavior for native UI drags).
* **Behind-Camera Clipping:** If any corner of the bounding box is behind the camera, the projected polygon is cleared entirely to prevent wildly incorrect projections.
* **Collision Layer Modification:** In `_ready()`, the node automatically adds its `raycast_mask` to its own `collision_layer`. Keep this in mind if you are sharing physics layers with other logic in your scene.

---

## 🤝 Contributing

Found a bug? Have an idea for an improvement? Pull requests and issues are highly welcome!

If you use this plugin in your game, please let me know—I'd love to see what you cook up! 🍳

---

## 📜 License

MIT License. Feel free to use this in your commercial or non-commercial projects.
