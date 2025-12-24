extends Control
class_name MCSView

## MCS Visual Colony Renderer - Isometric 2.5D
## Unified coordinate system: everything goes through _iso_transform()
## Ground is a diamond, buildings are hex prisms with height

const _MCSTypes = preload("res://scripts/mars_colony_sim/mcs_types.gd")

# =============================================================================
# ISOMETRIC CONFIGURATION
# =============================================================================

# The ground plane is a square in world space, viewed at 30° isometric angle
# World coords: (0,0) to (WORLD_SIZE, WORLD_SIZE), height Z goes up
const WORLD_SIZE = 400.0
const WORLD_CENTER_X = 200.0
const WORLD_CENTER_Y = 200.0

# Isometric projection matrix components
# Standard 2:1 isometric: for every 2 pixels horizontal, 1 pixel vertical
const ISO_TILE_WIDTH = 2.0    # How wide a 1x1 world tile appears
const ISO_TILE_HEIGHT = 1.0   # How tall a 1x1 world tile appears (depth)
const ISO_HEIGHT_SCALE = 2.5  # How much Z height translates to screen Y (taller = more dramatic)

# Visual sizes in world units
const LIFEPOD_RADIUS = 20.0
const BUILDING_RADIUS = 28.0  # MASSIVE footprint for EPIC scale
const COLONIST_SIZE = 2.5

# =============================================================================
# PERSPECTIVE SYSTEM
# =============================================================================
# One-point perspective: buildings spread from foreground toward horizon
# Depth = distance into scene, Lateral = left/right from center

const PERSPECTIVE_ENABLED = true  # Toggle for A/B testing

# Screen space ratios (0.0 = top, 1.0 = bottom)
const HORIZON_SCREEN_Y = 0.38       # Horizon line at 38% from top
const FOREGROUND_SCREEN_Y = 0.95    # Foreground ground at 95%

# World space bounds for perspective layout
const MAX_DEPTH = 80.0              # Distance from front to horizon
const MAX_LATERAL = 14.0            # Left/right spread - TIGHT for dense city
const MIN_DEPTH = 6.0               # Closest buildings to camera - CLOSE!

# Perspective scaling - EPIC scale for massive structures
const PERSPECTIVE_BASE_SCALE = 65.0  # Base pixel scale at depth=0 (bigger = larger buildings)
const PERSPECTIVE_STRENGTH = 0.85    # How aggressively things shrink (lower = less shrinking)
const PERSPECTIVE_HEIGHT_SCALE = 6.5 # Vertical exaggeration for buildings (MASSIVE!)

# Row layout for perspective view - TIGHT clustering for dense city feel
const PERSPECTIVE_ROWS = [
	{"depth": 0.05, "slots": 4, "spread": 0.22},   # Foreground: prominent buildings (tight!)
	{"depth": 0.11, "slots": 6, "spread": 0.28},
	{"depth": 0.17, "slots": 8, "spread": 0.34},
	{"depth": 0.24, "slots": 10, "spread": 0.38},
	{"depth": 0.31, "slots": 12, "spread": 0.42},
	{"depth": 0.38, "slots": 14, "spread": 0.46},
	{"depth": 0.46, "slots": 16, "spread": 0.50},
	{"depth": 0.54, "slots": 18, "spread": 0.54},
	{"depth": 0.64, "slots": 22, "spread": 0.58},
	{"depth": 0.76, "slots": 28, "spread": 0.65},  # Background silhouettes
]

# =============================================================================
# BUILDING HEIGHTS (world units) - Scale with colony tier
# =============================================================================

const BUILDING_HEIGHTS = {
	# DRAMATIC heights for epic Martian skyline!
	# At Year 73, colony should have impressive skyscrapers
	# These heights are further scaled by tier (up to 5x) and colony age

	# Housing - starts modest, becomes impressive towers
	"hab_pod": 15.0,          # Tier 1: dome -> Tier 5: residential tower
	"apartment_block": 40.0,  # High-rise apartments dominate skyline
	"luxury_quarters": 35.0,  # Elegant penthouse towers
	"barracks": 12.0,

	# Food production - pyramids and vertical farms
	"greenhouse": 25.0,       # Tier 1: low pyramid -> Tier 5: towering vertical farm
	"hydroponics": 30.0,      # Tall hydroponic towers

	# Power - industrial spires
	"solar_array": 8.0,       # Elevated arrays at higher tiers
	"fission_reactor": 25.0,  # Cooling towers reach skyward

	# Industry - factory complexes
	"water_extractor": 20.0,  # Tall drilling rigs
	"oxygenator": 15.0,
	"workshop": 25.0,         # Industrial towers
	"factory": 35.0,          # Massive factory complexes
	"storage": 20.0,

	# Services - civic towers
	"medical_bay": 20.0,      # Medical tower
	"hospital": 40.0,         # Hospital complex reaches sky
	"school": 18.0,
	"university": 35.0,       # Campus tower
	"lab": 25.0,
	"research_center": 45.0,  # Science spire
	"recreation_center": 20.0,
	"temple": 30.0,           # Soaring temple spire
	"government_hall": 45.0,  # Government tower dominates

	# Mega-structures - the SKYLINE MAKERS
	"arcology": 120.0,        # Massive curved mega-tower
	"mega_tower": 100.0,      # Iconic skyscraper
	"admin_spire": 80.0,      # Tall administrative spire

	# Superstructures (special - always epic)
	"space_elevator": 800.0,  # Goes to orbit - beyond sky!
	"orbital_tether": 600.0,
	"mass_driver": 25.0,      # Rail with tall gantries
	"skyhook": 50.0,          # Anchor structure for rotating tether
}

# Colony era multipliers (affects all buildings slightly)
const TIER_MULTIPLIERS = {
	"survival": 0.9,
	"growth": 1.0,
	"society": 1.1,
	"independence": 1.2,
	"transcendence": 1.3,
}

# =============================================================================
# BUILDING UPGRADE PATHS - Visual progression for each building type
# =============================================================================
# Each building type has 5 visual tiers that show growth and advancement
# Tier 1: Emergency/basic survival structure
# Tier 2: Functional improvement
# Tier 3: Expanded/upgraded
# Tier 4: Advanced/optimized
# Tier 5: Megastructure-level (fully realized)

const UPGRADE_PATHS = {
	# -------------------------------------------------------------------------
	# POWER STRUCTURES
	# -------------------------------------------------------------------------
	"solar_array": {
		1: {"name": "Emergency Panel", "desc": "Single panel on ground", "panels": 1, "elevated": false, "rotating": false, "stacked": false},
		2: {"name": "Panel Array", "desc": "Row of 3 panels", "panels": 3, "elevated": false, "rotating": false, "stacked": false},
		3: {"name": "Elevated Array", "desc": "Raised on support poles", "panels": 4, "elevated": true, "rotating": false, "stacked": false},
		4: {"name": "Tracking Array", "desc": "Sun-tracking mount", "panels": 5, "elevated": true, "rotating": true, "stacked": false},
		5: {"name": "Solar Tower", "desc": "Multi-level solar farm", "panels": 8, "elevated": true, "rotating": true, "stacked": true},
	},
	"fission_reactor": {
		1: {"name": "RTG Pod", "desc": "Basic radioisotope generator", "cooling_towers": 0, "glow": 0.3},
		2: {"name": "Enhanced RTG", "desc": "Improved output", "cooling_towers": 0, "glow": 0.5},
		3: {"name": "Small Reactor", "desc": "Nuclear fission core", "cooling_towers": 1, "glow": 0.7},
		4: {"name": "Power Plant", "desc": "Full reactor complex", "cooling_towers": 2, "glow": 0.85},
		5: {"name": "Reactor Array", "desc": "Multiple reactor cores", "cooling_towers": 3, "glow": 1.0},
	},
	"fusion_reactor": {
		1: {"name": "Prototype Core", "desc": "Experimental fusion", "rings": 1, "plasma_glow": 0.4},
		2: {"name": "Stable Core", "desc": "Reliable output", "rings": 2, "plasma_glow": 0.6},
		3: {"name": "Enhanced Core", "desc": "High efficiency", "rings": 3, "plasma_glow": 0.75},
		4: {"name": "Fusion Complex", "desc": "Multi-core plant", "rings": 4, "plasma_glow": 0.9},
		5: {"name": "Fusion Megaplex", "desc": "Powers the colony", "rings": 5, "plasma_glow": 1.0},
	},
	# -------------------------------------------------------------------------
	# HOUSING
	# -------------------------------------------------------------------------
	"hab_pod": {
		1: {"name": "Emergency Shelter", "desc": "Pressurized bunker", "domes": 1, "windows": 0, "height_mult": 0.6},
		2: {"name": "Basic Hab", "desc": "Small dome with airlock", "domes": 1, "windows": 2, "height_mult": 0.8},
		3: {"name": "Expanded Hab", "desc": "Larger living space", "domes": 1, "windows": 4, "height_mult": 1.0},
		4: {"name": "Hab Complex", "desc": "Connected modules", "domes": 2, "windows": 6, "height_mult": 1.3},
		5: {"name": "Hab Tower", "desc": "Multi-story housing", "domes": 3, "windows": 10, "height_mult": 2.0},
	},
	"apartment_block": {
		1: {"name": "Crew Quarters", "desc": "Basic shared housing", "floors": 2, "balconies": false},
		2: {"name": "Apartment Unit", "desc": "Private apartments", "floors": 3, "balconies": false},
		3: {"name": "Apartment Block", "desc": "Family housing", "floors": 5, "balconies": true},
		4: {"name": "High-Rise", "desc": "Tall residential tower", "floors": 8, "balconies": true},
		5: {"name": "Sky Apartments", "desc": "Luxury tower", "floors": 12, "balconies": true},
	},
	# -------------------------------------------------------------------------
	# FOOD PRODUCTION
	# -------------------------------------------------------------------------
	"greenhouse": {
		1: {"name": "Grow Tent", "desc": "Emergency hydroponics", "sections": 1, "opacity": 0.6, "crops_visible": false},
		2: {"name": "Small Greenhouse", "desc": "Basic growing dome", "sections": 1, "opacity": 0.5, "crops_visible": true},
		3: {"name": "Greenhouse", "desc": "Full production dome", "sections": 2, "opacity": 0.4, "crops_visible": true},
		4: {"name": "Agri-Complex", "desc": "Multiple growing areas", "sections": 3, "opacity": 0.35, "crops_visible": true},
		5: {"name": "Vertical Farm", "desc": "Multi-level agriculture", "sections": 4, "opacity": 0.3, "crops_visible": true},
	},
	"hydroponics": {
		1: {"name": "Hydro Pod", "desc": "Small water system", "tanks": 1, "pipes_visible": false},
		2: {"name": "Hydro Array", "desc": "Expanded growing", "tanks": 2, "pipes_visible": true},
		3: {"name": "Hydro Bay", "desc": "Full bay system", "tanks": 3, "pipes_visible": true},
		4: {"name": "Hydro Tower", "desc": "Vertical hydroponics", "tanks": 4, "pipes_visible": true},
		5: {"name": "Hydro Megafarm", "desc": "Industrial scale", "tanks": 6, "pipes_visible": true},
	},
	# -------------------------------------------------------------------------
	# WATER & LIFE SUPPORT
	# -------------------------------------------------------------------------
	"water_extractor": {
		1: {"name": "Ice Drill", "desc": "Basic extraction", "drills": 1, "tank_size": 0.5, "pipes": false},
		2: {"name": "Deep Well", "desc": "Deeper access", "drills": 1, "tank_size": 0.7, "pipes": true},
		3: {"name": "Extraction Rig", "desc": "Multiple wells", "drills": 2, "tank_size": 1.0, "pipes": true},
		4: {"name": "Water Plant", "desc": "Processing facility", "drills": 3, "tank_size": 1.3, "pipes": true},
		5: {"name": "Water Tower", "desc": "Full distribution", "drills": 4, "tank_size": 2.0, "pipes": true},
	},
	"oxygenator": {
		1: {"name": "O2 Generator", "desc": "Basic oxygen", "vents": 1, "flow_rate": 0.5},
		2: {"name": "O2 Array", "desc": "Improved output", "vents": 2, "flow_rate": 0.7},
		3: {"name": "O2 Plant", "desc": "Life support hub", "vents": 3, "flow_rate": 1.0},
		4: {"name": "Atmo Processor", "desc": "Air recycling", "vents": 4, "flow_rate": 1.3},
		5: {"name": "Atmo Tower", "desc": "Colony-wide air", "vents": 6, "flow_rate": 2.0},
	},
	# -------------------------------------------------------------------------
	# INDUSTRY
	# -------------------------------------------------------------------------
	"workshop": {
		1: {"name": "Tool Shed", "desc": "Basic repairs", "workstations": 1, "chimneys": 0},
		2: {"name": "Workshop", "desc": "General fabrication", "workstations": 2, "chimneys": 0},
		3: {"name": "Machine Shop", "desc": "Precision manufacturing", "workstations": 3, "chimneys": 1},
		4: {"name": "Fab Lab", "desc": "Advanced manufacturing", "workstations": 4, "chimneys": 1},
		5: {"name": "Factory", "desc": "Industrial production", "workstations": 6, "chimneys": 2},
	},
	"factory": {
		1: {"name": "Small Factory", "desc": "Basic production", "smokestacks": 1, "cranes": 0},
		2: {"name": "Factory", "desc": "Standard output", "smokestacks": 1, "cranes": 1},
		3: {"name": "Industrial Plant", "desc": "High output", "smokestacks": 2, "cranes": 1},
		4: {"name": "Manufacturing Hub", "desc": "Automation", "smokestacks": 2, "cranes": 2},
		5: {"name": "Mega-Factory", "desc": "Full automation", "smokestacks": 3, "cranes": 3},
	},
	"storage": {
		1: {"name": "Supply Cache", "desc": "Small storage", "tanks": 1, "height_mult": 0.6},
		2: {"name": "Warehouse", "desc": "General storage", "tanks": 2, "height_mult": 0.8},
		3: {"name": "Storage Hub", "desc": "Central storage", "tanks": 3, "height_mult": 1.0},
		4: {"name": "Distribution Center", "desc": "Logistics hub", "tanks": 4, "height_mult": 1.3},
		5: {"name": "Storage Complex", "desc": "Massive capacity", "tanks": 6, "height_mult": 1.8},
	},
	# -------------------------------------------------------------------------
	# MEDICAL & SERVICES
	# -------------------------------------------------------------------------
	"medical_bay": {
		1: {"name": "First Aid Station", "desc": "Emergency care", "beds": 2, "red_cross": true},
		2: {"name": "Medical Bay", "desc": "Basic treatment", "beds": 4, "red_cross": true},
		3: {"name": "Clinic", "desc": "Full medical", "beds": 6, "red_cross": true},
		4: {"name": "Med Center", "desc": "Advanced care", "beds": 8, "red_cross": true},
		5: {"name": "Hospital", "desc": "Complete hospital", "beds": 12, "red_cross": true},
	},
	"school": {
		1: {"name": "Learning Pod", "desc": "Basic education", "floors": 1, "windows": 2},
		2: {"name": "School Room", "desc": "Class education", "floors": 1, "windows": 4},
		3: {"name": "School", "desc": "Full curriculum", "floors": 2, "windows": 6},
		4: {"name": "Academy", "desc": "Advanced education", "floors": 3, "windows": 8},
		5: {"name": "University", "desc": "Higher learning", "floors": 4, "windows": 12},
	},
	"lab": {
		1: {"name": "Research Pod", "desc": "Basic experiments", "antennas": 1, "glow": 0.3},
		2: {"name": "Lab", "desc": "Science lab", "antennas": 2, "glow": 0.5},
		3: {"name": "Research Lab", "desc": "Advanced research", "antennas": 3, "glow": 0.7},
		4: {"name": "Science Center", "desc": "Multi-discipline", "antennas": 4, "glow": 0.85},
		5: {"name": "Research Complex", "desc": "Cutting edge", "antennas": 6, "glow": 1.0},
	},
	# -------------------------------------------------------------------------
	# INFRASTRUCTURE
	# -------------------------------------------------------------------------
	"communications": {
		1: {"name": "Radio Mast", "desc": "Basic comms", "dishes": 0, "antenna_height": 0.8},
		2: {"name": "Comms Tower", "desc": "Enhanced range", "dishes": 1, "antenna_height": 1.0},
		3: {"name": "Relay Station", "desc": "Network node", "dishes": 2, "antenna_height": 1.3},
		4: {"name": "Comms Array", "desc": "Multi-band", "dishes": 3, "antenna_height": 1.6},
		5: {"name": "Deep Space Array", "desc": "Interplanetary", "dishes": 4, "antenna_height": 2.0},
	},
	"landing_pad": {
		1: {"name": "Marked Area", "desc": "Basic landing zone", "lights": 2, "has_tower": false},
		2: {"name": "Landing Pad", "desc": "Prepared surface", "lights": 4, "has_tower": false},
		3: {"name": "Spaceport Pad", "desc": "Refueling capable", "lights": 6, "has_tower": true},
		4: {"name": "Launch Complex", "desc": "Full facilities", "lights": 8, "has_tower": true},
		5: {"name": "Spaceport", "desc": "Major hub", "lights": 12, "has_tower": true},
	},
	# -------------------------------------------------------------------------
	# MEGASTRUCTURES (special - always impressive)
	# -------------------------------------------------------------------------
	"space_elevator": {
		1: {"name": "Anchor Point", "desc": "Base construction", "cable_opacity": 0.3, "platforms": 1},
		2: {"name": "Partial Tether", "desc": "Cable rising", "cable_opacity": 0.5, "platforms": 1},
		3: {"name": "Basic Elevator", "desc": "First cargo runs", "cable_opacity": 0.7, "platforms": 2},
		4: {"name": "Space Elevator", "desc": "Regular service", "cable_opacity": 0.85, "platforms": 3},
		5: {"name": "Orbital Gateway", "desc": "Major transit hub", "cable_opacity": 1.0, "platforms": 4},
	},
	"mass_driver": {
		1: {"name": "Launch Ramp", "desc": "Basic accelerator", "rail_length": 0.5, "power_glow": 0.3},
		2: {"name": "Mass Driver", "desc": "Functional launcher", "rail_length": 0.7, "power_glow": 0.5},
		3: {"name": "Cargo Launcher", "desc": "Regular launches", "rail_length": 0.85, "power_glow": 0.7},
		4: {"name": "Mass Driver Array", "desc": "High capacity", "rail_length": 1.0, "power_glow": 0.85},
		5: {"name": "Orbital Cannon", "desc": "Continuous ops", "rail_length": 1.2, "power_glow": 1.0},
	},
	"skyhook": {
		1: {"name": "Tether Anchor", "desc": "Ground anchor deployed", "rotation_speed": 0.0, "tether_length": 0.3, "counterweight": false},
		2: {"name": "Short Tether", "desc": "Initial rotation", "rotation_speed": 0.2, "tether_length": 0.5, "counterweight": false},
		3: {"name": "Operational Skyhook", "desc": "Catching payloads", "rotation_speed": 0.4, "tether_length": 0.7, "counterweight": true},
		4: {"name": "High-Capacity Tether", "desc": "Passenger service", "rotation_speed": 0.5, "tether_length": 0.85, "counterweight": true},
		5: {"name": "Interplanetary Gateway", "desc": "Mars-Earth transfers", "rotation_speed": 0.6, "tether_length": 1.0, "counterweight": true},
	},
}

# =============================================================================
# COLORS
# =============================================================================

const COLOR_SKY = Color(0.75, 0.50, 0.42)
const COLOR_GROUND_LIGHT = Color(0.58, 0.30, 0.20)
const COLOR_GROUND_DARK = Color(0.45, 0.22, 0.14)
const COLOR_GROUND_EDGE = Color(0.35, 0.16, 0.10)
const COLOR_SHADOW = Color(0.0, 0.0, 0.0, 0.3)

const COLOR_LIFEPOD_TOP = Color(0.4, 0.6, 0.8)
const COLOR_LIFEPOD_LEFT = Color(0.25, 0.42, 0.58)
const COLOR_LIFEPOD_RIGHT = Color(0.32, 0.50, 0.68)

const COLOR_TUNNEL = Color(0.2, 0.15, 0.12)
const COLOR_TUNNEL_GLOW = Color(1.0, 0.8, 0.5, 0.5)

# Warm futuristic palette inspired by concept art - metallic with golden highlights
const BUILDING_COLORS = {
	"housing": {"top": Color(0.78, 0.72, 0.68), "left": Color(0.55, 0.50, 0.46), "right": Color(0.68, 0.62, 0.58)},  # Warm metallic
	"food": {"top": Color(0.45, 0.65, 0.42), "left": Color(0.32, 0.48, 0.30), "right": Color(0.38, 0.55, 0.36)},  # Muted green
	"power": {"top": Color(0.95, 0.82, 0.55), "left": Color(0.78, 0.65, 0.42), "right": Color(0.88, 0.75, 0.50)},  # Golden
	"water": {"top": Color(0.55, 0.72, 0.82), "left": Color(0.42, 0.55, 0.65), "right": Color(0.48, 0.65, 0.75)},  # Steel blue
	"industry": {"top": Color(0.72, 0.62, 0.52), "left": Color(0.52, 0.42, 0.32), "right": Color(0.62, 0.52, 0.42)},  # Bronze
	"medical": {"top": Color(0.85, 0.75, 0.72), "left": Color(0.65, 0.55, 0.52), "right": Color(0.75, 0.65, 0.62)},  # Warm white/pink
	"research": {"top": Color(0.72, 0.68, 0.78), "left": Color(0.52, 0.48, 0.58), "right": Color(0.62, 0.58, 0.68)},  # Soft purple-gray
	"mega": {"top": Color(0.95, 0.92, 0.88), "left": Color(0.72, 0.68, 0.65), "right": Color(0.85, 0.82, 0.78)},  # Bright silver
}

# =============================================================================
# STATE
# =============================================================================

var _buildings: Array = []
var _colonists: Array = []
var _year: int = 1
var _stability: float = 1.0
var _colony_tier: String = "survival"

var _time: float = 0.0
var _camera_zoom: float = 1.0
var _camera_pan: Vector2 = Vector2.ZERO
var _time_scale: float = 1.0  # Synced with game speed for animations

# Cached building layout: id -> {world_x, world_y, height, category}
var _building_layout: Dictionary = {}

var _dust_particles: Array = []
var _sandstorm_active: bool = false
var _sandstorm_intensity: float = 0.0
var _force_field_active: bool = false
var _force_field_strength: float = 1.0

# =============================================================================
# CORE ISOMETRIC TRANSFORM
# =============================================================================

func _iso_transform(world_x: float, world_y: float, world_z: float = 0.0) -> Vector2:
	"""
	THE core transform. All world coordinates go through here.
	World: X+ is east, Y+ is south, Z+ is up
	Screen: Standard 2:1 isometric projection
	"""
	# Offset from world center
	var dx = world_x - WORLD_CENTER_X
	var dy = world_y - WORLD_CENTER_Y

	# Isometric projection (2:1 ratio)
	var screen_x = (dx - dy) * ISO_TILE_WIDTH
	var screen_y = (dx + dy) * ISO_TILE_HEIGHT - world_z * ISO_HEIGHT_SCALE

	# Apply camera zoom and pan, center on control
	var result = Vector2(screen_x, screen_y)
	result = result * _camera_zoom + _camera_pan
	result += size / 2

	return result

func _iso_v2(pos: Vector2, z: float = 0.0) -> Vector2:
	"""Convenience for Vector2 + height"""
	return _iso_transform(pos.x, pos.y, z)

func _get_depth(world_x: float, world_y: float, world_z: float = 0.0) -> float:
	"""Depth for sorting: higher = draw first (further from camera)"""
	# In isometric, things with larger X+Y are further back
	# Higher Z should be drawn later (on top)
	return -(world_x + world_y) + world_z * 0.01

# =============================================================================
# PERSPECTIVE TRANSFORM SYSTEM
# =============================================================================

func _get_vanishing_point() -> Vector2:
	"""The point on horizon where all perspective lines converge"""
	return Vector2(size.x * 0.5, size.y * HORIZON_SCREEN_Y)

func _perspective_transform(world_x: float, world_depth: float, world_z: float = 0.0) -> Vector2:
	"""
	One-point perspective transform.
	world_x: lateral position (negative = left, positive = right, 0 = center)
	world_depth: distance into scene (0 = foreground, MAX_DEPTH = horizon)
	world_z: height above ground
	"""
	var vp = _get_vanishing_point()

	# Normalize depth (0 = closest, 1 = horizon)
	var depth_norm = clampf(world_depth / MAX_DEPTH, 0.0, 1.0)

	# Perspective scale: things shrink as they approach horizon
	# Use exponential falloff for more realistic perspective
	var scale = PERSPECTIVE_BASE_SCALE / (1.0 + depth_norm * PERSPECTIVE_STRENGTH)

	# Screen Y: interpolate from foreground ground toward horizon
	var ground_y = size.y * FOREGROUND_SCREEN_Y
	var horizon_y = size.y * HORIZON_SCREEN_Y
	# Ease-out curve so distant objects cluster near horizon
	var y_ratio = 1.0 - pow(1.0 - depth_norm, 1.5)
	var base_screen_y = lerp(ground_y, horizon_y, y_ratio)

	# Apply height (scaled by perspective - taller things remain visible)
	var height_offset = world_z * scale * PERSPECTIVE_HEIGHT_SCALE / PERSPECTIVE_BASE_SCALE
	var screen_y = base_screen_y - height_offset

	# Screen X: spread from vanishing point center, scaled by perspective
	var screen_x = vp.x + world_x * scale

	# Apply camera zoom and pan
	var result = Vector2(screen_x, screen_y)
	result = (result - size / 2) * _camera_zoom + size / 2 + _camera_pan

	return result

func _perspective_v2(lateral: float, depth: float, z: float = 0.0) -> Vector2:
	"""Convenience wrapper for perspective transform"""
	return _perspective_transform(lateral, depth, z)

func _get_perspective_scale(world_depth: float) -> float:
	"""Get the scale factor at a given depth (for sizing elements)"""
	var depth_norm = clampf(world_depth / MAX_DEPTH, 0.0, 1.0)
	# Minimum scale of 40% to keep back buildings visible
	var raw_scale = PERSPECTIVE_BASE_SCALE / (1.0 + depth_norm * PERSPECTIVE_STRENGTH)
	return maxf(raw_scale, PERSPECTIVE_BASE_SCALE * 0.4)

func _get_depth_perspective(world_depth: float, world_z: float = 0.0) -> float:
	"""Depth sorting for perspective: higher depth = draw first (background)"""
	# Objects further into scene draw first, height breaks ties
	return world_depth - world_z * 0.001

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready():
	clip_contents = true  # IMPORTANT: Clip to our bounds
	for i in range(30):
		_dust_particles.append({
			"x": randf() * WORLD_SIZE,
			"y": randf() * WORLD_SIZE,
			"z": randf() * 15.0,
			"vx": randf_range(-8, 8),
			"vy": randf_range(-4, 4),
			"vz": randf_range(-1, 1),
			"size": randf_range(1.5, 3.5),
			"alpha": randf_range(0.15, 0.35)
		})

func _process(delta: float):
	# Scale animation time with game speed (capped for sanity)
	var anim_scale = clampf(_time_scale / 30.0, 0.5, 4.0)
	_time += delta * anim_scale
	_update_dust(delta * anim_scale)
	_update_transport_animations(delta * anim_scale)
	queue_redraw()

func _update_transport_animations(delta: float):
	"""Update mass driver launch and skyhook rotation animations"""
	var mass_driver_tier = _get_building_max_tier(_MCSTypes.BuildingType.MASS_DRIVER)
	var skyhook_tier = _get_building_max_tier(_MCSTypes.BuildingType.SKYHOOK)

	# Mass driver launch cycle (every 5 seconds at tier 5, slower at lower tiers)
	if mass_driver_tier > 0:
		var launch_interval = 8.0 - mass_driver_tier  # 7s at T1, 3s at T5
		_mass_driver_launch_timer += delta
		if _mass_driver_launch_timer >= launch_interval:
			_mass_driver_launch_timer = 0.0
			_mass_driver_projectile_t = 0.0
		# Advance projectile if in flight
		if _mass_driver_projectile_t >= 0:
			_mass_driver_projectile_t += delta * 0.5  # 2 seconds flight time
			if _mass_driver_projectile_t > 1.0:
				_mass_driver_projectile_t = -1.0  # Done

	# Skyhook rotation
	if skyhook_tier > 0:
		var rotation_speed = 0.1 + skyhook_tier * 0.1  # 0.2-0.6 based on tier
		_skyhook_rotation += delta * rotation_speed
		if _skyhook_rotation > TAU:
			_skyhook_rotation -= TAU

		# Catch/release flash timer (every 8 seconds)
		_skyhook_catch_timer += delta
		if _skyhook_catch_timer >= 8.0:
			_skyhook_catch_timer = 0.0

	# === LANDING SHIPS ===
	var starport_tier = _get_building_max_tier(_MCSTypes.BuildingType.STARPORT)
	if starport_tier > 0:
		# Spawn new landing ships periodically
		_landing_ship_spawn_timer += delta
		var spawn_interval = 12.0 - starport_tier * 2.0  # 10s at T1, 2s at T5
		if _landing_ship_spawn_timer >= spawn_interval:
			_landing_ship_spawn_timer = 0.0
			# Spawn a new landing/takeoff ship
			var is_landing = randf() > 0.4  # 60% landing, 40% takeoff
			_landing_ships.append({
				"x": randf_range(0.3, 0.7),  # Screen X ratio
				"y": 0.0 if is_landing else 1.0,  # Start from top (landing) or ground (takeoff)
				"phase": "landing" if is_landing else "takeoff",
				"type": ["shuttle", "freighter", "passenger"][randi() % 3],
				"timer": 0.0
			})

		# Update existing landing ships
		var new_landing_ships: Array = []
		for ship in _landing_ships:
			ship.timer += delta
			var duration = 4.0 if ship.type == "shuttle" else 6.0
			var progress = ship.timer / duration
			if ship.phase == "landing":
				ship.y = progress
			else:  # takeoff
				ship.y = 1.0 - progress
			if progress < 1.0:
				new_landing_ships.append(ship)
		_landing_ships = new_landing_ships

	# === ORBITAL SHIPS ===
	# Initialize orbital ships if empty and we have starport
	if _orbital_ships.is_empty() and starport_tier > 0:
		for i in range(2 + starport_tier):  # 3-7 orbital ships
			_orbital_ships.append({
				"orbit_t": randf() * TAU,
				"orbit_r": 100 + randf() * 80,  # Orbit radius
				"orbit_speed": 0.05 + randf() * 0.1,
				"size": 8 + randf() * 12,  # Ship size
				"type": ["freighter", "liner", "cruiser"][randi() % 3]
			})

	# Update orbital ships
	for ship in _orbital_ships:
		ship.orbit_t += delta * ship.orbit_speed

	# === CITY SPOTLIGHTS ===
	for i in range(_spotlight_angles.size()):
		_spotlight_angles[i] += delta * (0.3 + i * 0.1)  # Different rotation speeds
		if _spotlight_angles[i] > TAU:
			_spotlight_angles[i] -= TAU

func _draw():
	# Background sky with atmospheric gradient
	_draw_sky()

	# Orbital elements (behind everything)
	_draw_orbital_elements()

	# Draw isometric ground diamond
	_draw_ground()

	# Collect and sort all objects
	var objects = _collect_all_objects()
	objects.sort_custom(func(a, b): return a.depth > b.depth)

	# Draw in order
	for obj in objects:
		match obj.type:
			"tunnel": _draw_tunnel_obj(obj)
			"shadow": _draw_shadow_obj(obj)
			"building": _draw_building_obj(obj)
			"lifepod": _draw_lifepod_obj(obj)
			"colonist": _draw_colonist_obj(obj)
			"drone": _draw_drone_obj(obj)

	# Communication dishes on COMMS buildings
	_draw_comms_dishes()

	# Force field dome over colony
	_draw_force_field()

	# Energy beams between major structures
	_draw_energy_network()

	# Elevated transit system (monorail)
	_draw_transit_system()

	# City spotlights (on tall buildings)
	_draw_city_spotlights()

	# Ships landing/taking off
	_draw_landing_ships()

	# Dust on top
	_draw_dust()

	# Atmospheric effects
	_draw_atmosphere_effects()

# =============================================================================
# SKY AND ATMOSPHERE
# =============================================================================

func _draw_sky():
	"""Draw Mars sky with horizon, distant mountains, and celestial bodies"""
	var sky_palette = TERRAFORM_SKY_COLORS[_terraforming_stage]
	var horizon_color = sky_palette.horizon
	var zenith_color = sky_palette.zenith
	var ground_colors = TERRAFORM_GROUND_COLORS[_terraforming_stage]

	# Horizon position depends on perspective mode
	var horizon_ratio = HORIZON_SCREEN_Y if PERSPECTIVE_ENABLED else 0.5
	var horizon_y = size.y * horizon_ratio

	# Sky gradient - from top to horizon
	var bands = 12
	for i in range(bands):
		var t1 = float(i) / bands
		var t2 = float(i + 1) / bands
		var c1 = zenith_color.lerp(horizon_color, t1)
		var c2 = zenith_color.lerp(horizon_color, t2)
		var y1 = horizon_y * t1
		var y2 = horizon_y * t2
		draw_rect(Rect2(0, y1, size.x, y2 - y1), c1.lerp(c2, 0.5))

	# Distant mountains silhouette (far background)
	_draw_distant_mountains(horizon_y, ground_colors.dark.darkened(0.3))

	# Mid-ground terrain (closer hills)
	_draw_midground_terrain(horizon_y, ground_colors.dark.darkened(0.15))

	# Ground plane (fades from horizon)
	_draw_ground_plane(horizon_y, ground_colors)

	# Earth - dramatic large celestial body on horizon (like in Stockcake reference)
	# Visible as a blue-green jewel, reminder of home
	var earth_phase = fmod(_time * 0.02, 1.0)  # Very slow movement
	var earth_x = size.x * 0.75
	var earth_y = size.y * (0.12 + sin(earth_phase * PI * 2) * 0.03)
	var earth_size = 35.0  # Dramatic size

	# Earth glow (atmosphere)
	draw_circle(Vector2(earth_x, earth_y), earth_size * 1.15, Color(0.4, 0.6, 0.8, 0.15))
	# Earth body
	draw_circle(Vector2(earth_x, earth_y), earth_size, Color(0.25, 0.45, 0.65))
	# Continents hint (lighter patches)
	draw_circle(Vector2(earth_x - 8, earth_y - 5), earth_size * 0.3, Color(0.35, 0.55, 0.45, 0.6))
	draw_circle(Vector2(earth_x + 10, earth_y + 3), earth_size * 0.25, Color(0.35, 0.55, 0.45, 0.5))
	# Polar ice cap
	draw_circle(Vector2(earth_x, earth_y - earth_size * 0.7), earth_size * 0.25, Color(0.85, 0.9, 0.95, 0.7))
	# Specular highlight
	draw_circle(Vector2(earth_x - earth_size * 0.3, earth_y - earth_size * 0.3),
		earth_size * 0.2, Color(1.0, 1.0, 1.0, 0.25))

	# Moon visible near Earth (tiny companion)
	var luna_offset = Vector2(earth_size * 1.8, sin(_time * 0.1) * 10)
	draw_circle(Vector2(earth_x, earth_y) + luna_offset, 6, Color(0.75, 0.73, 0.7))

	# Phobos (Mars moon - irregular, potato-shaped, fast orbit)
	var phobos_t = fmod(_time * 0.25, 1.0)
	var phobos_x = size.x * (0.05 + phobos_t * 0.9)
	var phobos_y = size.y * (0.08 + sin(phobos_t * PI) * 0.12)
	# Irregular shape (elongated)
	var phobos_color = Color(0.55, 0.50, 0.45)
	draw_rect(Rect2(phobos_x - 6, phobos_y - 3, 12, 6), phobos_color)
	draw_circle(Vector2(phobos_x - 5, phobos_y), 4, phobos_color)
	draw_circle(Vector2(phobos_x + 5, phobos_y), 3.5, phobos_color)

	# Deimos (smaller, slower, more distant)
	var deimos_t = fmod(_time * 0.12, 1.0)
	var deimos_x = size.x * (0.95 - deimos_t * 0.85)
	var deimos_y = size.y * (0.18 + sin(deimos_t * PI) * 0.06)
	draw_circle(Vector2(deimos_x, deimos_y), 4, Color(0.6, 0.55, 0.5))
	draw_circle(Vector2(deimos_x + 1.5, deimos_y - 1), 2.5, Color(0.55, 0.50, 0.45))

	# Stars (visible during dust-free moments) - more stars, varied sizes
	if not _sandstorm_active:
		for i in range(40):
			var sx = fmod(i * 137.5 + 50, size.x)
			var sy = fmod(i * 89.3 + 20, size.y * 0.35)
			var star_size = 0.8 + fmod(i * 0.3, 1.2)
			var twinkle = 0.15 + sin(_time * 2.5 + i * 0.7) * 0.2
			# Slight color variation
			var star_color = Color(1.0, 1.0, 0.95, twinkle)
			if i % 5 == 0:
				star_color = Color(0.9, 0.95, 1.0, twinkle)  # Blue-ish
			elif i % 7 == 0:
				star_color = Color(1.0, 0.92, 0.85, twinkle)  # Orange-ish
			draw_circle(Vector2(sx, sy), star_size, star_color)

func _draw_distant_mountains(horizon_y: float, color: Color):
	"""Draw layered mountain ranges for cinematic depth"""
	var sky_palette = TERRAFORM_SKY_COLORS[_terraforming_stage]

	# Layer 1: Most distant - barely visible, blends with horizon
	var far_color = color.lerp(sky_palette.horizon, 0.7)
	var far_points = PackedVector2Array()
	far_points.append(Vector2(0, horizon_y + 30))
	for i in range(17):
		var x = size.x * i / 16
		var peak_h = 45 + sin(i * 0.6) * 30 + sin(i * 2.1) * 12
		far_points.append(Vector2(x, horizon_y - peak_h))
	far_points.append(Vector2(size.x, horizon_y + 30))
	draw_polygon(far_points, [far_color])

	# Layer 2: Mid-distance mountains
	var mid_color = color.lerp(sky_palette.horizon, 0.4)
	var mid_points = PackedVector2Array()
	mid_points.append(Vector2(0, horizon_y + 25))
	for i in range(13):
		var x = size.x * i / 12
		var peak_h = 35 + sin(i * 0.8 + 1.0) * 25 + sin(i * 1.7) * 15 + sin(i * 0.4) * 18
		mid_points.append(Vector2(x, horizon_y - peak_h))
	mid_points.append(Vector2(size.x, horizon_y + 25))
	draw_polygon(mid_points, [mid_color])

	# Layer 3: Foreground mountains - more detail and contrast
	var near_color = color.lerp(sky_palette.horizon, 0.15)
	var near_points = PackedVector2Array()
	near_points.append(Vector2(0, horizon_y + 20))
	for i in range(10):
		var x = size.x * i / 9
		var peak_h = 25 + sin(i * 1.1 + 2.0) * 20 + sin(i * 2.3) * 12
		near_points.append(Vector2(x, horizon_y - peak_h))
	near_points.append(Vector2(size.x, horizon_y + 20))
	draw_polygon(near_points, [near_color])

func _draw_midground_terrain(horizon_y: float, color: Color):
	"""Draw closer rolling hills with atmospheric perspective"""
	var sky_palette = TERRAFORM_SKY_COLORS[_terraforming_stage]

	# Layer 1: Distant hills - hazed
	var far_hill_color = color.lerp(sky_palette.horizon, 0.5)
	var far_points = PackedVector2Array()
	far_points.append(Vector2(0, horizon_y + 70))
	for i in range(21):
		var x = size.x * i / 20
		var hill_h = 18 + sin(i * 0.4) * 14 + sin(i * 1.1) * 8
		far_points.append(Vector2(x, horizon_y + 20 - hill_h))
	far_points.append(Vector2(size.x, horizon_y + 70))
	draw_polygon(far_points, [far_hill_color])

	# Layer 2: Closer hills
	var points = PackedVector2Array()
	points.append(Vector2(0, horizon_y + 60))
	for i in range(16):
		var x = size.x * i / 15
		var hill_h = 15 + sin(i * 0.5 + 2.0) * 12 + sin(i * 1.2) * 8
		points.append(Vector2(x, horizon_y + 10 - hill_h))
	points.append(Vector2(size.x, horizon_y + 60))
	draw_polygon(points, [color])

func _draw_ground_plane(horizon_y: float, ground_colors: Dictionary):
	"""Draw the ground plane that buildings sit on"""
	# Simple solid ground color - no gradient bands
	var fg_color = ground_colors.dark
	draw_rect(Rect2(0, horizon_y + 20, size.x, size.y - horizon_y - 20), fg_color)

	# ROCKY FOREGROUND - dramatic framing like reference images
	_draw_foreground_rocks(ground_colors)

func _draw_foreground_rocks(ground_colors: Dictionary):
	"""Draw dramatic rocky formations in foreground for cinematic framing"""
	var sky_palette = TERRAFORM_SKY_COLORS[_terraforming_stage]

	# Rock colors - darker than ground, with some purple/brown tones
	var rock_dark = ground_colors.dark.darkened(0.35)
	var rock_mid = ground_colors.dark.darkened(0.2)
	var rock_light = ground_colors.dark.lerp(sky_palette.horizon, 0.15)  # Rim lit

	# LEFT SIDE ROCKS - large formation framing the view
	var left_rocks = PackedVector2Array([
		Vector2(0, size.y),  # Bottom left corner
		Vector2(0, size.y * 0.55),  # Up the left edge
		Vector2(size.x * 0.03, size.y * 0.52),  # Peak 1
		Vector2(size.x * 0.06, size.y * 0.58),
		Vector2(size.x * 0.09, size.y * 0.54),  # Peak 2
		Vector2(size.x * 0.12, size.y * 0.62),
		Vector2(size.x * 0.15, size.y * 0.56),  # Peak 3
		Vector2(size.x * 0.18, size.y * 0.68),
		Vector2(size.x * 0.22, size.y * 0.72),
		Vector2(size.x * 0.25, size.y * 0.78),
		Vector2(size.x * 0.28, size.y * 0.85),
		Vector2(size.x * 0.30, size.y),  # Meets bottom
	])
	draw_polygon(left_rocks, [rock_dark])

	# Left rocks highlight (rim lighting from sky)
	var left_highlight = PackedVector2Array([
		Vector2(size.x * 0.03, size.y * 0.52),
		Vector2(size.x * 0.06, size.y * 0.58),
		Vector2(size.x * 0.09, size.y * 0.54),
		Vector2(size.x * 0.12, size.y * 0.62),
		Vector2(size.x * 0.15, size.y * 0.56),
		Vector2(size.x * 0.13, size.y * 0.58),
		Vector2(size.x * 0.10, size.y * 0.56),
		Vector2(size.x * 0.07, size.y * 0.60),
		Vector2(size.x * 0.04, size.y * 0.54),
	])
	for i in range(left_highlight.size() - 1):
		draw_line(left_highlight[i], left_highlight[i + 1],
			rock_light, 2.5)

	# RIGHT SIDE ROCKS - smaller formation
	var right_rocks = PackedVector2Array([
		Vector2(size.x, size.y),  # Bottom right corner
		Vector2(size.x, size.y * 0.65),  # Up the right edge
		Vector2(size.x * 0.96, size.y * 0.62),  # Peak 1
		Vector2(size.x * 0.93, size.y * 0.68),
		Vector2(size.x * 0.90, size.y * 0.64),  # Peak 2
		Vector2(size.x * 0.86, size.y * 0.72),
		Vector2(size.x * 0.82, size.y * 0.78),
		Vector2(size.x * 0.78, size.y * 0.88),
		Vector2(size.x * 0.75, size.y),  # Meets bottom
	])
	draw_polygon(right_rocks, [rock_mid])

	# FOREGROUND BOULDERS - scattered small rocks
	var boulder_color = rock_dark.lightened(0.05)
	# Boulder 1 - bottom left area
	draw_circle(Vector2(size.x * 0.32, size.y * 0.92), 15, boulder_color)
	draw_circle(Vector2(size.x * 0.35, size.y * 0.94), 10, boulder_color.darkened(0.1))
	# Boulder 2 - bottom center-left
	draw_circle(Vector2(size.x * 0.42, size.y * 0.96), 12, boulder_color)
	# Boulder 3 - bottom right area
	draw_circle(Vector2(size.x * 0.68, size.y * 0.94), 14, boulder_color)
	draw_circle(Vector2(size.x * 0.72, size.y * 0.96), 8, boulder_color.darkened(0.15))

# =============================================================================
# BUILDING QUERY HELPERS
# =============================================================================

func _has_building_type(building_type: int) -> bool:
	"""Check if colony has an operational building of the given type"""
	for b in _buildings:
		if b.get("type", -1) == building_type and b.get("is_operational", false):
			return true
	return false

func _get_building_max_tier(building_type: int) -> int:
	"""Get the highest tier of an operational building type (0 if none)"""
	var max_tier = 0
	for b in _buildings:
		if b.get("type", -1) == building_type and b.get("is_operational", false):
			max_tier = maxi(max_tier, b.get("tier", 1))
	return max_tier

# =============================================================================
# ORBITAL ELEMENTS
# =============================================================================

func _draw_orbital_elements():
	"""Draw satellites, space stations, skyhook, and orbital ring in the sky"""
	var sky_center = Vector2(size.x * 0.5, size.y * 0.15)

	# Check for actual orbital buildings
	var starport_tier = _get_building_max_tier(_MCSTypes.BuildingType.STARPORT)
	var orbital_tier = _get_building_max_tier(_MCSTypes.BuildingType.ORBITAL)
	var catcher_tier = _get_building_max_tier(_MCSTypes.BuildingType.CATCHER)

	# STARPORT - Shows landing/launching ships from surface
	if starport_tier > 0:
		_draw_starport_ships(sky_center, starport_tier)

	# ORBITAL STATION - Large space station in orbit
	if orbital_tier > 0:
		_draw_orbital_station(sky_center, orbital_tier)

	# ASTEROID CATCHER - Cargo catching facility with asteroids
	if catcher_tier > 0:
		_draw_asteroid_catcher(sky_center, catcher_tier)

	# Satellites traversing the sky (left to right) - BOLD and visible!
	if starport_tier > 0 or orbital_tier > 0 or _colony_tier != "survival":
		var num_sats = 3 + starport_tier + orbital_tier * 2  # More satellites
		for i in range(num_sats):
			# Each satellite has different speed and altitude
			var speed = 0.02 + i * 0.008  # Varied speeds
			var orbit_t = fmod(_time * speed + i * 0.25, 1.0)
			# Traverse from left edge to right edge of sky
			var sat_x = orbit_t * size.x
			var sat_y = size.y * (0.06 + i * 0.025) + sin(orbit_t * PI) * 20  # Higher arc
			# Solar panel glint - BRIGHT
			var glint = max(0, sin(_time * 3.0 + i * 1.2))
			var sat_size = 4 + glint * 3  # LARGER, pulsing
			var sat_color = Color(0.9, 0.95, 1.0, 0.7 + glint * 0.3)  # Brighter
			draw_circle(Vector2(sat_x, sat_y), sat_size, sat_color)
			# Add solar panel wings when glinting
			if glint > 0.5:
				var wing_len = 8 + i * 2
				draw_line(Vector2(sat_x - wing_len, sat_y), Vector2(sat_x + wing_len, sat_y),
					Color(0.3, 0.5, 0.8, glint * 0.6), 2)

	# LARGE ORBITAL SHIPS - freighters, liners, cruisers (tied to starport)
	if not _orbital_ships.is_empty():
		_draw_orbital_ships(sky_center)

	# SKYHOOK - Rotating momentum-exchange tether
	var skyhook_tier = _get_building_max_tier(_MCSTypes.BuildingType.SKYHOOK)
	if skyhook_tier > 0:
		_draw_skyhook(sky_center, skyhook_tier)

	# MASS DRIVER PROJECTILE - Launched cargo capsule
	if _mass_driver_projectile_t >= 0:
		_draw_mass_driver_projectile(sky_center)

	# ORBITAL RING (transcendence only) - the ultimate flex
	if _colony_tier == "transcendence":
		var ring_center = Vector2(size.x * 0.5, size.y * 0.2)
		var ring_rx = 200
		var ring_ry = 30
		# Ring segments
		var segments = 32
		for i in range(segments):
			var a1 = i * TAU / segments
			var a2 = (i + 1) * TAU / segments
			var p1 = ring_center + Vector2(cos(a1) * ring_rx, sin(a1) * ring_ry)
			var p2 = ring_center + Vector2(cos(a2) * ring_rx, sin(a2) * ring_ry)
			# Shimmer effect
			var shimmer = 0.4 + sin(_time * 2.0 + a1 * 3) * 0.2
			draw_line(p1, p2, Color(0.6, 0.8, 1.0, shimmer), 3)
		# Energy nodes on ring
		for i in range(8):
			var node_a = i * TAU / 8 + _time * 0.1
			var node_pos = ring_center + Vector2(cos(node_a) * ring_rx, sin(node_a) * ring_ry)
			draw_circle(node_pos, 4, Color(0.5, 0.9, 1.0, 0.8))

func _draw_skyhook(sky_center: Vector2, tier: int):
	"""Draw rotating skyhook tether - BOLD and dramatic, traverses sky while rotating"""
	# Skyhook traverses left-to-right while rotating
	var traverse_t = fmod(_time * 0.014 + 0.5, 1.0)
	var hook_center = Vector2(traverse_t * size.x, size.y * 0.14 + sin(traverse_t * PI) * 25)

	# Tether properties based on tier - MUCH LONGER
	var tether_length = 60.0 + tier * 25.0  # 85-185 pixels - impressive span!
	var rotation_speed = UPGRADE_PATHS.get("skyhook", {}).get(tier, {}).get("rotation_speed", 0.3)
	var has_counterweight = tier >= 3

	# Calculate tether endpoints based on rotation
	var angle = _skyhook_rotation
	var end1 = hook_center + Vector2(cos(angle), sin(angle) * 0.4) * tether_length
	var end2 = hook_center + Vector2(cos(angle + PI), sin(angle + PI) * 0.4) * tether_length

	# Tether color - BOLD metallic with energy glow
	var tether_color = Color(0.8, 0.85, 0.9, 0.9)
	if tier >= 4:
		tether_color = tether_color.lerp(Color(0.6, 0.9, 1.0), 0.4)

	# Draw tether - THICK and visible
	draw_line(end1, end2, tether_color, 3.0 + tier * 0.8)
	# Add glow line behind
	draw_line(end1, end2, Color(0.5, 0.7, 1.0, 0.3), 6.0 + tier * 1.5)

	# Central hub - LARGER
	draw_circle(hook_center, 8 + tier * 2, Color(0.7, 0.75, 0.8, 0.9))
	draw_circle(hook_center, 5 + tier, Color(0.4, 0.6, 0.8, 0.6))  # Inner glow

	# Counterweights at endpoints - ALWAYS visible, bigger at higher tiers
	var cw_size = 5 + tier * 2
	draw_circle(end1, cw_size, Color(0.6, 0.65, 0.7, 0.8))
	draw_circle(end2, cw_size, Color(0.6, 0.65, 0.7, 0.8))
	# Counterweight highlights
	draw_circle(end1, cw_size * 0.5, Color(0.8, 0.85, 0.9, 0.5))
	draw_circle(end2, cw_size * 0.5, Color(0.8, 0.85, 0.9, 0.5))

	# Catch/release flash effect - BIGGER and more dramatic
	if _skyhook_catch_timer < 0.5:
		var flash_alpha = 1.0 - _skyhook_catch_timer * 2.0
		var catch_end = end1 if end1.y > end2.y else end2
		draw_circle(catch_end, 15 + tier * 4, Color(1.0, 0.9, 0.5, flash_alpha * 0.8))
		draw_circle(catch_end, 25 + tier * 6, Color(1.0, 0.8, 0.3, flash_alpha * 0.3))

	# Orbital arc hint (subtle curve showing trajectory)
	if tier >= 2:
		var arc_color = Color(0.6, 0.7, 0.8, 0.15)
		var arc_points = PackedVector2Array()
		for i in range(17):
			var a = -0.4 + i * 0.05
			arc_points.append(hook_center + Vector2(cos(a) * 100, sin(a) * 40))
		for i in range(arc_points.size() - 1):
			draw_line(arc_points[i], arc_points[i + 1], arc_color, 1.0)

func _draw_mass_driver_projectile(sky_center: Vector2):
	"""Draw cargo capsule launched from mass driver"""
	# Start position: bottom of screen (mass driver location)
	var start_pos = Vector2(size.x * 0.3, size.y * 0.85)
	# End position: near skyhook in orbit
	var end_pos = sky_center + Vector2(-60, 40)  # Same as skyhook center, lower

	# Curved trajectory (parabolic arc)
	var t = _mass_driver_projectile_t
	var mid_y = lerp(start_pos.y, end_pos.y, 0.5) - 80  # Arc peak
	var mid_pos = Vector2(lerp(start_pos.x, end_pos.x, 0.5), mid_y)

	# Quadratic bezier interpolation
	var p01 = start_pos.lerp(mid_pos, t)
	var p12 = mid_pos.lerp(end_pos, t)
	var current_pos = p01.lerp(p12, t)

	# Capsule
	var capsule_color = Color(0.8, 0.75, 0.6)
	draw_circle(current_pos, 4, capsule_color)

	# Plasma/exhaust trail
	var trail_length = 8
	for i in range(trail_length):
		var trail_t = maxf(0, t - i * 0.02)
		var tp01 = start_pos.lerp(mid_pos, trail_t)
		var tp12 = mid_pos.lerp(end_pos, trail_t)
		var trail_pos = tp01.lerp(tp12, trail_t)
		var trail_alpha = (trail_length - i) / float(trail_length) * 0.5
		var trail_size = 3 - i * 0.3
		if trail_size > 0:
			draw_circle(trail_pos, trail_size, Color(1.0, 0.6, 0.2, trail_alpha))

	# Bright point at front
	draw_circle(current_pos, 2, Color(1.0, 0.95, 0.8, 0.9))

func _draw_orbital_ships(sky_center: Vector2):
	"""Draw large orbital ships - BOLD freighters, liners, cruisers traversing the sky"""
	for ship in _orbital_ships:
		# Ships traverse left-to-right across the sky
		var traverse_t = fmod(ship.orbit_t / TAU, 1.0)
		var orbit_x = traverse_t * size.x
		var orbit_y = size.y * 0.10 + sin(traverse_t * PI) * 25 + ship.orbit_r * 0.05
		var pos = Vector2(orbit_x, orbit_y)
		var ship_size = ship.size * 1.5  # 50% BIGGER ships!

		# Different ship types have different shapes
		match ship.type:
			"freighter":
				# Boxy cargo ship with containers
				var body_color = Color(0.55, 0.52, 0.48, 0.8)
				draw_rect(Rect2(pos.x - ship_size, pos.y - ship_size * 0.3, ship_size * 2, ship_size * 0.6), body_color)
				# Engine glow
				draw_circle(pos + Vector2(-ship_size - 3, 0), 3, Color(0.3, 0.6, 1.0, 0.6))
				# Containers on top
				for i in range(3):
					var cx = pos.x - ship_size * 0.6 + i * ship_size * 0.5
					draw_rect(Rect2(cx, pos.y - ship_size * 0.5, ship_size * 0.4, ship_size * 0.2), Color(0.7, 0.5, 0.3, 0.7))

			"liner":
				# Sleek passenger ship with windows
				var body_color = Color(0.8, 0.82, 0.85, 0.8)
				# Elongated hull
				draw_rect(Rect2(pos.x - ship_size * 1.2, pos.y - ship_size * 0.25, ship_size * 2.4, ship_size * 0.5), body_color)
				# Window strip
				for i in range(5):
					var wx = pos.x - ship_size * 0.8 + i * ship_size * 0.4
					draw_circle(Vector2(wx, pos.y), 1.5, Color(1.0, 0.95, 0.7, 0.8))
				# Engine pods
				draw_circle(pos + Vector2(-ship_size * 1.2, ship_size * 0.2), 2, Color(0.4, 0.7, 1.0, 0.7))
				draw_circle(pos + Vector2(-ship_size * 1.2, -ship_size * 0.2), 2, Color(0.4, 0.7, 1.0, 0.7))

			"cruiser":
				# Military-style with angular design
				var body_color = Color(0.4, 0.42, 0.45, 0.85)
				# Wedge shape
				var hull = PackedVector2Array([
					pos + Vector2(ship_size * 1.3, 0),  # Nose
					pos + Vector2(-ship_size, -ship_size * 0.4),
					pos + Vector2(-ship_size, ship_size * 0.4)
				])
				draw_polygon(hull, [body_color])
				# Bridge
				draw_rect(Rect2(pos.x - ship_size * 0.3, pos.y - ship_size * 0.5, ship_size * 0.6, ship_size * 0.15), Color(0.6, 0.65, 0.7, 0.8))
				# Engine array
				for i in range(3):
					var ey = pos.y - ship_size * 0.25 + i * ship_size * 0.25
					draw_circle(Vector2(pos.x - ship_size * 1.05, ey), 2, Color(0.3, 0.5, 0.9, 0.7))

func _draw_starport_ships(sky_center: Vector2, tier: int):
	"""Draw ships ascending/descending - BOLD with dramatic flames!"""
	# More ships at higher tiers
	var ship_count = 2 + tier
	for i in range(ship_count):
		# Each ship has a different phase offset
		var phase_offset = i * 2.8  # Stagger the ships
		var cycle_time = 10.0 - tier  # Faster cycles at higher tiers
		var ship_phase = fmod(_time + phase_offset, cycle_time) / cycle_time

		# Ship travels from horizon to orbit and back
		var ascending = ship_phase < 0.5
		var t = ship_phase * 2.0 if ascending else (1.0 - ship_phase) * 2.0

		# Curved path from surface to orbit - wider spread
		var start_x = size.x * (0.2 + i * 0.12)
		var start_y = size.y * 0.88
		var end_x = sky_center.x + (i - ship_count * 0.5) * 50
		var end_y = sky_center.y + 20

		# Bezier curve for realistic ascent/descent
		var control_x = lerp(start_x, end_x, 0.5)
		var control_y = size.y * 0.35
		var ship_x = lerp(lerp(start_x, control_x, t), lerp(control_x, end_x, t), t)
		var ship_y = lerp(lerp(start_y, control_y, t), lerp(control_y, end_y, t), t)
		var ship_pos = Vector2(ship_x, ship_y)

		# Ship size - BIGGER, gets smaller as it ascends (perspective)
		var ship_scale = lerp(1.0, 0.4, t)
		var ship_size = (14 + tier * 4) * ship_scale  # Much bigger base size!

		# Draw ship body - BRIGHTER
		var ship_color = Color(0.85, 0.88, 0.92, 0.95)
		var nose_dir = -1 if ascending else 1
		var nose = ship_pos + Vector2(0, nose_dir * ship_size)
		var left = ship_pos + Vector2(-ship_size * 0.5, -nose_dir * ship_size * 0.4)
		var right = ship_pos + Vector2(ship_size * 0.5, -nose_dir * ship_size * 0.4)
		var hull = PackedVector2Array([nose, left, right])
		if _is_valid_polygon(hull):
			draw_polygon(hull, [ship_color])
			# Add highlight
			draw_polygon(hull, [Color(1.0, 1.0, 1.0, 0.2)])

		# Engine flame - DRAMATIC!
		var flame_size = ship_size * 0.8 * (1.2 if ascending else 0.4)
		var flame_pos = ship_pos + Vector2(0, -nose_dir * ship_size * 0.5)
		var flame_color = Color(1.0, 0.5, 0.1, 0.95) if ascending else Color(0.4, 0.7, 1.0, 0.6)
		draw_circle(flame_pos, flame_size, flame_color)
		if ascending:
			# Exhaust trail
			for j in range(5):
				var trail_t = j * 0.15
				var trail_pos = ship_pos + Vector2(0, -nose_dir * (ship_size * 0.6 + j * ship_size * 0.3))
				draw_circle(trail_pos, flame_size * (1.0 - trail_t * 0.5), Color(1.0, 0.5, 0.1, 0.4 - trail_t * 0.3))

func _draw_orbital_station(sky_center: Vector2, tier: int):
	"""Draw large orbital space station - BOLD and impressive, traverses sky"""
	# Station traverses left-to-right slowly (like ISS pass)
	var traverse_t = fmod(_time * 0.012, 1.0)  # Slow but visible traverse
	var station_x = traverse_t * size.x
	var station_y = size.y * 0.12 + sin(traverse_t * PI) * 30  # Higher arc
	var pos = Vector2(station_x, station_y)

	# Station size based on tier - MUCH BIGGER
	var station_size = 20 + tier * 10  # 30-70 pixels!

	# Main hub (rotating)
	var hub_rotation = _time * 0.2
	var hub_color = Color(0.7, 0.72, 0.75, 0.85)
	draw_circle(pos, station_size * 0.4, hub_color)

	# Rotating ring (habitat ring)
	var ring_radius = station_size
	var ring_segments = 8 + tier * 4
	for i in range(ring_segments):
		var angle = hub_rotation + i * TAU / ring_segments
		var ring_pos = pos + Vector2(cos(angle), sin(angle) * 0.4) * ring_radius
		var segment_size = 2 + tier
		draw_circle(ring_pos, segment_size, Color(0.6, 0.65, 0.7, 0.7))

	# Solar arrays (4 large panels)
	var panel_color = Color(0.2, 0.3, 0.5, 0.7)
	var panel_length = station_size * 1.5
	var panel_width = station_size * 0.3
	for i in range(4):
		var panel_angle = i * TAU / 4 + _time * 0.02  # Slow tracking rotation
		var panel_dir = Vector2(cos(panel_angle), sin(panel_angle) * 0.4)
		var panel_start = pos + panel_dir * station_size * 0.5
		var panel_end = pos + panel_dir * (station_size * 0.5 + panel_length)
		draw_line(panel_start, panel_end, panel_color, panel_width)
		# Panel glint
		var glint = maxf(0, sin(panel_angle + _time))
		if glint > 0.8:
			draw_circle(panel_end, 3, Color(0.8, 0.9, 1.0, glint - 0.8))

	# Docking ports with occasional ship
	if tier >= 2:
		var dock_angle = _time * 0.1
		var dock_pos = pos + Vector2(cos(dock_angle), sin(dock_angle) * 0.4) * station_size * 0.6
		draw_rect(Rect2(dock_pos.x - 4, dock_pos.y - 2, 8, 4), Color(0.5, 0.55, 0.6, 0.8))

	# Station lights (blinking)
	var blink = sin(_time * 3.0) > 0.5
	if blink:
		draw_circle(pos + Vector2(0, -station_size * 0.5), 2, Color(1.0, 0.2, 0.2, 0.9))
		draw_circle(pos + Vector2(0, station_size * 0.5), 2, Color(0.2, 1.0, 0.2, 0.9))

func _draw_asteroid_catcher(sky_center: Vector2, tier: int):
	"""Draw asteroid catcher facility - BOLD with dramatic asteroid captures"""
	# Catcher traverses left-to-right in higher orbit
	var traverse_t = fmod(_time * 0.015 + 0.3, 1.0)
	var catcher_x = traverse_t * size.x
	var catcher_y = size.y * 0.08 + sin(traverse_t * PI) * 20  # High orbit
	var pos = Vector2(catcher_x, catcher_y)

	var catcher_size = 18 + tier * 8  # MUCH BIGGER - impressive facility

	# Main structure - net/scoop shape
	var scoop_color = Color(0.6, 0.55, 0.5, 0.8)
	var scoop_open = catcher_size * 1.5
	var scoop_depth = catcher_size * 0.8

	# Draw scoop arms
	var arm_left = pos + Vector2(-scoop_open * 0.5, -scoop_depth * 0.5)
	var arm_right = pos + Vector2(scoop_open * 0.5, -scoop_depth * 0.5)
	var scoop_back = pos + Vector2(0, scoop_depth * 0.5)
	draw_line(arm_left, scoop_back, scoop_color, 2)
	draw_line(arm_right, scoop_back, scoop_color, 2)
	draw_line(arm_left, arm_right, scoop_color, 1)

	# Net lines
	for i in range(3):
		var t = (i + 1) * 0.25
		var net_left = arm_left.lerp(scoop_back, t)
		var net_right = arm_right.lerp(scoop_back, t)
		draw_line(net_left, net_right, Color(0.5, 0.5, 0.5, 0.4), 1)

	# Processing module at back
	draw_circle(scoop_back, catcher_size * 0.3, Color(0.65, 0.6, 0.55, 0.8))

	# Incoming asteroids (multiple based on tier)
	var asteroid_count = tier
	for i in range(asteroid_count):
		var asteroid_phase = fmod(_time * 0.15 + i * 2.3, 1.0)
		# Asteroids come from upper right
		var ast_start = Vector2(size.x * 0.9, size.y * 0.05)
		var ast_end = pos + Vector2(0, -scoop_depth * 0.3)

		var ast_t = asteroid_phase
		var ast_pos = ast_start.lerp(ast_end, ast_t)
		var ast_size = 3 + tier + sin(i * 1.7) * 2

		# Asteroid (irregular shape simulated with multiple circles)
		var ast_color = Color(0.5, 0.45, 0.4, 0.7 + ast_t * 0.3)
		draw_circle(ast_pos, ast_size, ast_color)
		draw_circle(ast_pos + Vector2(ast_size * 0.3, -ast_size * 0.2), ast_size * 0.6, ast_color.darkened(0.1))

		# Trail
		if ast_t > 0.1:
			for j in range(3):
				var trail_t = ast_t - j * 0.05
				if trail_t > 0:
					var trail_pos = ast_start.lerp(ast_end, trail_t)
					draw_circle(trail_pos, ast_size * (0.5 - j * 0.1), Color(0.6, 0.5, 0.4, 0.2 - j * 0.05))

	# Catching flash effect
	var catch_phase = fmod(_time, 5.0)
	if catch_phase < 0.3:
		var flash_alpha = (0.3 - catch_phase) * 3.0
		draw_circle(pos, catcher_size * 0.8, Color(1.0, 0.9, 0.5, flash_alpha * 0.5))

func _draw_landing_ships():
	"""Draw ships landing/taking off from the colony"""
	for ship in _landing_ships:
		# Screen position
		var screen_x = size.x * ship.x
		var screen_y = lerp(size.y * 0.1, size.y * 0.7, ship.y)  # Landing zone

		# Ship gets bigger as it descends (perspective)
		var scale = 0.3 + ship.y * 0.7
		var base_size = 8 if ship.type == "shuttle" else (14 if ship.type == "freighter" else 12)
		var ship_size = base_size * scale

		match ship.type:
			"shuttle":
				# Small triangular shuttle
				var nose = Vector2(screen_x, screen_y - ship_size)
				var left = Vector2(screen_x - ship_size * 0.6, screen_y + ship_size * 0.5)
				var right = Vector2(screen_x + ship_size * 0.6, screen_y + ship_size * 0.5)
				draw_polygon(PackedVector2Array([nose, left, right]), [Color(0.75, 0.78, 0.82, 0.9)])
				# Engine flame (landing = bottom, takeoff = top)
				if ship.phase == "landing":
					_draw_engine_flame(Vector2(screen_x, screen_y + ship_size * 0.6), ship_size * 0.4, true)
				else:
					_draw_engine_flame(Vector2(screen_x, screen_y + ship_size * 0.6), ship_size * 0.5, false)

			"freighter":
				# Boxy cargo ship
				draw_rect(Rect2(screen_x - ship_size, screen_y - ship_size * 0.4, ship_size * 2, ship_size * 0.8), Color(0.55, 0.52, 0.48, 0.9))
				# Cockpit
				draw_rect(Rect2(screen_x - ship_size * 0.3, screen_y - ship_size * 0.7, ship_size * 0.6, ship_size * 0.35), Color(0.4, 0.6, 0.8, 0.8))
				# Engines
				_draw_engine_flame(Vector2(screen_x - ship_size * 0.5, screen_y + ship_size * 0.5), ship_size * 0.3, ship.phase == "landing")
				_draw_engine_flame(Vector2(screen_x + ship_size * 0.5, screen_y + ship_size * 0.5), ship_size * 0.3, ship.phase == "landing")

			"passenger":
				# Sleek passenger liner
				var body = PackedVector2Array([
					Vector2(screen_x, screen_y - ship_size),  # Nose
					Vector2(screen_x - ship_size * 0.8, screen_y + ship_size * 0.3),
					Vector2(screen_x - ship_size * 0.8, screen_y + ship_size * 0.5),
					Vector2(screen_x + ship_size * 0.8, screen_y + ship_size * 0.5),
					Vector2(screen_x + ship_size * 0.8, screen_y + ship_size * 0.3),
				])
				draw_polygon(body, [Color(0.85, 0.87, 0.9, 0.9)])
				# Windows
				for i in range(4):
					var wx = screen_x - ship_size * 0.5 + i * ship_size * 0.35
					draw_circle(Vector2(wx, screen_y), 1.5 * scale, Color(1.0, 0.95, 0.7, 0.8))
				# Engine
				_draw_engine_flame(Vector2(screen_x, screen_y + ship_size * 0.55), ship_size * 0.4, ship.phase == "landing")

func _draw_engine_flame(pos: Vector2, size_mult: float, is_retro: bool):
	"""Draw engine exhaust flame"""
	var flame_length = size_mult * (15 if is_retro else 25)
	var flame_width = size_mult * 6

	# Flame direction (down for landing/retro, up for takeoff)
	var direction = -1 if is_retro else 1

	# Core flame (white-yellow)
	var core_points = PackedVector2Array([
		pos,
		pos + Vector2(-flame_width * 0.3, flame_length * 0.6 * direction),
		pos + Vector2(0, flame_length * direction),
		pos + Vector2(flame_width * 0.3, flame_length * 0.6 * direction)
	])
	draw_polygon(core_points, [Color(1.0, 0.95, 0.7, 0.9)])

	# Outer flame (orange)
	var outer_points = PackedVector2Array([
		pos + Vector2(-flame_width * 0.2, 0),
		pos + Vector2(-flame_width * 0.5, flame_length * 0.7 * direction),
		pos + Vector2(0, flame_length * 1.2 * direction),
		pos + Vector2(flame_width * 0.5, flame_length * 0.7 * direction),
		pos + Vector2(flame_width * 0.2, 0)
	])
	draw_polygon(outer_points, [Color(1.0, 0.5, 0.1, 0.6)])

func _draw_city_spotlights():
	"""Draw rotating searchlights sweeping across the city"""
	if _colony_tier == "survival" or _building_layout.size() < 10:
		return

	# Place spotlights at tall buildings
	var spotlight_positions: Array = []
	for bid in _building_layout:
		var layout = _building_layout[bid]
		if layout.height > 60:  # Only on tall buildings
			spotlight_positions.append(Vector2(layout.screen_x, layout.screen_y - layout.height * 0.8))

	# Draw each spotlight beam
	for i in range(mini(_spotlight_angles.size(), spotlight_positions.size())):
		var pos = spotlight_positions[i]
		var angle = _spotlight_angles[i]

		# Beam cone
		var beam_length = 200 + sin(_time * 0.5 + i) * 50
		var beam_spread = 0.2

		var end_center = pos + Vector2(cos(angle), sin(angle) * 0.5) * beam_length
		var end_left = pos + Vector2(cos(angle - beam_spread), sin(angle - beam_spread) * 0.5) * beam_length
		var end_right = pos + Vector2(cos(angle + beam_spread), sin(angle + beam_spread) * 0.5) * beam_length

		# Draw cone with gradient
		var beam_color = Color(1.0, 0.98, 0.9, 0.08)
		var cone = PackedVector2Array([pos, end_left, end_center, end_right])
		draw_polygon(cone, [beam_color])

		# Bright spot at origin
		draw_circle(pos, 4, Color(1.0, 0.95, 0.8, 0.6))

		# Sky hit (if beam points upward)
		if sin(angle) < -0.3:
			var sky_y = size.y * 0.1
			var sky_x = pos.x + (sky_y - pos.y) / tan(angle) if abs(tan(angle)) > 0.01 else pos.x
			if sky_x > 0 and sky_x < size.x:
				draw_circle(Vector2(sky_x, sky_y), 15 + sin(_time * 2 + i) * 5, Color(1.0, 0.95, 0.85, 0.15))

func _draw_comms_dishes():
	"""Draw radar dishes on COMMS buildings"""
	for b in _buildings:
		if b.get("type", -1) != _MCSTypes.BuildingType.COMMS:
			continue
		if not b.get("is_operational", false):
			continue

		var bid = b.get("id", "")
		if not _building_layout.has(bid):
			continue

		var layout = _building_layout[bid]
		var tier = b.get("tier", 1)

		# Draw dishes on top of the COMMS building
		var base_pos = Vector2(layout.screen_x, layout.screen_y - layout.height * 0.6)

		# Main dish - rotates slowly
		var dish_angle = _time * 0.1
		var dish_size = 12 + tier * 3

		# Dish base (pole)
		draw_rect(Rect2(base_pos.x - 2, base_pos.y, 4, 15), Color(0.5, 0.52, 0.55))

		# Dish (parabolic shape)
		var dish_center = base_pos + Vector2(cos(dish_angle) * 8, -5)
		var dish_points = PackedVector2Array()
		for j in range(9):
			var a = -0.8 + j * 0.2
			var dx = cos(dish_angle + a * 0.5) * dish_size * abs(cos(a))
			var dy = sin(a) * dish_size * 0.4 - 8
			dish_points.append(dish_center + Vector2(dx, dy))
		if dish_points.size() >= 3:
			draw_polyline(dish_points, Color(0.7, 0.72, 0.75), 2.0)

		# Dish face
		draw_circle(dish_center + Vector2(0, -8), dish_size * 0.3, Color(0.6, 0.65, 0.7, 0.5))

		# Signal waves (animated)
		if tier >= 2:
			for wave in range(3):
				var wave_t = fmod(_time * 0.8 + wave * 0.3, 1.0)
				var wave_r = 10 + wave_t * 40
				var wave_alpha = (1.0 - wave_t) * 0.3
				var wave_pos = dish_center + Vector2(cos(dish_angle), 0) * wave_r * 0.5
				draw_arc(wave_pos, wave_r, dish_angle - 0.3, dish_angle + 0.3, 8, Color(0.4, 0.8, 1.0, wave_alpha), 1.5)

func _draw_energy_network():
	"""Draw energy beams connecting power sources to major buildings"""
	# Only in later tiers
	if _colony_tier == "survival" or _building_layout.size() < 5:
		return

	var center = _iso_transform(WORLD_CENTER_X, WORLD_CENTER_Y, 20)

	# Find power buildings and major structures
	var power_buildings = []
	var consumers = []

	for bid in _building_layout:
		var layout = _building_layout[bid]
		# Find matching building data
		for b in _buildings:
			if b.get("id", "") == bid:
				var btype = b.get("type", 0)
				var is_operational = b.get("is_operational", false)
				if not is_operational:
					continue
				# Categorize
				if btype in [_MCSTypes.BuildingType.POWER_STATION, _MCSTypes.BuildingType.SOLAR_FARM, _MCSTypes.BuildingType.REACTOR, _MCSTypes.BuildingType.FUSION_PLANT]:
					power_buildings.append({"pos": _iso_transform(layout.world_x, layout.world_y, layout.height * 0.5), "type": btype})
				elif btype in [_MCSTypes.BuildingType.FABRICATOR, _MCSTypes.BuildingType.RESEARCH, _MCSTypes.BuildingType.FOUNDRY, _MCSTypes.BuildingType.PRECISION]:
					consumers.append(_iso_transform(layout.world_x, layout.world_y, layout.height * 0.5))
				break

	# Draw energy beams from power to center hub
	for power in power_buildings:
		var beam_color = Color(0.3, 0.7, 1.0, 0.3)
		if power.type == _MCSTypes.BuildingType.REACTOR or power.type == _MCSTypes.BuildingType.FUSION_PLANT:
			beam_color = Color(0.3, 1.0, 0.5, 0.3)  # Green for nuclear

		# Pulsing beam
		var pulse = fmod(_time * 2.0, 1.0)
		var mid_point = power.pos.lerp(center, pulse)

		draw_line(power.pos, center, beam_color, 2.0)
		draw_circle(mid_point, 4, Color(beam_color.r, beam_color.g, beam_color.b, 0.8))

func _draw_transit_system():
	"""Draw elevated monorail/transit tubes connecting nearby buildings"""
	# Only for established colonies (20+ buildings)
	if _building_layout.size() < 20:
		return

	# Ground boundary - transit must be WELL below horizon and mountains
	# The horizon is at ~38%, mountains extend to ~45%, so use 55% to be safe
	var ground_min_y = size.y * 0.55  # Must be clearly in ground area

	# Find transit hub buildings
	var hubs: Array = []

	for bid in _building_layout:
		var layout = _building_layout[bid]
		for b in _buildings:
			if b.get("id", "") == bid:
				var btype = b.get("type", 0)
				var is_operational = b.get("is_operational", false)
				if not is_operational:
					continue
				# Only major hub buildings - check screen position first
				var screen_pos = _iso_transform(layout.world_x, layout.world_y, layout.height)
				if screen_pos.y < ground_min_y:
					continue  # Skip buildings that appear in sky area
				if btype in [_MCSTypes.BuildingType.RECREATION, _MCSTypes.BuildingType.QUARTERS,
							_MCSTypes.BuildingType.MEDICAL, _MCSTypes.BuildingType.RESEARCH]:
					hubs.append({
						"pos": Vector2(layout.world_x, layout.world_y),
						"height": layout.height,
						"screen_pos": screen_pos,
						"type": btype
					})
				break

	if hubs.size() < 2:
		return

	# Find pairs of nearby buildings (max distance 60 units, tighter constraint)
	var max_dist = 60.0
	var connections: Array = []

	for i in range(hubs.size()):
		for j in range(i + 1, hubs.size()):
			var dist = hubs[i].pos.distance_to(hubs[j].pos)
			if dist < max_dist and dist > 25:  # Not too close, not too far
				connections.append({"a": hubs[i], "b": hubs[j], "dist": dist})

	# Limit to 2 connections max (very subtle)
	connections.sort_custom(func(x, y): return x.dist < y.dist)
	connections = connections.slice(0, 2)

	# Rail styling - subtle and low
	var rail_color = Color(0.55, 0.6, 0.65, 0.5)
	var support_color = Color(0.4, 0.45, 0.5, 0.6)

	for conn in connections:
		var hub_a = conn.a
		var hub_b = conn.b
		# Rail height just slightly above buildings
		var rail_height = maxf(hub_a.height, hub_b.height) + 5.0

		var start_3d = _iso_transform(hub_a.pos.x, hub_a.pos.y, rail_height)
		var end_3d = _iso_transform(hub_b.pos.x, hub_b.pos.y, rail_height)

		# Skip if any point is above ground area
		if start_3d.y < ground_min_y or end_3d.y < ground_min_y:
			continue

		# Short support pylons at each end (from building top, not ground)
		var start_top = _iso_transform(hub_a.pos.x, hub_a.pos.y, hub_a.height)
		var end_top = _iso_transform(hub_b.pos.x, hub_b.pos.y, hub_b.height)
		draw_line(start_top, start_3d, support_color, 1.5 * _camera_zoom)
		draw_line(end_top, end_3d, support_color, 1.5 * _camera_zoom)

		# Single rail line
		draw_line(start_3d, end_3d, rail_color, 1.5 * _camera_zoom)

		# Moving pod along the rail
		var pod_t = fmod(_time * 0.1 + hash(str(hub_a.pos)) * 0.001, 1.0)
		var pod_pos = start_3d.lerp(end_3d, pod_t)
		# Skip pod if in sky area
		if pod_pos.y >= ground_min_y:
			draw_circle(pod_pos, 3 * _camera_zoom, Color(0.85, 0.8, 0.75, 0.8))

func _draw_atmosphere_effects():
	"""Draw aurora, meteor showers, and other atmospheric phenomena"""
	# Aurora (rare, beautiful)
	if sin(_time * 0.05) > 0.9:
		_draw_aurora()

	# Occasional meteor
	if fmod(_time, 15.0) < 0.5:
		_draw_meteor()

func _draw_aurora():
	"""Draw northern lights effect"""
	var aurora_colors = [
		Color(0.2, 0.8, 0.4, 0.15),
		Color(0.3, 0.6, 0.9, 0.12),
		Color(0.5, 0.3, 0.8, 0.1)
	]

	for band in range(3):
		var base_y = size.y * (0.05 + band * 0.08)
		var points = PackedVector2Array()
		for i in range(20):
			var x = size.x * i / 19.0
			var wave = sin(_time * 0.5 + i * 0.3 + band) * 15
			points.append(Vector2(x, base_y + wave))

		for i in range(19):
			var p1 = points[i]
			var p2 = points[i + 1]
			var p3 = Vector2(p2.x, p2.y + 30)
			var p4 = Vector2(p1.x, p1.y + 30)
			draw_polygon(PackedVector2Array([p1, p2, p3, p4]), [aurora_colors[band]])

func _draw_meteor():
	"""Draw a shooting star/meteor"""
	var meteor_t = fmod(_time, 15.0) / 0.5
	var start = Vector2(size.x * 0.8, size.y * 0.05)
	var end_pos = Vector2(size.x * 0.3, size.y * 0.25)
	var pos = start.lerp(end_pos, meteor_t)

	# Trail
	for i in range(5):
		var trail_pos = start.lerp(end_pos, max(0, meteor_t - i * 0.05))
		var trail_alpha = (1.0 - i * 0.2) * (1.0 - meteor_t)
		draw_circle(trail_pos, 3 - i * 0.5, Color(1.0, 0.9, 0.7, trail_alpha))

	# Head
	draw_circle(pos, 3, Color(1.0, 0.95, 0.8, 1.0 - meteor_t))

# =============================================================================
# CRATER TERRAIN SYSTEM
# =============================================================================

# Crater parameters
const CRATER_RIM_HEIGHT = 25.0      # Height of crater rim above floor (reduced)
const CRATER_RIM_WIDTH = 40.0       # Width of the rim ring (narrower)
const CRATER_FLOOR_RADIUS = 160.0   # Radius of flat buildable area (bigger for buildings)
const CRATER_SEGMENTS = 32          # Smoothness of crater circle

# Terraforming stage (0-4)
var _terraforming_stage: int = 0

# Transport animation state
var _mass_driver_launch_timer: float = 0.0
var _mass_driver_projectile_t: float = -1.0  # -1 = no projectile, 0-1 = in flight
var _skyhook_rotation: float = 0.0
var _skyhook_catch_timer: float = 0.0

# Landing ships animation
var _landing_ships: Array = []  # {x, y, phase, type, timer}
var _landing_ship_spawn_timer: float = 0.0

# Orbital ships (large freighters/colony ships)
var _orbital_ships: Array = []  # {orbit_t, orbit_r, size, type}

# City spotlights
var _spotlight_angles: Array = [0.0, 1.5, 3.0, 4.5]  # Multiple spotlights with different phases

# Procedural skyscraper seeds (for deterministic generation)
var _skyscraper_seeds: Array = []

# Terraforming color palettes
# Golden/warm sky colors inspired by concept art - dramatic sunset atmosphere
const TERRAFORM_SKY_COLORS = [
	{"horizon": Color(0.95, 0.72, 0.45), "zenith": Color(0.55, 0.32, 0.22)},  # Stage 0: Golden Mars sunset
	{"horizon": Color(0.92, 0.75, 0.55), "zenith": Color(0.58, 0.38, 0.28)},  # Stage 1: Warming amber
	{"horizon": Color(0.95, 0.82, 0.65), "zenith": Color(0.65, 0.48, 0.36)},  # Stage 2: Soft gold
	{"horizon": Color(0.88, 0.82, 0.78), "zenith": Color(0.55, 0.58, 0.62)},  # Stage 3: Living
	{"horizon": Color(0.75, 0.85, 0.92), "zenith": Color(0.45, 0.58, 0.72)},  # Stage 4: Breathable blue
]

const TERRAFORM_GROUND_COLORS = [
	{"light": Color(0.65, 0.38, 0.25), "dark": Color(0.50, 0.28, 0.18)},  # Stage 0: Warm red rock
	{"light": Color(0.60, 0.35, 0.26), "dark": Color(0.45, 0.25, 0.18)},  # Stage 1: Rich red
	{"light": Color(0.52, 0.38, 0.28), "dark": Color(0.40, 0.30, 0.22)},  # Stage 2: Brown earth
	{"light": Color(0.40, 0.48, 0.32), "dark": Color(0.28, 0.38, 0.22)},  # Stage 3: Green patches
	{"light": Color(0.35, 0.55, 0.38), "dark": Color(0.25, 0.45, 0.28)},  # Stage 4: Lush green
]

func _draw_ground():
	"""Draw ground details - the background is handled by _draw_sky()"""
	# The sky/horizon/ground_plane already draws the base terrain
	# Here we just add the local details around the colony

	var ground_colors = TERRAFORM_GROUND_COLORS[_terraforming_stage]

	if PERSPECTIVE_ENABLED:
		_draw_ground_perspective(ground_colors)
	else:
		_draw_ground_isometric(ground_colors)

func _draw_ground_perspective(ground_colors: Dictionary):
	"""Draw ground for perspective view - subtle depth lines converging to horizon"""
	# Draw converging perspective lines to create depth
	var vp = _get_vanishing_point()
	var line_color = ground_colors.dark
	line_color.a = 0.1

	# Horizontal depth lines (parallel to horizon, getting smaller toward horizon)
	var num_lines = 8
	for i in range(num_lines):
		var depth_t = float(i + 1) / (num_lines + 1)
		var depth = depth_t * MAX_DEPTH
		var y = lerp(size.y * FOREGROUND_SCREEN_Y, size.y * HORIZON_SCREEN_Y, pow(depth_t, 1.3))
		var spread = lerp(size.x * 0.6, size.x * 0.1, depth_t)
		draw_line(Vector2(vp.x - spread, y), Vector2(vp.x + spread, y), line_color, 1.0)

	# Converging vertical lines
	var num_vlines = 12
	for i in range(num_vlines):
		var t = float(i) / (num_vlines - 1)
		var bottom_x = size.x * (0.1 + t * 0.8)
		var top_t = 0.3 + t * 0.4  # Lines converge toward center at horizon
		var top_x = vp.x + (bottom_x - vp.x) * 0.3
		draw_line(Vector2(bottom_x, size.y * FOREGROUND_SCREEN_Y),
			Vector2(top_x, size.y * (HORIZON_SCREEN_Y + 0.05)), line_color, 0.5)

	# Subtle colony highlight area
	var colony_color = ground_colors.light
	colony_color.a = 0.15
	var colony_poly = PackedVector2Array([
		_perspective_transform(-MAX_LATERAL * 0.4, MIN_DEPTH, 0),
		_perspective_transform(MAX_LATERAL * 0.4, MIN_DEPTH, 0),
		_perspective_transform(MAX_LATERAL * 0.3, MAX_DEPTH * 0.6, 0),
		_perspective_transform(-MAX_LATERAL * 0.3, MAX_DEPTH * 0.6, 0)
	])
	draw_polygon(colony_poly, [colony_color])

func _draw_ground_isometric(ground_colors: Dictionary):
	"""Draw ground for isometric view - original circular colony area"""
	# Subtle lighter area where colony sits (isometric circle)
	var colony_area_points = PackedVector2Array()
	var colony_r = WORLD_SIZE * 0.4
	for i in range(32):
		var angle = i * TAU / 32.0
		var pos = _iso_transform(
			WORLD_CENTER_X + cos(angle) * colony_r,
			WORLD_CENTER_Y + sin(angle) * colony_r,
			0
		)
		colony_area_points.append(pos)

	# Subtle highlight for the colony area
	var colony_ground = ground_colors.light
	colony_ground.a = 0.3
	draw_polygon(colony_area_points, [colony_ground])

	# Draw terrain features based on terraforming stage
	_draw_terrain_features()

	# Draw subtle grid in colony area
	_draw_floor_grid()

func _draw_floor_grid():
	"""Draw subtle grid for depth perception (isometric only)"""
	if PERSPECTIVE_ENABLED:
		return  # Perspective mode uses different grid in _draw_ground_perspective

	var grid_color = TERRAFORM_GROUND_COLORS[_terraforming_stage].dark
	grid_color.a = 0.15

	var grid_range = WORLD_SIZE * 0.4

	# Circular grid lines (concentric rings)
	for ring in range(1, 5):
		var r = ring * grid_range / 4.0
		var prev_pos = _iso_transform(WORLD_CENTER_X + r, WORLD_CENTER_Y, 0)
		for seg in range(1, 25):
			var angle = seg * TAU / 24.0
			var pos = _iso_transform(WORLD_CENTER_X + cos(angle) * r, WORLD_CENTER_Y + sin(angle) * r, 0)
			draw_line(prev_pos, pos, grid_color, 1.0)
			prev_pos = pos

	# Radial grid lines (spokes from center)
	for i in range(8):
		var angle = i * TAU / 8.0
		var start = _iso_transform(WORLD_CENTER_X, WORLD_CENTER_Y, 0)
		var end_pos = _iso_transform(
			WORLD_CENTER_X + cos(angle) * grid_range,
			WORLD_CENTER_Y + sin(angle) * grid_range,
			0
		)
		draw_line(start, end_pos, grid_color, 1.0)

func _draw_terrain_features():
	"""Draw stage-specific terrain features"""
	match _terraforming_stage:
		0:
			_draw_dust_patches()
		1:
			_draw_dust_patches()
			_draw_ice_pools()
		2:
			_draw_ice_pools()
			_draw_small_lakes()
		3:
			_draw_small_lakes()
			_draw_vegetation_patches()
		4:
			_draw_lakes_and_rivers()
			_draw_vegetation_patches()
			_draw_trees()

func _draw_dust_patches():
	"""Draw dusty patches on crater floor"""
	for i in range(8):
		var patch_angle = i * TAU / 8.0 + 0.5
		var patch_r = 40 + sin(i * 3.1) * 30
		var patch_x = WORLD_CENTER_X + cos(patch_angle) * patch_r
		var patch_y = WORLD_CENTER_Y + sin(patch_angle) * patch_r
		var patch_pos = _iso_transform(patch_x, patch_y, 0.1)
		var patch_size = 15 + sin(i * 2.7) * 8

		var dust_color = TERRAFORM_GROUND_COLORS[0].dark
		dust_color.a = 0.3
		_draw_ellipse(patch_pos, patch_size * _camera_zoom, patch_size * 0.5 * _camera_zoom, dust_color)

func _draw_ice_pools():
	"""Draw melting ice pools (stage 1-2)"""
	var ice_color = Color(0.7, 0.85, 0.95, 0.6)

	for i in range(5):
		var pool_angle = i * TAU / 5.0 + _time * 0.01
		var pool_r = 60 + sin(i * 2.3) * 25
		var pool_x = WORLD_CENTER_X + cos(pool_angle) * pool_r
		var pool_y = WORLD_CENTER_Y + sin(pool_angle) * pool_r
		var pool_pos = _iso_transform(pool_x, pool_y, 0.2)
		var pool_size = 12 + sin(i * 1.9) * 6

		_draw_ellipse(pool_pos, pool_size * _camera_zoom, pool_size * 0.5 * _camera_zoom, ice_color)

		# Mist rising
		var mist_y_offset = sin(_time * 2.0 + i) * 3
		var mist_pos = pool_pos - Vector2(0, 5 + mist_y_offset) * _camera_zoom
		draw_circle(mist_pos, 6 * _camera_zoom, Color(0.9, 0.95, 1.0, 0.2))

func _draw_small_lakes():
	"""Draw small water bodies (stage 2-3)"""
	var water_color = Color(0.3, 0.5, 0.7, 0.7)

	for i in range(3):
		var lake_angle = i * TAU / 3.0 + 1.0
		var lake_r = 70 + sin(i * 1.7) * 20
		var lake_x = WORLD_CENTER_X + cos(lake_angle) * lake_r
		var lake_y = WORLD_CENTER_Y + sin(lake_angle) * lake_r
		var lake_pos = _iso_transform(lake_x, lake_y, -0.5)
		var lake_size = 20 + sin(i * 2.1) * 8

		_draw_ellipse(lake_pos, lake_size * _camera_zoom, lake_size * 0.5 * _camera_zoom, water_color)

		# Water shimmer
		var shimmer = 0.3 + sin(_time * 1.5 + i * 2) * 0.2
		draw_circle(lake_pos + Vector2(-3, -2) * _camera_zoom, 4 * _camera_zoom, Color(0.8, 0.9, 1.0, shimmer))

func _draw_lakes_and_rivers():
	"""Draw larger water features (stage 4)"""
	var water_color = Color(0.2, 0.45, 0.65, 0.8)

	# Central lake
	var lake_pos = _iso_transform(WORLD_CENTER_X - 50, WORLD_CENTER_Y + 40, -1)
	_draw_ellipse(lake_pos, 35 * _camera_zoom, 20 * _camera_zoom, water_color)

	# River channel
	var river_color = Color(0.25, 0.5, 0.7, 0.6)
	var river_start = _iso_transform(WORLD_CENTER_X - 80, WORLD_CENTER_Y - 60, -0.5)
	var river_mid = _iso_transform(WORLD_CENTER_X - 50, WORLD_CENTER_Y + 40, -0.5)
	var river_end = _iso_transform(WORLD_CENTER_X + 30, WORLD_CENTER_Y + 80, -0.5)

	draw_line(river_start, river_mid, river_color, 8 * _camera_zoom)
	draw_line(river_mid, river_end, river_color, 6 * _camera_zoom)

func _draw_vegetation_patches():
	"""Draw green vegetation (stage 3-4)"""
	var green_light = Color(0.3, 0.6, 0.3, 0.7)
	var green_dark = Color(0.2, 0.45, 0.2, 0.6)

	var num_patches = 6 if _terraforming_stage == 3 else 12

	for i in range(num_patches):
		var patch_angle = i * TAU / num_patches + 0.3
		var patch_r = 50 + sin(i * 2.9) * 35
		var patch_x = WORLD_CENTER_X + cos(patch_angle) * patch_r
		var patch_y = WORLD_CENTER_Y + sin(patch_angle) * patch_r
		var patch_pos = _iso_transform(patch_x, patch_y, 0.3)
		var patch_size = 18 + sin(i * 1.7) * 10

		var patch_color = green_light if i % 2 == 0 else green_dark
		_draw_ellipse(patch_pos, patch_size * _camera_zoom, patch_size * 0.5 * _camera_zoom, patch_color)

func _draw_trees():
	"""Draw trees (stage 4 only)"""
	var trunk_color = Color(0.4, 0.3, 0.2)
	var leaf_color = Color(0.2, 0.5, 0.25)

	for i in range(8):
		var tree_angle = i * TAU / 8.0 + 0.7
		var tree_r = 65 + sin(i * 3.3) * 25
		var tree_x = WORLD_CENTER_X + cos(tree_angle) * tree_r
		var tree_y = WORLD_CENTER_Y + sin(tree_angle) * tree_r

		var tree_height = 8 + sin(i * 2.1) * 4

		# Trunk
		var trunk_base = _iso_transform(tree_x, tree_y, 0)
		var trunk_top = _iso_transform(tree_x, tree_y, tree_height)
		draw_line(trunk_base, trunk_top, trunk_color, 2 * _camera_zoom)

		# Canopy
		var canopy_pos = _iso_transform(tree_x, tree_y, tree_height + 3)
		draw_circle(canopy_pos, (6 + sin(i) * 2) * _camera_zoom, leaf_color)

# Public API for terraforming
func set_terraforming_stage(stage: int):
	_terraforming_stage = clampi(stage, 0, 4)

# =============================================================================
# OBJECT COLLECTION
# =============================================================================

func _collect_all_objects() -> Array:
	var objects = []
	var tier_mult = TIER_MULTIPLIERS.get(_colony_tier, 1.0)

	if PERSPECTIVE_ENABLED:
		return _collect_all_objects_perspective(tier_mult)
	else:
		return _collect_all_objects_isometric(tier_mult)

func _collect_all_objects_perspective(tier_mult: float) -> Array:
	"""Collect objects for perspective rendering"""
	var objects = []

	# Lifepod in center-front
	var lp_height = 15.0 * tier_mult
	var lp_depth = MIN_DEPTH * 0.8  # Slightly in front of closest buildings
	objects.append({
		"type": "lifepod",
		"lateral": 0.0,
		"world_depth": lp_depth,
		"height": lp_height,
		"depth": _get_depth_perspective(lp_depth, lp_height),
		"depth_ratio": lp_depth / MAX_DEPTH,
		"is_perspective": true
	})

	# Buildings
	for building in _buildings:
		var bid = building.get("id", "")
		if not _building_layout.has(bid):
			continue

		var layout = _building_layout[bid]
		var lateral = layout.get("lateral", layout.world_x)
		var world_depth = layout.get("depth", layout.world_y)
		var bh = layout.height
		var depth_ratio = layout.get("depth_ratio", world_depth / MAX_DEPTH)

		# Shadow (on ground, behind building)
		objects.append({
			"type": "shadow",
			"lateral": lateral + bh * 0.15,  # Shadow offset right
			"world_depth": world_depth,
			"height": bh,
			"depth": _get_depth_perspective(world_depth, 0) + 0.001,
			"depth_ratio": depth_ratio,
			"is_perspective": true
		})

		# Building
		objects.append({
			"type": "building",
			"lateral": lateral,
			"world_depth": world_depth,
			"height": bh,
			"building": building,
			"category": layout.category,
			"depth": _get_depth_perspective(world_depth, bh),
			"depth_ratio": depth_ratio,
			"is_perspective": true
		})

	# Colonists - position relative to their buildings
	for colonist in _colonists:
		if not colonist.get("is_alive", true):
			continue
		var cpos = _get_colonist_perspective_pos(colonist)
		objects.append({
			"type": "colonist",
			"lateral": cpos.x,
			"world_depth": cpos.y,
			"depth": _get_depth_perspective(cpos.y, 2),
			"depth_ratio": cpos.y / MAX_DEPTH,
			"is_perspective": true
		})

	# Worker drones - autonomous robots traveling between buildings
	var num_drones = mini(_buildings.size() * 2, 40)  # 2 drones per building, max 40
	for drone_id in range(num_drones):
		var dpos = _get_drone_perspective_pos(drone_id)
		objects.append({
			"type": "drone",
			"lateral": dpos.x,
			"world_depth": dpos.y,
			"depth": _get_depth_perspective(dpos.y, 1),
			"depth_ratio": dpos.y / MAX_DEPTH,
			"drone_id": drone_id,
			"is_perspective": true
		})

	return objects

func _collect_all_objects_isometric(tier_mult: float) -> Array:
	"""Collect objects for isometric rendering (original)"""
	var objects = []

	# Lifepod at center
	var lp_height = 15.0 * tier_mult
	objects.append({
		"type": "lifepod",
		"x": WORLD_CENTER_X,
		"y": WORLD_CENTER_Y,
		"height": lp_height,
		"depth": _get_depth(WORLD_CENTER_X, WORLD_CENTER_Y, lp_height),
		"is_perspective": false
	})

	# Buildings
	for building in _buildings:
		var bid = building.get("id", "")
		if not _building_layout.has(bid):
			continue

		var layout = _building_layout[bid]
		var bx = layout.world_x
		var by = layout.world_y
		var bh = layout.height

		# Tunnel (underground, drawn first)
		objects.append({
			"type": "tunnel",
			"from_x": WORLD_CENTER_X,
			"from_y": WORLD_CENTER_Y,
			"to_x": bx,
			"to_y": by,
			"is_operational": building.get("is_operational", false),
			"depth": _get_depth(bx, by, -5),
			"is_perspective": false
		})

		# Shadow (on ground)
		objects.append({
			"type": "shadow",
			"x": bx,
			"y": by,
			"height": bh,
			"depth": _get_depth(bx, by, 0) + 0.001,
			"is_perspective": false
		})

		# Building
		objects.append({
			"type": "building",
			"x": bx,
			"y": by,
			"height": bh,
			"building": building,
			"category": layout.category,
			"depth": _get_depth(bx, by, bh),
			"is_perspective": false
		})

	# Colonists
	for colonist in _colonists:
		if not colonist.get("is_alive", true):
			continue
		var cpos = _get_colonist_world_pos(colonist)
		objects.append({
			"type": "colonist",
			"x": cpos.x,
			"y": cpos.y,
			"depth": _get_depth(cpos.x, cpos.y, 2),
			"is_perspective": false
		})

	return objects

func _get_drone_perspective_pos(drone_id: int) -> Vector2:
	"""Get drone position - fast workers zipping between buildings"""
	var seed_val = float(hash(str(drone_id))) * 0.0001

	if _building_layout.size() < 2:
		# No buildings, hover near lifepod
		var hover_x = sin(_time * 2.0 + seed_val * 20.0) * 20.0
		var hover_y = MIN_DEPTH * 0.5 + cos(_time * 1.5 + seed_val * 15.0) * 5.0
		return Vector2(hover_x, hover_y)

	# Drones travel between two buildings
	var building_keys = _building_layout.keys()
	var from_idx = drone_id % building_keys.size()
	var to_idx = (drone_id * 7 + 3) % building_keys.size()  # Different destination

	var from_layout = _building_layout[building_keys[from_idx]]
	var to_layout = _building_layout[building_keys[to_idx]]

	var from_pos = Vector2(from_layout.get("lateral", 0.0), from_layout.get("depth", MIN_DEPTH))
	var to_pos = Vector2(to_layout.get("lateral", 0.0), to_layout.get("depth", MIN_DEPTH))

	# Speed scales SMOOTHLY with game speed - always some movement
	# _time_scale is ~14 at slider=1, ~70 at slider=5, ~140 at slider=10
	var speed_scale = clampf(_time_scale / 100.0, 0.1, 1.5)  # Always moving, faster at higher speeds
	var base_speed = 0.25 + seed_val * 0.15
	var phase = fmod(_time * base_speed * speed_scale + seed_val * 10.0, 2.0)

	var t: float
	if phase < 1.0:
		t = phase
	else:
		t = 2.0 - phase

	# Linear movement (drones don't need smooth easing, they're robots)
	var pos = from_pos.lerp(to_pos, t)

	# Hover wobble also slows at low speed
	var wobble = sin(_time * 6.0 * speed_scale + seed_val * 30.0) * 0.5
	return Vector2(pos.x + wobble, clampf(pos.y, MIN_DEPTH * 0.2, MAX_DEPTH * 0.95))

func _get_colonist_perspective_pos(colonist: Dictionary) -> Vector2:
	"""Get colonist position - travels between lifepod and buildings"""
	var colonist_id = colonist.get("id", 0)
	var seed_val = float(hash(str(colonist_id))) * 0.0001

	# Lifepod position (home base)
	var home = Vector2(0.0, MIN_DEPTH * 0.6)

	# Find a destination building for this colonist
	var dest = home
	var assigned_building = colonist.get("assigned_building", "")

	if assigned_building != "" and _building_layout.has(assigned_building):
		# Go to assigned building
		var layout = _building_layout[assigned_building]
		dest = Vector2(layout.get("lateral", 0.0), layout.get("depth", MIN_DEPTH))
	elif _building_layout.size() > 0:
		# Pick a building to visit based on colonist ID and time
		# Visit cycle scales smoothly with game speed
		var visit_speed_scale = clampf(_time_scale / 100.0, 0.1, 1.5)
		var building_keys = _building_layout.keys()
		var visit_cycle = fmod(_time * 0.02 * visit_speed_scale + seed_val * 10.0, float(building_keys.size()))
		var target_idx = int(visit_cycle) % building_keys.size()
		var target_key = building_keys[target_idx]
		var layout = _building_layout[target_key]
		dest = Vector2(layout.get("lateral", 0.0), layout.get("depth", MIN_DEPTH))

	# Animate walking between home and destination
	# Speed scales smoothly with game speed
	var speed_scale = clampf(_time_scale / 100.0, 0.1, 1.5)
	var walk_speed = 0.08 + seed_val * 0.04  # Varied walking speeds
	var walk_phase = fmod(_time * walk_speed * speed_scale + seed_val * 5.0, 2.0)

	# 0-1: walk to destination, 1-2: walk back home
	var t: float
	if walk_phase < 1.0:
		t = walk_phase  # Going to building
	else:
		t = 2.0 - walk_phase  # Coming back

	# Smooth easing for natural movement
	t = t * t * (3.0 - 2.0 * t)  # Smoothstep

	# Interpolate position
	var pos = home.lerp(dest, t)

	# Walking wobble also slows at low speed
	var wobble_x = sin(_time * 3.0 * speed_scale + seed_val * 10.0) * 1.0
	var wobble_y = cos(_time * 3.0 * speed_scale + seed_val * 10.0) * 0.3

	return Vector2(pos.x + wobble_x, clampf(pos.y + wobble_y, MIN_DEPTH * 0.3, MAX_DEPTH * 0.95))

# =============================================================================
# DRAWING FUNCTIONS
# =============================================================================

func _draw_tunnel_obj(obj: Dictionary):
	var from_screen = _iso_transform(obj.from_x, obj.from_y, -3)
	var to_screen = _iso_transform(obj.to_x, obj.to_y, -3)

	# Dark tunnel line
	draw_line(from_screen, to_screen, COLOR_TUNNEL, 5.0 * _camera_zoom)

	# Glow if operational
	if obj.is_operational:
		draw_line(from_screen, to_screen, COLOR_TUNNEL_GLOW, 2.0 * _camera_zoom)

func _draw_shadow_obj(obj: Dictionary):
	var shadow_center: Vector2
	var shadow_rx: float
	var shadow_ry: float

	if obj.get("is_perspective", false):
		# Perspective shadow
		var lateral = obj.get("lateral", 0.0)
		var world_depth = obj.get("world_depth", MIN_DEPTH)
		shadow_center = _perspective_transform(lateral, world_depth, 0)
		var scale = _get_perspective_scale(world_depth)
		shadow_rx = (BUILDING_RADIUS + obj.height * 0.1) * scale / PERSPECTIVE_BASE_SCALE * _camera_zoom * 1.5
		shadow_ry = shadow_rx * 0.4  # Flatter in perspective
	else:
		# Isometric shadow
		var shadow_offset_x = obj.height * 0.2
		var shadow_offset_y = obj.height * 0.1
		shadow_center = _iso_transform(obj.x + shadow_offset_x, obj.y + shadow_offset_y, 0)
		shadow_rx = (BUILDING_RADIUS + obj.height * 0.15) * _camera_zoom
		shadow_ry = shadow_rx * 0.5

	_draw_ellipse(shadow_center, shadow_rx, shadow_ry, COLOR_SHADOW)

func _draw_building_obj(obj: Dictionary):
	var building = obj.building
	var category = obj.category
	var height = obj.height
	var building_type = building.get("type", 0)

	var colors = BUILDING_COLORS.get(category, BUILDING_COLORS["housing"])
	var is_operational = building.get("is_operational", false)
	var progress = building.get("construction_progress", 1.0)

	# Adjust for construction/broken state
	var draw_height = height * progress if progress < 1.0 else height
	var alpha = 0.6 if progress < 1.0 else 1.0

	var top_color = colors.top
	var left_color = colors.left
	var right_color = colors.right

	if not is_operational and progress >= 1.0:
		# Broken - red tint
		top_color = top_color.lerp(Color.RED, 0.4)
		left_color = left_color.lerp(Color.RED, 0.4)
		right_color = right_color.lerp(Color.RED, 0.4)

	if alpha < 1.0:
		top_color.a = alpha
		left_color.a = alpha
		right_color.a = alpha

	var tier = building.get("tier", 1)
	var shape = _get_building_shape(building_type, tier)

	# Perspective mode: use simplified building shapes
	if obj.get("is_perspective", false):
		_draw_building_perspective(obj, shape, draw_height, top_color, left_color, right_color, is_operational, progress)
		return

	# Isometric mode: use original detailed shapes
	var bx = obj.x
	var by = obj.y

	match shape:
		BuildingShape.TOWER:
			_draw_tower(bx, by, BUILDING_RADIUS * 1.8, draw_height, top_color)
		BuildingShape.DOME:
			_draw_dome(bx, by, BUILDING_RADIUS, draw_height * 0.7, top_color)
		BuildingShape.ARCOLOGY:
			_draw_arcology(bx, by, BUILDING_RADIUS * 2.5, draw_height * 0.8)
		BuildingShape.GREENHOUSE:
			_draw_greenhouse(bx, by, BUILDING_RADIUS * 1.2, draw_height * 0.8)
		BuildingShape.SOLAR_ARRAY:
			_draw_solar_array(bx, by, BUILDING_RADIUS * 2.0)
		BuildingShape.REACTOR:
			_draw_reactor(bx, by, draw_height)
		BuildingShape.TERRAFORMING_TOWER:
			_draw_terraforming_tower(bx, by, draw_height * 1.2)
		BuildingShape.LANDING_PAD:
			_draw_landing_pad(bx, by, BUILDING_RADIUS * 2.0)
		BuildingShape.COMMS_TOWER:
			_draw_comms_tower(bx, by, draw_height * 1.5)
		BuildingShape.SPACE_ELEVATOR:
			_draw_space_elevator(bx, by, draw_height * 3.0)
		BuildingShape.MASS_DRIVER:
			_draw_mass_driver(bx, by, BUILDING_RADIUS * 3.0)
		BuildingShape.FUSION_REACTOR:
			_draw_fusion_reactor(bx, by, draw_height * 1.5)
		BuildingShape.STADIUM:
			_draw_stadium(bx, by, BUILDING_RADIUS * 2.5, draw_height * 0.5)
		BuildingShape.PROCEDURAL_SKYSCRAPER:
			var seed_val = hash(building.get("id", "default"))
			_draw_procedural_skyscraper(bx, by, BUILDING_RADIUS * 1.5, draw_height * 1.5, seed_val)
		_:  # HEX_PRISM (default)
			_draw_hex_prism(bx, by, BUILDING_RADIUS, draw_height, top_color, left_color, right_color)

	# Status light on top (skip for solar arrays and megastructures - they have their own visuals)
	var skip_status_light = shape in [BuildingShape.SOLAR_ARRAY, BuildingShape.MASS_DRIVER,
		BuildingShape.FUSION_REACTOR, BuildingShape.SPACE_ELEVATOR]
	if progress >= 1.0 and not skip_status_light:
		var light_z = draw_height + 3
		if shape == BuildingShape.DOME:
			light_z = 4.0 + draw_height * 0.7 + 3  # Dome has base + dome height
		elif shape == BuildingShape.TOWER:
			light_z = draw_height + 12  # Tower has antenna
		var light_pos = _iso_transform(bx, by, light_z)
		var light_color = Color.GREEN if is_operational else Color.RED
		if not is_operational and fmod(_time, 0.8) < 0.4:
			light_color.a = 0.2
		draw_circle(light_pos, 3.0 * _camera_zoom, light_color)

	# RIM LIGHTING - dramatic sun-facing edge highlight
	if progress >= 1.0 and is_operational:
		_draw_rim_light(bx, by, BUILDING_RADIUS, draw_height, shape)

func _draw_building_perspective(obj: Dictionary, shape: BuildingShape, draw_height: float,
		top_color: Color, left_color: Color, right_color: Color,
		is_operational: bool, progress: float):
	"""Draw a building in perspective view - atmospheric haze for distant buildings"""
	var lateral = obj.get("lateral", 0.0)
	var world_depth = obj.get("world_depth", MIN_DEPTH)
	var depth_ratio = obj.get("depth_ratio", 0.0)

	# Get building tier (1-5) for visual upgrades
	var building = obj.get("building", {})
	var tier = clampi(building.get("tier", 1), 1, 5)
	var building_type = building.get("type", 0)

	# Get perspective scale for this depth
	var scale = _get_perspective_scale(world_depth)
	var scale_mult = scale / PERSPECTIVE_BASE_SCALE

	# Atmospheric haze - golden dusty Mars atmosphere
	# Distant buildings blend toward warm horizon color
	var haze_factor = clampf(depth_ratio * 1.3, 0.0, 0.85)
	var sky_palette = TERRAFORM_SKY_COLORS[_terraforming_stage]
	var haze_color = sky_palette.horizon.lerp(Color(0.4, 0.25, 0.18), 0.4)  # Dusty gold

	# Silhouette for very distant buildings (dark against bright sky)
	var silhouette_factor = clampf((depth_ratio - 0.5) * 2.0, 0.0, 0.7)
	var silhouette_color = Color(0.22, 0.18, 0.15)

	# Apply atmospheric effects
	# Near: original colors, Mid: hazed, Far: silhouette
	top_color = top_color.lerp(haze_color, haze_factor * 0.6)
	top_color = top_color.lerp(silhouette_color, silhouette_factor)
	left_color = left_color.lerp(haze_color, haze_factor * 0.7)
	left_color = left_color.lerp(silhouette_color, silhouette_factor * 1.1)
	right_color = right_color.lerp(haze_color, haze_factor * 0.5)
	right_color = right_color.lerp(silhouette_color, silhouette_factor * 0.9)

	# Base and top positions
	var base_pos = _perspective_transform(lateral, world_depth, 0)
	var top_pos = _perspective_transform(lateral, world_depth, draw_height)

	# Width scales with perspective
	var base_width = BUILDING_RADIUS * scale_mult * _camera_zoom * 2.0

	# Skip drawing buildings that are too small (prevents polygon errors)
	if base_width < 4.0 or draw_height * scale_mult < 4.0:
		# Draw simple dot for very distant buildings
		draw_circle(base_pos, maxf(2.0, base_width * 0.3), top_color)
		return

	# Draw different shapes based on building type - now with tier support!
	match shape:
		BuildingShape.ARCOLOGY:
			# Organic curved towers for arcologies (Stockcake reference)
			_draw_perspective_curved_tower(base_pos, top_pos, base_width, draw_height, scale_mult,
				top_color, left_color, right_color, depth_ratio, tier)
		BuildingShape.TOWER:
			_draw_perspective_tower(base_pos, top_pos, base_width, draw_height, scale_mult,
				top_color, left_color, right_color, depth_ratio, tier)
		BuildingShape.GREENHOUSE:
			# Pyramidal tiered greenhouses (Bizley-style)
			_draw_perspective_pyramid(base_pos, base_width, draw_height, scale_mult,
				depth_ratio, tier)
		BuildingShape.DOME:
			_draw_perspective_dome(base_pos, base_width, draw_height * 0.7, scale_mult,
				top_color, depth_ratio, tier, building_type)
		BuildingShape.SOLAR_ARRAY:
			_draw_perspective_solar(base_pos, base_width * 1.5, scale_mult, depth_ratio, tier)
		BuildingShape.REACTOR, BuildingShape.FUSION_REACTOR:
			_draw_perspective_reactor(base_pos, base_width, draw_height, scale_mult,
				top_color, depth_ratio, tier)
		BuildingShape.SPACE_ELEVATOR:
			_draw_perspective_elevator(base_pos, draw_height * 3.0, scale_mult, depth_ratio, tier)
		BuildingShape.TERRAFORMING_TOWER, BuildingShape.COMMS_TOWER:
			_draw_perspective_spire(base_pos, draw_height, scale_mult, top_color, depth_ratio, tier)
		BuildingShape.MASS_DRIVER:
			_draw_perspective_mass_driver(base_pos, base_width * 2.0, scale_mult, depth_ratio, tier)
		BuildingShape.STADIUM:
			_draw_perspective_stadium(base_pos, base_width * 2.5, draw_height * 0.6, scale_mult,
				depth_ratio, tier)
		BuildingShape.PROCEDURAL_SKYSCRAPER:
			var seed_val = hash(building.get("id", "default"))
			_draw_perspective_procedural_skyscraper(base_pos, top_pos, base_width * 1.5, draw_height * 1.5,
				scale_mult, top_color, left_color, right_color, depth_ratio, tier, seed_val)
		_:  # HEX_PRISM, LANDING_PAD, etc
			_draw_perspective_block(base_pos, top_pos, base_width, draw_height, scale_mult,
				top_color, left_color, right_color, tier)

	# ========== UPGRADE CONSTRUCTION VISUALS ==========
	# If building is being upgraded, draw beautiful scaffolding and cranes
	var is_upgrading = building.get("upgrading", false)
	var upgrade_progress_val = building.get("upgrade_progress", 0.0)
	if is_upgrading:
		_draw_upgrade_scaffolding(base_pos, top_pos, base_width, draw_height, scale_mult,
			depth_ratio, upgrade_progress_val)

	# Status light (skip for very distant buildings)
	if progress >= 1.0 and depth_ratio < 0.6:
		var light_pos = _perspective_transform(lateral, world_depth, draw_height + 2)
		var light_color = Color.GREEN if is_operational else Color.RED
		if not is_operational and fmod(_time, 0.8) < 0.4:
			light_color.a = 0.2
		var light_size = maxf(2.0, 3.0 * scale_mult) * _camera_zoom
		draw_circle(light_pos, light_size, light_color)

# =============================================================================
# PERSPECTIVE BUILDING SHAPES
# =============================================================================

func _draw_perspective_block(base_pos: Vector2, top_pos: Vector2, width: float,
		height: float, scale: float, top_c: Color, left_c: Color, right_c: Color, tier: int = 1):
	"""
	Generic building block (used for workshops, storage, medical, etc.)
	Tier affects: size, detail level, window count, structural complexity
	"""
	# Size grows with tier
	var hw = width * (0.45 + tier * 0.02)

	# Warm metallic tint for sci-fi look
	var warm_tint = Color(1.0, 0.95, 0.88)
	var main_color = left_c.lerp(warm_tint, 0.15)
	var light_color = right_c.lerp(warm_tint, 0.25)
	var shadow_color = left_c.darkened(0.15)

	# Left face (shadow side)
	var left_poly = PackedVector2Array([
		base_pos + Vector2(-hw, 0),
		base_pos + Vector2(0, 0),
		top_pos + Vector2(0, 0),
		top_pos + Vector2(-hw * 0.9, 0)
	])
	draw_polygon(left_poly, [shadow_color])

	# Right face (lit side - golden light)
	var right_poly = PackedVector2Array([
		base_pos + Vector2(0, 0),
		base_pos + Vector2(hw, 0),
		top_pos + Vector2(hw * 0.9, 0),
		top_pos + Vector2(0, 0)
	])
	draw_polygon(right_poly, [light_color])

	# Top face
	var depth_offset = height * 0.15 * scale
	var top_poly = PackedVector2Array([
		top_pos + Vector2(-hw * 0.9, 0),
		top_pos + Vector2(hw * 0.9, 0),
		top_pos + Vector2(hw * 0.8, -depth_offset),
		top_pos + Vector2(-hw * 0.8, -depth_offset)
	])
	draw_polygon(top_poly, [top_c.lerp(warm_tint, 0.2)])

	# Golden edge highlights (warm rim lighting)
	var highlight = Color(1.0, 0.92, 0.75, 0.4 + tier * 0.05)
	draw_line(top_pos + Vector2(-hw * 0.9, 0), top_pos + Vector2(hw * 0.9, 0),
		highlight, 2.0 * _camera_zoom)
	draw_line(base_pos + Vector2(hw, 0), top_pos + Vector2(hw * 0.9, 0),
		highlight, 1.5 * _camera_zoom)

	# Structural bands (more at higher tiers)
	if tier >= 2 and scale > 0.3:
		var band_color = shadow_color.darkened(0.1)
		var num_bands = tier - 1
		for b in range(num_bands):
			var t = float(b + 1) / (num_bands + 1)
			var band_y = lerp(base_pos.y, top_pos.y, t)
			var band_hw = lerp(hw, hw * 0.9, t)
			draw_line(Vector2(base_pos.x - band_hw, band_y),
				Vector2(base_pos.x + band_hw, band_y), band_color, 1.5 * _camera_zoom)

	# Window strips (warm interior glow) - more at higher tiers
	var min_height_for_windows = 15.0 - tier * 2  # Lower threshold at higher tiers
	if height > min_height_for_windows and scale > 0.3:
		var window_glow = Color(1.0, 0.9, 0.65, 0.6 + tier * 0.05)
		var num_floors = int(clampf(height / (12.0 - tier), 1, 4 + tier))
		for i in range(num_floors):
			var t = float(i + 0.5) / num_floors
			var floor_y = lerp(base_pos.y - 5, top_pos.y + 5, t)
			var floor_hw = lerp(hw * 0.85, hw * 0.75, t)
			var window_h = maxf(2.0, (2.0 + tier * 0.5) * scale) * _camera_zoom
			draw_rect(Rect2(base_pos.x - floor_hw * 0.6, floor_y - window_h/2,
				floor_hw * 1.2, window_h), window_glow)

	# Roof equipment (tier 3+) - antenna, vents, etc.
	if tier >= 3:
		var equipment_color = shadow_color.lightened(0.1)
		# Small antenna
		var antenna_height = 8.0 * scale * _camera_zoom
		draw_line(top_pos + Vector2(hw * 0.3, -depth_offset),
			top_pos + Vector2(hw * 0.3, -depth_offset - antenna_height),
			equipment_color, 1.5 * _camera_zoom)
		# Vent box
		if tier >= 4:
			draw_rect(Rect2(top_pos.x - hw * 0.4, top_pos.y - depth_offset - 5 * scale * _camera_zoom,
				hw * 0.3, 5 * scale * _camera_zoom), equipment_color)

func _draw_perspective_tower(base_pos: Vector2, top_pos: Vector2, width: float,
		height: float, scale: float, top_c: Color, left_c: Color, right_c: Color,
		depth_ratio: float, tier: int = 1):
	"""
	Tiered apartment/tower progression:
	Tier 1: Low crew quarters (2 floors)
	Tier 2: Apartment unit (3 floors)
	Tier 3: Apartment block (5 floors, balconies)
	Tier 4: High-rise (8 floors, balconies)
	Tier 5: Sky apartments (12 floors, luxury balconies)
	"""
	var upgrade_data = UPGRADE_PATHS.get("apartment_block", {}).get(tier, {})
	var num_floors = upgrade_data.get("floors", 2)
	var has_balconies = upgrade_data.get("balconies", false)

	var hw = width * (0.4 + tier * 0.02)  # Slightly wider at higher tiers

	# Tower colors - metallic silver/white like concept art
	var tower_base = Color(0.75, 0.72, 0.68)  # Warm metallic
	var tower_light = Color(0.85, 0.82, 0.78)
	var tower_dark = Color(0.55, 0.52, 0.48)
	var foundation_color = Color(0.6, 0.58, 0.55)  # Darker foundation

	# TIERED FOUNDATION BASE - stepped platform (like sunset settlement reference)
	var num_tiers = mini(1 + tier / 2, 3)  # 1-3 foundation tiers
	var tier_height = 6.0 * scale * _camera_zoom
	var foundation_top = base_pos.y

	for ft in range(num_tiers):
		var ft_ratio = float(ft) / num_tiers
		var ft_width = hw * (1.4 - ft * 0.15)  # Each tier narrower
		var ft_y = base_pos.y + (num_tiers - ft) * tier_height
		var ft_top_y = base_pos.y + (num_tiers - ft - 1) * tier_height

		# Foundation tier platform
		var ft_color = foundation_color.lerp(tower_dark, ft_ratio * 0.3)
		draw_polygon(PackedVector2Array([
			Vector2(base_pos.x - ft_width, ft_y),
			Vector2(base_pos.x + ft_width, ft_y),
			Vector2(base_pos.x + ft_width * 0.95, ft_top_y),
			Vector2(base_pos.x - ft_width * 0.95, ft_top_y)
		]), [ft_color])

		# Light edge on top of each tier
		if depth_ratio < 0.5:
			draw_line(Vector2(base_pos.x - ft_width * 0.95, ft_top_y),
				Vector2(base_pos.x + ft_width * 0.95, ft_top_y),
				foundation_color.lightened(0.15), 1.5 * _camera_zoom)

		foundation_top = ft_top_y

	# Adjust base_pos for tower to sit on foundation
	var tower_base_pos = Vector2(base_pos.x, foundation_top)

	# Main tower body - tapered elegantly (now sits on foundation)
	var tower_poly = PackedVector2Array([
		tower_base_pos + Vector2(-hw, 0),
		tower_base_pos + Vector2(hw, 0),
		top_pos + Vector2(hw * 0.6, 0),
		top_pos + Vector2(-hw * 0.6, 0)
	])
	draw_polygon(tower_poly, [tower_base])

	# Right face (lit side) - warm golden light
	var right_poly = PackedVector2Array([
		tower_base_pos + Vector2(hw, 0),
		tower_base_pos + Vector2(hw * 0.3, 0),
		top_pos + Vector2(hw * 0.2, 0),
		top_pos + Vector2(hw * 0.6, 0)
	])
	draw_polygon(right_poly, [tower_light])

	# Glowing windows (warm interior light) - number based on tier
	if depth_ratio < 0.55:
		var window_glow = Color(1.0, 0.9, 0.6, 0.9)  # Warm golden light
		var window_bright = Color(1.0, 0.95, 0.8)
		for i in range(num_floors):
			var t = float(i + 0.5) / num_floors
			var floor_y = lerp(tower_base_pos.y - 5, top_pos.y + 5, t)
			var floor_hw = lerp(hw * 0.9, hw * 0.5, t)
			var window_w = maxf(3.0, 6.0 * scale) * _camera_zoom
			var window_h = maxf(2.0, 4.0 * scale) * _camera_zoom

			# Window strip across floor
			draw_rect(Rect2(tower_base_pos.x - floor_hw * 0.7, floor_y - window_h/2,
				floor_hw * 1.4, window_h), window_glow)
			# Bright center
			draw_rect(Rect2(tower_base_pos.x - floor_hw * 0.3, floor_y - window_h/2,
				floor_hw * 0.6, window_h), window_bright)

			# Balconies (tier 3+)
			if has_balconies and i % 2 == 0 and depth_ratio < 0.4:
				var balcony_color = Color(0.5, 0.55, 0.6)
				var balcony_w = floor_hw * 0.3
				var balcony_h = 3.0 * scale * _camera_zoom
				# Left balcony
				draw_rect(Rect2(tower_base_pos.x - floor_hw - balcony_w, floor_y - balcony_h/2,
					balcony_w, balcony_h), balcony_color)
				# Right balcony
				draw_rect(Rect2(tower_base_pos.x + floor_hw, floor_y - balcony_h/2,
					balcony_w, balcony_h), balcony_color)

	# Spire on top - elegant antenna (taller at higher tiers)
	var spire_height = (10.0 + tier * 3.0) * scale * _camera_zoom
	var spire_top = top_pos + Vector2(0, -spire_height)
	draw_line(top_pos, spire_top, tower_light, 2.0 * _camera_zoom)

	# Beacon light at top (pulsing)
	var beacon_pulse = sin(_time * 3.0) * 0.3 + 0.7
	draw_circle(spire_top, 4.0 * scale * _camera_zoom * beacon_pulse, Color(1.0, 0.3, 0.2, beacon_pulse))
	draw_circle(spire_top, 2.0 * scale * _camera_zoom, Color(1.0, 0.5, 0.3))

	# Rim lighting on edges (from tower base, not foundation)
	draw_line(tower_base_pos + Vector2(-hw, 0), top_pos + Vector2(-hw * 0.6, 0),
		Color(1.0, 0.9, 0.7, 0.3), 1.5 * _camera_zoom)
	draw_line(tower_base_pos + Vector2(hw, 0), top_pos + Vector2(hw * 0.6, 0),
		Color(1.0, 0.95, 0.8, 0.4), 2.0 * _camera_zoom)

func _draw_perspective_mega_dome(base_pos: Vector2, width: float, height: float,
		scale: float, depth_ratio: float, tier: int = 5):
	"""
	Mega-dome arcology - massive geodesic dome containing an entire city
	Inspired by the Geodesic Dome City reference image
	Only appears at tier 5 as the ultimate habitat structure
	"""
	var dome_radius = width * (1.5 + tier * 0.2)
	var dome_height = height * scale * _camera_zoom * 4.0

	# Colors - translucent dome with visible city inside
	var dome_glass = Color(0.85, 0.88, 0.92, 0.35)  # Semi-transparent
	var frame_color = Color(0.5, 0.52, 0.55)  # Metallic frame
	var frame_light = Color(0.65, 0.68, 0.72)
	var city_dark = Color(0.35, 0.38, 0.42)  # Buildings inside
	var city_light = Color(0.5, 0.52, 0.55)
	var window_glow = Color(1.0, 0.92, 0.7, 0.8)  # Warm city lights

	# Draw the interior city FIRST (behind the dome glass)
	# Random buildings inside the dome
	var num_buildings = 12 + tier * 3
	var city_buildings: Array = []

	for i in range(num_buildings):
		var angle = float(i) / num_buildings * PI  # Spread across dome
		var dist = randf_range(0.2, 0.85) * dome_radius
		var bx = base_pos.x + cos(angle) * dist - sin(angle) * dist * 0.3
		var building_height = randf_range(15, 45) * scale * _camera_zoom * (1.0 - abs(cos(angle)) * 0.3)
		var by = base_pos.y - building_height

		# Ensure building stays inside dome
		var dome_y_at_x = base_pos.y - dome_height * sin(acos(clampf(abs(bx - base_pos.x) / dome_radius, 0, 1)))
		by = maxf(by, dome_y_at_x + 5)

		city_buildings.append({"x": bx, "y": by, "h": building_height, "w": randf_range(5, 12) * scale * _camera_zoom})

	# Sort buildings by position for overlap
	city_buildings.sort_custom(func(a, b): return a.y > b.y)

	# Draw city buildings
	for b in city_buildings:
		var bw = b.w
		var bh = b.h
		# Building body
		draw_rect(Rect2(b.x - bw/2, b.y, bw, bh), city_dark)
		# Lit side
		draw_rect(Rect2(b.x, b.y, bw/2, bh), city_light)
		# Windows
		if depth_ratio < 0.4:
			var num_floors = int(bh / (8 * scale * _camera_zoom))
			for f in range(mini(num_floors, 4)):
				var wy = b.y + bh * (0.2 + float(f) / num_floors * 0.6)
				draw_rect(Rect2(b.x - bw * 0.3, wy, bw * 0.6, 2 * scale * _camera_zoom), window_glow)

	# Draw geodesic dome shell
	var segments = 16 if depth_ratio < 0.4 else 10
	var dome_points = PackedVector2Array()

	for i in range(segments + 1):
		var angle = PI * float(i) / segments
		var x = base_pos.x + cos(angle) * dome_radius
		var y = base_pos.y - sin(angle) * dome_height
		dome_points.append(Vector2(x, y))

	# Close the dome at ground level
	dome_points.append(base_pos + Vector2(dome_radius, 0))
	dome_points.append(base_pos + Vector2(-dome_radius, 0))

	# Draw dome glass (semi-transparent)
	draw_polygon(dome_points, [dome_glass])

	# Hexagonal geodesic frame pattern
	if depth_ratio < 0.5:
		# Horizontal latitude lines
		var num_bands = 4
		for band in range(1, num_bands):
			var band_t = float(band) / num_bands
			var band_y = base_pos.y - dome_height * band_t
			var band_radius = dome_radius * cos(asin(band_t))

			var band_points = PackedVector2Array()
			for i in range(segments + 1):
				var angle = PI * float(i) / segments
				var r = band_radius * (1.0 if i % 2 == 0 else 0.95)  # Slight hex variation
				band_points.append(Vector2(base_pos.x + cos(angle) * r, band_y + sin(angle * 6) * 2))

			for i in range(band_points.size() - 1):
				draw_line(band_points[i], band_points[i + 1], frame_color, 1.5 * _camera_zoom)

		# Vertical longitude lines (geodesic ribs)
		var num_ribs = 8
		for rib in range(num_ribs):
			var rib_angle = PI * float(rib) / (num_ribs - 1)
			var rib_x = base_pos.x + cos(rib_angle) * dome_radius
			var rib_top = Vector2(base_pos.x, base_pos.y - dome_height)
			var rib_bottom = Vector2(rib_x, base_pos.y)

			# Draw as curve through the dome surface
			var prev_pt = rib_bottom
			for seg in range(1, 6):
				var seg_t = float(seg) / 5
				var seg_angle = rib_angle * (1.0 - seg_t)
				var seg_x = base_pos.x + cos(seg_angle) * dome_radius * cos(seg_t * PI / 2)
				var seg_y = base_pos.y - dome_height * sin(seg_t * PI / 2)
				var pt = Vector2(seg_x, seg_y)
				draw_line(prev_pt, pt, frame_color, 1.5 * _camera_zoom)
				prev_pt = pt

	# Dome outline (structural rim)
	for i in range(segments):
		var angle1 = PI * float(i) / segments
		var angle2 = PI * float(i + 1) / segments
		var p1 = Vector2(base_pos.x + cos(angle1) * dome_radius, base_pos.y - sin(angle1) * dome_height)
		var p2 = Vector2(base_pos.x + cos(angle2) * dome_radius, base_pos.y - sin(angle2) * dome_height)
		draw_line(p1, p2, frame_light, 2.5 * _camera_zoom)

	# Specular highlight on dome (sunlight reflection)
	var highlight_angle = PI * 0.7
	var highlight_pos = Vector2(
		base_pos.x + cos(highlight_angle) * dome_radius * 0.6,
		base_pos.y - sin(highlight_angle) * dome_height * 0.7
	)
	draw_circle(highlight_pos, dome_radius * 0.15, Color(1.0, 0.98, 0.95, 0.2))
	draw_circle(highlight_pos + Vector2(-5, -5), dome_radius * 0.08, Color(1.0, 1.0, 1.0, 0.3))

	# Base foundation ring
	draw_line(base_pos + Vector2(-dome_radius, 0), base_pos + Vector2(dome_radius, 0),
		frame_color.darkened(0.2), 4.0 * _camera_zoom)

	# Entry airlocks (small structures at base)
	var airlock_color = Color(0.45, 0.48, 0.52)
	for side in [-1, 1]:
		var airlock_x = base_pos.x + side * dome_radius * 0.6
		draw_rect(Rect2(airlock_x - 8 * scale * _camera_zoom, base_pos.y - 12 * scale * _camera_zoom,
			16 * scale * _camera_zoom, 12 * scale * _camera_zoom), airlock_color)

func _draw_perspective_curved_tower(base_pos: Vector2, top_pos: Vector2, width: float,
		height: float, scale: float, top_c: Color, left_c: Color, right_c: Color,
		depth_ratio: float, tier: int = 1):
	"""
	Organic curved tower shapes - inspired by Stockcake Mars colony reference
	Teardrop, bulb, and flared cylinder forms that feel more futuristic
	"""
	# At tier 5, arcologies become MEGA-DOMES!
	if tier >= 5:
		_draw_perspective_mega_dome(base_pos, width, height, scale, depth_ratio, tier)
		return

	var hw = width * (0.5 + tier * 0.05)

	# Tower colors - reflective metallic catching orange light
	var tower_body = Color(0.78, 0.74, 0.70)
	var tower_light = Color(0.92, 0.88, 0.82)  # Warm highlight
	var tower_dark = Color(0.52, 0.48, 0.44)
	var glass_band = Color(0.4, 0.6, 0.75, 0.7)  # Blue glass accent

	# Curve profile based on tier - different organic shapes
	var curve_type = tier % 3  # 0=teardrop, 1=bulb, 2=flared

	# Generate curved profile points
	var num_points = 12 if depth_ratio < 0.4 else 8
	var left_profile: Array = []
	var right_profile: Array = []

	for i in range(num_points + 1):
		var t = float(i) / num_points
		var y = lerp(base_pos.y, top_pos.y, t)

		# Calculate width at this height based on curve type
		var width_factor: float
		match curve_type:
			0:  # Teardrop - widest at bottom, tapers to point
				width_factor = 1.0 - pow(t, 1.5)
			1:  # Bulb - narrow base, wide middle, narrow top
				width_factor = sin(t * PI) * 0.8 + 0.2
			2, _:  # Flared - narrow at bottom, widens toward top
				width_factor = 0.4 + t * 0.6 + sin(t * PI) * 0.2

		var w = hw * width_factor
		left_profile.append(Vector2(base_pos.x - w, y))
		right_profile.append(Vector2(base_pos.x + w, y))

	# Build main body polygon
	var body_poly = PackedVector2Array()
	for pt in left_profile:
		body_poly.append(pt)
	for i in range(right_profile.size() - 1, -1, -1):
		body_poly.append(right_profile[i])
	draw_polygon(body_poly, [tower_body])

	# Right side highlight (catching light)
	var highlight_poly = PackedVector2Array()
	for i in range(right_profile.size()):
		var pt = right_profile[i]
		var inner_pt = Vector2(lerp(base_pos.x, pt.x, 0.6), pt.y)
		highlight_poly.append(inner_pt)
	for i in range(right_profile.size() - 1, -1, -1):
		highlight_poly.append(right_profile[i])
	draw_polygon(highlight_poly, [tower_light])

	# Glass band around middle
	if depth_ratio < 0.5:
		var band_start = int(num_points * 0.35)
		var band_end = int(num_points * 0.45)
		for i in range(band_start, band_end):
			var y1 = lerp(base_pos.y, top_pos.y, float(i) / num_points)
			var y2 = lerp(base_pos.y, top_pos.y, float(i + 1) / num_points)
			var w1 = abs(right_profile[i].x - base_pos.x)
			var w2 = abs(right_profile[mini(i + 1, num_points)].x - base_pos.x)
			draw_polygon(PackedVector2Array([
				Vector2(base_pos.x - w1 * 0.95, y1),
				Vector2(base_pos.x + w1 * 0.95, y1),
				Vector2(base_pos.x + w2 * 0.95, y2),
				Vector2(base_pos.x - w2 * 0.95, y2)
			]), [glass_band])

	# Windows scattered on surface
	if depth_ratio < 0.45:
		var window_color = Color(1.0, 0.92, 0.7, 0.9)
		for i in range(3 + tier * 2):
			var wt = 0.2 + float(i) / (3 + tier * 2) * 0.6
			var wy = lerp(base_pos.y, top_pos.y, wt)
			var profile_idx = int(wt * num_points)
			var ww = abs(right_profile[mini(profile_idx, num_points)].x - base_pos.x) * 0.7
			var wx = base_pos.x + (randf_range(-0.5, 0.5) if i > 0 else 0) * ww
			var window_size = maxf(2.0, 4.0 * scale) * _camera_zoom
			draw_circle(Vector2(wx, wy), window_size, window_color)

	# Elegant spire on top
	var spire_h = (8.0 + tier * 4.0) * scale * _camera_zoom
	var spire_top = top_pos + Vector2(0, -spire_h)
	draw_line(top_pos, spire_top, tower_light, 2.5 * _camera_zoom)

	# Beacon
	var pulse = sin(_time * 2.5) * 0.3 + 0.7
	draw_circle(spire_top, 3.5 * scale * _camera_zoom * pulse, Color(0.4, 0.8, 1.0, pulse * 0.8))

	# Curved rim light on left edge
	if depth_ratio < 0.5:
		for i in range(left_profile.size() - 1):
			draw_line(left_profile[i], left_profile[i + 1],
				Color(1.0, 0.95, 0.85, 0.25), 1.5 * _camera_zoom)

func _draw_perspective_dome(base_pos: Vector2, width: float, height: float,
		scale: float, color: Color, depth_ratio: float, tier: int = 1, building_type: int = 0):
	"""
	Tiered dome progression (for hab pods and greenhouses):
	Hab pods: Tier 1=bunker, Tier 2=dome, Tier 3+=multi-dome
	Greenhouses: Tier 1=tent, Tier 2=small dome, Tier 3+=vertical farm sections
	"""
	# Determine which upgrade path to use based on building type
	var upgrade_key = "hab_pod"
	if building_type == _MCSTypes.BuildingType.AGRIDOME or building_type == _MCSTypes.BuildingType.HYDROPONICS or building_type == _MCSTypes.BuildingType.PROTEIN_VATS:
		upgrade_key = "greenhouse"
	var upgrade_data = UPGRADE_PATHS.get(upgrade_key, {}).get(tier, {})

	# Size grows with tier
	var size_mult = upgrade_data.get("height_mult", 1.0) if upgrade_key == "hab_pod" else 1.0
	var radius = width * 0.6 * (0.8 + tier * 0.1)
	var dome_height = height * scale * _camera_zoom * 2.5 * size_mult

	# Skip if too small (prevents degenerate polygon errors)
	if radius < 3.0 or dome_height < 3.0:
		_draw_ellipse(base_pos, radius, dome_height * 0.5, color)
		return

	# For greenhouses: more sections = more domes side by side
	var num_sections = upgrade_data.get("sections", 1) if upgrade_key == "greenhouse" else 1
	var num_domes = upgrade_data.get("domes", 1) if upgrade_key == "hab_pod" else 1
	var has_crops = upgrade_data.get("crops_visible", false)
	var glass_opacity = upgrade_data.get("opacity", 0.4)
	var num_windows = upgrade_data.get("windows", 0)

	# Glass tint - semi-transparent with warm reflection
	var glass_color = Color(0.85, 0.9, 0.95, glass_opacity)
	var frame_color = Color(0.6, 0.55, 0.5)  # Metallic bronze frame
	var interior_green = Color(0.2, 0.5, 0.25, 0.6)  # Visible greenery inside
	var highlight_color = Color(1.0, 0.95, 0.85, 0.3)  # Warm rim light

	# Calculate dome positions for multi-dome configurations
	var dome_positions: Array = []
	if upgrade_key == "greenhouse" and num_sections > 1:
		# Greenhouses: side-by-side sections
		for s in range(num_sections):
			var offset_x = (s - (num_sections - 1) / 2.0) * radius * 1.4
			dome_positions.append(base_pos + Vector2(offset_x, 0))
	elif upgrade_key == "hab_pod" and num_domes > 1:
		# Hab pods: clustered domes
		dome_positions.append(base_pos)  # Central dome
		if num_domes >= 2:
			dome_positions.append(base_pos + Vector2(-radius * 0.9, 3))  # Left
		if num_domes >= 3:
			dome_positions.append(base_pos + Vector2(radius * 0.9, 3))   # Right
	else:
		dome_positions.append(base_pos)

	# Draw each dome
	for dome_idx in range(dome_positions.size()):
		var dome_pos = dome_positions[dome_idx]
		var this_radius = radius * (1.0 if dome_idx == 0 else 0.7)
		var this_height = dome_height * (1.0 if dome_idx == 0 else 0.6)

		var segments = 12 if depth_ratio < 0.5 else 8
		var points = PackedVector2Array()

		for i in range(segments + 1):
			var angle = PI * float(i) / segments
			var x = dome_pos.x + cos(angle) * this_radius
			var y = dome_pos.y - sin(angle) * this_height
			points.append(Vector2(x, y))

		points.append(dome_pos + Vector2(this_radius, 0))
		points.append(dome_pos + Vector2(-this_radius, 0))

		# Interior greenery (for greenhouses with visible crops)
		if has_crops or upgrade_key == "greenhouse":
			var green_points = PackedVector2Array()
			for i in range(segments + 1):
				var angle = PI * float(i) / segments
				var x = dome_pos.x + cos(angle) * this_radius * 0.85
				var y = dome_pos.y - sin(angle) * this_height * 0.7
				green_points.append(Vector2(x, y))
			green_points.append(dome_pos + Vector2(this_radius * 0.85, 0))
			green_points.append(dome_pos + Vector2(-this_radius * 0.85, 0))
			# More vibrant green at higher tiers
			var green_intensity = 0.4 + tier * 0.1
			if _is_valid_polygon(green_points):
				draw_polygon(green_points, [Color(0.2, green_intensity, 0.25, 0.6)])

		# Glass dome (semi-transparent)
		if _is_valid_polygon(points):
			draw_polygon(points, [glass_color])

		# Geodesic frame lines (more detail at higher tiers)
		if depth_ratio < 0.6:
			var num_bands = mini(1 + tier, 4)
			# Horizontal bands
			for band in range(num_bands):
				var band_t = float(band + 1) / (num_bands + 1)
				var band_y = dome_pos.y - this_height * band_t
				var band_radius = this_radius * sqrt(1.0 - band_t * band_t) * 1.1
				var band_points = PackedVector2Array()
				for i in range(9):
					var angle = PI * float(i) / 8.0
					band_points.append(Vector2(dome_pos.x + cos(angle) * band_radius, band_y))
				for i in range(8):
					draw_line(band_points[i], band_points[i + 1], frame_color, 1.5 * _camera_zoom)

			# Vertical ribs (more at higher tiers)
			var num_ribs = 4 + tier
			for i in range(num_ribs):
				var angle = PI * float(i) / (num_ribs - 1)
				var top = Vector2(dome_pos.x, dome_pos.y - this_height)
				var bottom = Vector2(dome_pos.x + cos(angle) * this_radius, dome_pos.y)
				draw_line(bottom, top, frame_color, 1.2 * _camera_zoom)

		# Windows for hab pods (tier 2+)
		if upgrade_key == "hab_pod" and num_windows > 0 and depth_ratio < 0.5:
			var window_color = Color(0.9, 0.85, 0.6, 0.8)  # Warm interior light
			for w in range(mini(num_windows, 4)):
				var window_angle = PI * 0.3 + w * PI * 0.15
				var window_x = dome_pos.x + cos(window_angle) * this_radius * 0.9
				var window_y = dome_pos.y - sin(window_angle) * this_height * 0.6
				var window_size = 3.0 * scale * _camera_zoom
				draw_circle(Vector2(window_x, window_y), window_size, window_color)

		# Highlight arc (rim lighting - warm golden)
		for i in range(segments):
			var angle1 = PI * float(i) / segments
			var angle2 = PI * float(i + 1) / segments
			var p1 = Vector2(dome_pos.x + cos(angle1) * this_radius, dome_pos.y - sin(angle1) * this_height)
			var p2 = Vector2(dome_pos.x + cos(angle2) * this_radius, dome_pos.y - sin(angle2) * this_height)
			var brightness = 0.15 + 0.25 * (1.0 - float(i) / segments)
			draw_line(p1, p2, Color(1.0, 0.9, 0.7, brightness), 2.5 * _camera_zoom)

		# Base ring (metallic)
		draw_line(dome_pos + Vector2(-this_radius, 0), dome_pos + Vector2(this_radius, 0),
			frame_color.darkened(0.2), 3.0 * _camera_zoom)

	# Connecting tunnels between domes (for multi-dome configs)
	if dome_positions.size() > 1 and depth_ratio < 0.5:
		var tunnel_color = Color(0.5, 0.48, 0.45)
		for i in range(dome_positions.size() - 1):
			var tunnel_start = dome_positions[i] + Vector2(radius * 0.4, 0)
			var tunnel_end = dome_positions[i + 1] + Vector2(-radius * 0.4, 0)
			draw_line(tunnel_start, tunnel_end, tunnel_color, 4.0 * _camera_zoom)

func _draw_perspective_pyramid(base_pos: Vector2, width: float, height: float,
		scale: float, depth_ratio: float, tier: int = 1):
	"""
	Pyramidal tiered greenhouse - inspired by Bizley Mars colony art
	Translucent triangular structures with visible terraces of plants inside
	Spire/antenna on top, multiple pyramids at higher tiers
	"""
	# Get upgrade path for greenhouse
	var upgrade_data = UPGRADE_PATHS.get("greenhouse", {}).get(tier, {})
	var num_sections = upgrade_data.get("sections", 1)

	# Colors - translucent white/blue-gray glass (Bizley palette)
	var glass_color = Color(0.88, 0.92, 0.96, 0.45)  # Semi-transparent white-blue
	var glass_highlight = Color(0.95, 0.97, 1.0, 0.3)  # Bright highlight
	var frame_color = Color(0.55, 0.58, 0.62)  # Blue-gray metal frame
	var terrace_green = Color(0.25, 0.55, 0.30, 0.7)  # Visible plants
	var terrace_alt = Color(0.35, 0.50, 0.28, 0.7)  # Alternate plant row
	var spire_color = Color(0.65, 0.68, 0.72)  # Top antenna

	# Pyramid dimensions - grows with tier
	var base_width = width * (0.5 + tier * 0.12)
	var pyramid_height = height * scale * _camera_zoom * (2.0 + tier * 0.5)
	var num_terraces = 2 + tier  # More terraces at higher tiers

	# Calculate positions for multiple pyramids
	var pyramid_positions: Array = []
	if num_sections == 1:
		pyramid_positions.append(base_pos)
	else:
		# Multiple pyramids in a cluster - like Bizley art
		var spacing = base_width * 1.6
		for s in range(num_sections):
			var offset_x = (s - (num_sections - 1) / 2.0) * spacing
			# Stagger depth slightly for visual interest
			var offset_y = abs(s - (num_sections - 1) / 2.0) * 8.0 * scale * _camera_zoom
			pyramid_positions.append(base_pos + Vector2(offset_x, offset_y))

	# Draw each pyramid (back to front for proper overlap)
	pyramid_positions.sort_custom(func(a, b): return a.y < b.y)

	for pyr_idx in range(pyramid_positions.size()):
		var pyr_pos = pyramid_positions[pyr_idx]
		var pyr_width = base_width * (1.0 if pyr_idx == pyramid_positions.size() / 2 else 0.85)
		var pyr_height = pyramid_height * (1.0 if pyr_idx == pyramid_positions.size() / 2 else 0.8)

		# Apex position
		var apex = pyr_pos + Vector2(0, -pyr_height)

		# Draw terraces from bottom to top (visible plant rows)
		for t in range(num_terraces):
			var t_ratio = float(t) / num_terraces
			var t_ratio_next = float(t + 1) / num_terraces

			# Terrace dimensions (narrower as we go up)
			var t_width = pyr_width * (1.0 - t_ratio * 0.9)
			var t_width_next = pyr_width * (1.0 - t_ratio_next * 0.9)
			var t_y = pyr_pos.y - pyr_height * t_ratio
			var t_y_next = pyr_pos.y - pyr_height * t_ratio_next

			# Terrace floor (visible plants)
			var terrace_points = PackedVector2Array([
				Vector2(pyr_pos.x - t_width, t_y),
				Vector2(pyr_pos.x + t_width, t_y),
				Vector2(pyr_pos.x + t_width_next, t_y_next),
				Vector2(pyr_pos.x - t_width_next, t_y_next)
			])
			var plant_color = terrace_green if t % 2 == 0 else terrace_alt
			# Distant pyramids: darker, less saturated
			if depth_ratio > 0.4:
				plant_color = plant_color.darkened(depth_ratio * 0.4)
			draw_polygon(terrace_points, [plant_color])

		# Glass pyramid shell (translucent overlay)
		var left_face = PackedVector2Array([
			pyr_pos + Vector2(-pyr_width, 0),
			apex,
			pyr_pos
		])
		var right_face = PackedVector2Array([
			pyr_pos,
			apex,
			pyr_pos + Vector2(pyr_width, 0)
		])

		# Atmospheric haze for distant pyramids
		var haze_glass = glass_color
		if depth_ratio > 0.3:
			haze_glass = glass_color.lerp(Color(0.7, 0.6, 0.5, 0.4), depth_ratio * 0.5)

		draw_polygon(left_face, [haze_glass.darkened(0.1)])
		draw_polygon(right_face, [haze_glass])

		# Frame lines (structural ribs)
		if depth_ratio < 0.6:
			# Left and right edges
			draw_line(pyr_pos + Vector2(-pyr_width, 0), apex, frame_color, 2.0 * _camera_zoom)
			draw_line(pyr_pos + Vector2(pyr_width, 0), apex, frame_color, 2.0 * _camera_zoom)

			# Horizontal terrace lines
			for t in range(1, num_terraces):
				var t_ratio = float(t) / num_terraces
				var t_width = pyr_width * (1.0 - t_ratio * 0.9)
				var t_y = pyr_pos.y - pyr_height * t_ratio
				draw_line(Vector2(pyr_pos.x - t_width, t_y), Vector2(pyr_pos.x + t_width, t_y),
					frame_color.darkened(0.15), 1.5 * _camera_zoom)

		# Highlight on right edge (warm rim light like in Bizley art)
		if depth_ratio < 0.5:
			draw_line(pyr_pos + Vector2(pyr_width, 0), apex,
				Color(1.0, 0.95, 0.85, 0.35), 3.0 * _camera_zoom)

		# Spire/antenna on top
		var spire_height = pyr_height * 0.15
		draw_line(apex, apex + Vector2(0, -spire_height), spire_color, 2.5 * _camera_zoom)
		# Small light at top
		draw_circle(apex + Vector2(0, -spire_height), 2.5 * _camera_zoom, Color(0.9, 0.95, 1.0, 0.8))

		# Base ring (foundation)
		draw_line(pyr_pos + Vector2(-pyr_width, 0), pyr_pos + Vector2(pyr_width, 0),
			frame_color.darkened(0.25), 3.0 * _camera_zoom)

func _draw_perspective_solar(base_pos: Vector2, width: float, scale: float, depth_ratio: float, tier: int = 1):
	"""
	Tiered solar array progression:
	Tier 1: Single emergency panel flat on ground
	Tier 2: Row of 3 panels on ground
	Tier 3: Elevated on support poles
	Tier 4: Tracking mount that rotates toward sun
	Tier 5: Multi-level solar tower farm
	"""
	# Get upgrade path data
	var upgrade_data = UPGRADE_PATHS.get("solar_array", {}).get(tier, {})
	var num_panels = upgrade_data.get("panels", 1)
	var is_elevated = upgrade_data.get("elevated", false)
	var is_rotating = upgrade_data.get("rotating", false)
	var is_stacked = upgrade_data.get("stacked", false)

	# Colors
	var panel_dark = Color(0.15, 0.20, 0.35)
	var panel_light = Color(0.25, 0.32, 0.48)
	var reflection = Color(1.0, 0.85, 0.55, 0.3)
	var frame_color = Color(0.72, 0.68, 0.62)
	var grid_color = Color(0.35, 0.42, 0.55)

	var base_hw = width * 0.35  # Single panel half-width
	var panel_tilt_base = 6.0 * scale * _camera_zoom

	# Pole height depends on tier
	var pole_height = 0.0
	if is_elevated:
		pole_height = (8.0 + tier * 3.0) * scale * _camera_zoom

	# Rotation animation for tracking arrays (tier 4+)
	var rotation_offset = 0.0
	if is_rotating:
		# Slow tracking motion following the sun
		rotation_offset = sin(_time * 0.3) * 0.2

	# Number of vertical levels for stacked arrays (tier 5)
	var num_levels = 1
	if is_stacked:
		num_levels = 3

	# Draw support structure first
	if is_elevated:
		# Main support pole
		draw_line(base_pos, base_pos + Vector2(0, -pole_height), frame_color, 3.0 * _camera_zoom)
		# Cross-bracing for taller structures
		if tier >= 4:
			var brace_y = pole_height * 0.4
			draw_line(base_pos + Vector2(-8 * scale, 0), base_pos + Vector2(0, -brace_y),
				frame_color.darkened(0.2), 1.5 * _camera_zoom)
			draw_line(base_pos + Vector2(8 * scale, 0), base_pos + Vector2(0, -brace_y),
				frame_color.darkened(0.2), 1.5 * _camera_zoom)

	# Draw each level of panels
	for level in range(num_levels):
		var level_offset = level * pole_height * 0.4 if is_stacked else 0.0
		var level_base = base_pos + Vector2(0, -pole_height - level_offset)

		# Calculate panel layout for this level
		var panels_this_level = num_panels if level == 0 else maxi(num_panels - level * 2, 2)
		var total_width = panels_this_level * base_hw * 2.2
		var start_x = -total_width / 2.0 + base_hw

		# Draw each panel
		for p in range(panels_this_level):
			var panel_x = start_x + p * base_hw * 2.2
			var panel_pos = level_base + Vector2(panel_x, 0)

			# Panel size grows slightly with tier
			var hw = base_hw * (0.8 + tier * 0.1)
			var tilt = panel_tilt_base * (1.0 + rotation_offset)

			# Draw panel with tilt
			var panel_poly = PackedVector2Array([
				panel_pos + Vector2(-hw, 0),
				panel_pos + Vector2(hw, 0),
				panel_pos + Vector2(hw * 0.85, -tilt),
				panel_pos + Vector2(-hw * 0.85, -tilt)
			])
			draw_polygon(panel_poly, [panel_dark])

			# Light reflection on right half
			var reflect_poly = PackedVector2Array([
				panel_pos + Vector2(0, 0),
				panel_pos + Vector2(hw, 0),
				panel_pos + Vector2(hw * 0.85, -tilt),
				panel_pos + Vector2(0, -tilt * 0.95)
			])
			draw_polygon(reflect_poly, [panel_light])

			# Animated sun glint
			var glint_phase = sin(_time * 0.5 + panel_pos.x * 0.1 + p * 0.5) * 0.3 + 0.5
			var glint_x = lerp(panel_pos.x - hw * 0.5, panel_pos.x + hw * 0.5, glint_phase)
			var glint_y = panel_pos.y - tilt * 0.5
			draw_circle(Vector2(glint_x, glint_y), (2.0 + tier * 0.5) * scale * _camera_zoom, reflection)

			# Grid lines (skip for distant or low tier)
			if depth_ratio < 0.65 and tier >= 2:
				var divisions = mini(tier, 4)
				for i in range(divisions):
					var t = float(i + 1) / (divisions + 1)
					var x1 = lerp(panel_pos.x - hw, panel_pos.x + hw, t)
					var x2 = lerp(panel_pos.x - hw * 0.85, panel_pos.x + hw * 0.85, t)
					draw_line(Vector2(x1, panel_pos.y), Vector2(x2, panel_pos.y - tilt),
						grid_color, 0.8 * _camera_zoom)

			# Frame edge highlights
			draw_line(panel_pos + Vector2(-hw, 0), panel_pos + Vector2(-hw * 0.85, -tilt),
				frame_color.lightened(0.2), 1.5 * _camera_zoom)
			draw_line(panel_pos + Vector2(hw, 0), panel_pos + Vector2(hw * 0.85, -tilt),
				frame_color.lightened(0.3), 1.5 * _camera_zoom)

		# Connecting bar for multi-panel arrays
		if panels_this_level > 1 and is_elevated:
			var bar_y = level_base.y
			draw_line(level_base + Vector2(start_x - base_hw, 0),
				level_base + Vector2(-start_x + base_hw, 0),
				frame_color.darkened(0.1), 2.0 * _camera_zoom)

	# Tracking motor housing for tier 4+
	if is_rotating and depth_ratio < 0.5:
		var motor_pos = base_pos + Vector2(0, -pole_height + 3 * scale)
		draw_circle(motor_pos, 4.0 * scale * _camera_zoom, frame_color)
		# Rotating indicator light
		var indicator_pulse = sin(_time * 2.0) * 0.3 + 0.7
		draw_circle(motor_pos + Vector2(3 * scale, 0), 1.5 * scale * _camera_zoom,
			Color(0.3, 1.0, 0.5, indicator_pulse))

func _draw_perspective_reactor(base_pos: Vector2, width: float, height: float,
		scale: float, color: Color, depth_ratio: float, tier: int = 1):
	"""
	Tiered reactor progression:
	Tier 1-2: RTG pod (small, minimal glow)
	Tier 3: Small reactor with one cooling tower
	Tier 4: Power plant with dual cooling towers
	Tier 5: Reactor array with triple cooling towers and plasma arcs
	"""
	var upgrade_data = UPGRADE_PATHS.get("fission_reactor", {}).get(tier, {})
	var cooling_towers = upgrade_data.get("cooling_towers", 0)
	var glow_intensity = upgrade_data.get("glow", 0.3)

	var hw = width * 0.55 * (0.7 + tier * 0.15)  # Grows with tier
	var reactor_height = height * scale * _camera_zoom * (0.8 + tier * 0.2)

	# Metallic containment vessel colors
	var vessel_dark = Color(0.45, 0.42, 0.40)
	var vessel_light = Color(0.65, 0.62, 0.58)
	var vessel_highlight = Color(0.82, 0.78, 0.72)

	# Left side of vessel (shadow)
	var left_body = PackedVector2Array([
		base_pos + Vector2(-hw, 0),
		base_pos + Vector2(0, 0),
		base_pos + Vector2(0, -reactor_height),
		base_pos + Vector2(-hw * 0.75, -reactor_height)
	])
	draw_polygon(left_body, [vessel_dark])

	# Right side of vessel (lit by reactor glow)
	var right_body = PackedVector2Array([
		base_pos + Vector2(0, 0),
		base_pos + Vector2(hw, 0),
		base_pos + Vector2(hw * 0.75, -reactor_height),
		base_pos + Vector2(0, -reactor_height)
	])
	draw_polygon(right_body, [vessel_light])

	# Top dome cap - semicircle arc that closes automatically
	var dome_points = PackedVector2Array()
	var dome_segments = 8
	var dome_radius = hw * 0.75
	var dome_height = 8.0 * scale * _camera_zoom
	for i in range(dome_segments + 1):
		var angle = PI * float(i) / dome_segments
		var x = base_pos.x + cos(angle) * dome_radius
		var y = base_pos.y - reactor_height - sin(angle) * dome_height
		dome_points.append(Vector2(x, y))
	# Polygon auto-closes from last point to first - arc already forms complete dome shape
	if dome_points.size() >= 3:
		draw_polygon(dome_points, [vessel_highlight])

	# Containment rings (industrial details)
	var num_rings = 3
	for i in range(num_rings):
		var t = float(i + 1) / (num_rings + 1)
		var ring_y = base_pos.y - reactor_height * t
		var ring_hw = lerp(hw, hw * 0.75, t)
		draw_line(Vector2(base_pos.x - ring_hw, ring_y),
			Vector2(base_pos.x + ring_hw, ring_y), vessel_dark.darkened(0.2), 3.0 * _camera_zoom)

	# Glowing reactor core (visible through center viewport)
	var core_y = base_pos.y - reactor_height * 0.5
	var core_radius = hw * 0.35
	var glow_pulse = glow_intensity * (0.6 + sin(_time * 3.0) * 0.4)

	# Outer glow (large, soft) - scaled by tier glow
	var outer_glow = Color(0.3, 0.85, 1.0, 0.2 * glow_pulse * (1.0 - depth_ratio * 0.7))
	draw_circle(Vector2(base_pos.x, core_y), core_radius * 2.5, outer_glow)

	# Middle glow
	var mid_glow = Color(0.4, 0.9, 1.0, 0.4 * glow_pulse * (1.0 - depth_ratio * 0.5))
	draw_circle(Vector2(base_pos.x, core_y), core_radius * 1.5, mid_glow)

	# Core glow (bright center)
	var core_glow = Color(0.7, 0.95, 1.0, 0.8 * glow_pulse)
	draw_circle(Vector2(base_pos.x, core_y), core_radius, core_glow)

	# White-hot center (only visible at tier 3+)
	if tier >= 3:
		draw_circle(Vector2(base_pos.x, core_y), core_radius * 0.4, Color(1.0, 1.0, 1.0, glow_pulse))

	# Viewport frame
	var viewport_hw = hw * 0.25
	var viewport_top = core_y - core_radius * 0.8
	var viewport_bot = core_y + core_radius * 0.8
	draw_line(Vector2(base_pos.x - viewport_hw, viewport_top),
		Vector2(base_pos.x - viewport_hw, viewport_bot), vessel_dark, 2.0 * _camera_zoom)
	draw_line(Vector2(base_pos.x + viewport_hw, viewport_top),
		Vector2(base_pos.x + viewport_hw, viewport_bot), vessel_dark, 2.0 * _camera_zoom)

	# Cooling towers (tier 3+)
	if cooling_towers > 0 and depth_ratio < 0.7:
		var tower_spacing = hw * 1.5
		for t in range(cooling_towers):
			var tower_x = base_pos.x + (t - (cooling_towers - 1) / 2.0) * tower_spacing
			var tower_hw = hw * 0.35
			var tower_h = reactor_height * 0.8
			# Cooling tower body (hyperboloid shape)
			var tower_poly = PackedVector2Array([
				Vector2(tower_x - tower_hw, base_pos.y),
				Vector2(tower_x + tower_hw, base_pos.y),
				Vector2(tower_x + tower_hw * 0.6, base_pos.y - tower_h * 0.5),
				Vector2(tower_x + tower_hw * 0.8, base_pos.y - tower_h),
				Vector2(tower_x - tower_hw * 0.8, base_pos.y - tower_h),
				Vector2(tower_x - tower_hw * 0.6, base_pos.y - tower_h * 0.5),
			])
			draw_polygon(tower_poly, [vessel_dark.lightened(0.1)])
			# Steam effect
			var steam_pulse = sin(_time * 2.0 + t) * 0.3 + 0.7
			var steam_color = Color(0.9, 0.95, 1.0, 0.3 * steam_pulse)
			draw_circle(Vector2(tower_x, base_pos.y - tower_h - 5 * scale), 8 * scale * _camera_zoom, steam_color)

	# Energy conduits coming out the sides (tier 2+)
	if depth_ratio < 0.5 and tier >= 2:
		var conduit_color = Color(0.5, 0.75, 0.85, 0.6)
		var conduit_glow = Color(0.4, 0.9, 1.0, 0.3 * glow_pulse)
		# Left conduit
		draw_line(Vector2(base_pos.x - hw, core_y),
			Vector2(base_pos.x - hw * 1.5, core_y - 5), conduit_color, 4.0 * _camera_zoom)
		draw_circle(Vector2(base_pos.x - hw * 1.5, core_y - 5), 5.0 * scale * _camera_zoom, conduit_glow)
		# Right conduit
		draw_line(Vector2(base_pos.x + hw, core_y),
			Vector2(base_pos.x + hw * 1.5, core_y - 5), conduit_color, 4.0 * _camera_zoom)
		draw_circle(Vector2(base_pos.x + hw * 1.5, core_y - 5), 5.0 * scale * _camera_zoom, conduit_glow)

	# Plasma arcs between towers (tier 5 only)
	if tier >= 5 and cooling_towers >= 2 and depth_ratio < 0.5:
		var arc_color = Color(0.5, 0.8, 1.0, sin(_time * 4.0) * 0.3 + 0.5)
		var arc_y = base_pos.y - reactor_height * 0.3
		for t in range(cooling_towers - 1):
			var arc_x1 = base_pos.x + (t - (cooling_towers - 1) / 2.0) * hw * 1.5
			var arc_x2 = base_pos.x + (t + 1 - (cooling_towers - 1) / 2.0) * hw * 1.5
			draw_line(Vector2(arc_x1, arc_y), Vector2(arc_x2, arc_y), arc_color, 2.0 * _camera_zoom)

func _draw_perspective_elevator(base_pos: Vector2, height: float, scale: float, depth_ratio: float, tier: int = 1):
	"""
	Elegant space elevator - Bizley-inspired thin cable ascending to orbit
	Minimal base station, emphasis on the ethereal tether reaching skyward
	"""
	var upgrade_data = UPGRADE_PATHS.get("space_elevator", {}).get(tier, {})
	var cable_opacity = upgrade_data.get("cable_opacity", 0.3) + 0.2
	var num_platforms = upgrade_data.get("platforms", 1)

	# Subtle colors - thin elegant line
	var cable_color = Color(0.75, 0.78, 0.85, cable_opacity)  # Light blue-gray
	var glow_color = Color(0.85, 0.92, 1.0, 0.15)  # Very subtle glow
	var base_color = Color(0.55, 0.58, 0.62)  # Blue-gray metal

	# Elevator reaches all the way to top of screen (into orbit/sky)
	var top_y: float
	if tier <= 2:
		# Under construction - partial height
		var construction_progress = 0.2 + tier * 0.3
		top_y = lerp(base_pos.y - 80, -50.0, construction_progress)
	else:
		top_y = -50.0  # Full height - beyond visible sky

	# THIN elegant cable - the key visual
	var cable_width = (1.0 + tier * 0.3) * _camera_zoom  # Very thin!

	# Subtle atmospheric glow (wider, very faint)
	if tier >= 2:
		var glow_width = cable_width * 6.0
		draw_line(base_pos, Vector2(base_pos.x, top_y), glow_color, glow_width)

	# Main cable - thin elegant line
	draw_line(base_pos, Vector2(base_pos.x, top_y), cable_color, cable_width)

	# Subtle highlight on one side (catching light)
	if tier >= 3:
		draw_line(base_pos + Vector2(1, 0), Vector2(base_pos.x + 1, top_y),
			Color(1.0, 0.98, 0.95, 0.25), cable_width * 0.5)

	# Small, elegant base anchor - pyramidal like other structures
	var base_width = (12.0 + tier * 3.0) * scale * _camera_zoom
	var base_height = (10.0 + tier * 2.0) * scale * _camera_zoom

	# Anchor platform (small pyramid shape)
	draw_polygon(PackedVector2Array([
		base_pos + Vector2(-base_width, 0),
		base_pos + Vector2(base_width, 0),
		base_pos + Vector2(0, -base_height)
	]), [base_color])

	# Frame lines on anchor
	if depth_ratio < 0.5:
		draw_line(base_pos + Vector2(-base_width, 0), base_pos + Vector2(0, -base_height),
			base_color.lightened(0.2), 1.5 * _camera_zoom)
		draw_line(base_pos + Vector2(base_width, 0), base_pos + Vector2(0, -base_height),
			base_color.darkened(0.1), 1.5 * _camera_zoom)

	# Climbing pods - small, subtle, elegant
	if tier >= 3:
		var num_pods = mini(num_platforms, 2)  # Max 2 visible pods
		for pod_idx in range(num_pods):
			var pod_offset = float(pod_idx) / maxf(num_pods, 1)
			var pod_t = fmod(_time * 0.05 + pod_offset, 1.0)
			var pod_y = lerp(base_pos.y - base_height - 10, top_y + 20, pod_t)
			var pod_size = 3.0 * scale * _camera_zoom * (1.0 - pod_t * 0.5)

			# Tiny glowing pod
			draw_circle(Vector2(base_pos.x, pod_y), pod_size * 1.5, Color(0.8, 0.9, 1.0, 0.2))
			draw_circle(Vector2(base_pos.x, pod_y), pod_size, Color(0.7, 0.75, 0.85, 0.8))

	# Small bright point at very top (orbital station - tier 4+)
	if tier >= 4:
		var star_size = (2.0 + tier) * _camera_zoom
		var star_pulse = sin(_time * 1.5) * 0.2 + 0.8
		draw_circle(Vector2(base_pos.x, top_y + 10), star_size * star_pulse,
			Color(0.9, 0.95, 1.0, 0.6))

	# Construction indicator for low tiers (subtle)
	if tier <= 2:
		# Small crane/gantry
		var crane_color = Color(0.6, 0.55, 0.5, 0.5)
		draw_line(base_pos + Vector2(-base_width * 0.8, -base_height * 0.5),
			base_pos + Vector2(-base_width * 0.3, -base_height * 1.5),
			crane_color, 1.5 * _camera_zoom)
		draw_line(base_pos + Vector2(base_width * 0.8, -base_height * 0.5),
			base_pos + Vector2(base_width * 0.3, -base_height * 1.5),
			crane_color, 1.5 * _camera_zoom)

func _draw_perspective_spire(base_pos: Vector2, height: float, scale: float,
		color: Color, depth_ratio: float, tier: int = 1):
	"""
	Tiered communications tower:
	Tier 1: Simple radio mast
	Tier 2: Tower with small dish
	Tier 3: Relay station with multiple dishes
	Tier 4: Comms array (larger dishes)
	Tier 5: Deep space array (massive dishes, constant signal)
	"""
	var upgrade_data = UPGRADE_PATHS.get("communications", {}).get(tier, {})
	var num_dishes = upgrade_data.get("dishes", 0)
	var antenna_mult = upgrade_data.get("antenna_height", 1.0)
	var tower_height = height * scale * _camera_zoom * 1.5 * antenna_mult
	var base_width = (4.0 + tier * 1.0) * scale * _camera_zoom  # Wider at higher tiers

	# Lattice tower
	var top_pos = base_pos + Vector2(0, -tower_height)
	draw_line(base_pos + Vector2(-base_width, 0), top_pos, color.darkened(0.3), 2.0 * _camera_zoom)
	draw_line(base_pos + Vector2(base_width, 0), top_pos, color.darkened(0.3), 2.0 * _camera_zoom)

	# Cross braces - more detail at higher tiers
	if depth_ratio < 0.5:
		var num_braces = 2 + tier
		for i in range(num_braces):
			var t = float(i + 1) / (num_braces + 1)
			var y = lerp(base_pos.y, top_pos.y, t)
			var w = lerp(base_width, base_width * 0.2, t)
			draw_line(Vector2(base_pos.x - w, y), Vector2(base_pos.x + w, y), color.darkened(0.2), 1.0)
			# X-bracing for higher tiers
			if tier >= 3 and i < num_braces - 1:
				var y2 = lerp(base_pos.y, top_pos.y, float(i + 2) / (num_braces + 1))
				var w2 = lerp(base_width, base_width * 0.2, float(i + 2) / (num_braces + 1))
				draw_line(Vector2(base_pos.x - w, y), Vector2(base_pos.x + w2, y2), color.darkened(0.25), 0.8)
				draw_line(Vector2(base_pos.x + w, y), Vector2(base_pos.x - w2, y2), color.darkened(0.25), 0.8)

	# Main antenna/emitter at top
	var dish_radius = (3.0 + tier * 1.5) * scale * _camera_zoom
	draw_circle(top_pos, dish_radius, color)

	# Satellite dishes (based on tier)
	if num_dishes > 0 and depth_ratio < 0.6:
		var dish_color = Color(0.7, 0.75, 0.8)
		for d in range(num_dishes):
			var dish_t = 0.5 + float(d) / (num_dishes + 1) * 0.4
			var dish_y = lerp(base_pos.y, top_pos.y, dish_t)
			var dish_offset = -1 if d % 2 == 0 else 1  # Alternate sides
			var dish_x = base_pos.x + dish_offset * base_width * 1.5
			var this_dish_size = dish_radius * (0.6 + float(tier) * 0.1)
			# Dish shape (arc facing up-right)
			var dish_points = PackedVector2Array()
			for i in range(7):
				var angle = PI * 0.2 + float(i) / 6 * PI * 0.6
				dish_points.append(Vector2(dish_x + cos(angle) * this_dish_size,
					dish_y - sin(angle) * this_dish_size * 0.5))
			for i in range(6):
				draw_line(dish_points[i], dish_points[i + 1], dish_color, 1.5 * _camera_zoom)
			# Dish support arm
			draw_line(Vector2(base_pos.x, dish_y), Vector2(dish_x, dish_y), color.darkened(0.2), 1.0)

	# Signal effect - stronger and more constant at higher tiers
	if depth_ratio < 0.4:
		var signal_speed = 1.5 + tier * 0.5  # Faster pulses at higher tiers
		var pulse = fmod(_time * signal_speed, 2.0) / 2.0
		var signal_alpha = (1.0 - pulse) * (0.3 + tier * 0.1)  # Stronger signal at higher tiers
		var signal_color = Color(0.5, 0.8, 1.0, signal_alpha)
		draw_circle(top_pos, dish_radius * (1.0 + pulse * 3.0), signal_color)
		# Secondary signal for tier 4+
		if tier >= 4:
			var pulse2 = fmod(_time * signal_speed + 0.5, 2.0) / 2.0
			draw_circle(top_pos, dish_radius * (1.0 + pulse2 * 3.0), signal_color.darkened(0.3))

func _draw_perspective_mass_driver(base_pos: Vector2, width: float, scale: float, depth_ratio: float, tier: int = 1):
	"""
	Tiered mass driver progression:
	Tier 1: Launch ramp (basic accelerator)
	Tier 2: Mass driver (functional)
	Tier 3: Cargo launcher (regular launches)
	Tier 4: Mass driver array (high capacity)
	Tier 5: Orbital cannon (continuous ops, massive power)
	"""
	var upgrade_data = UPGRADE_PATHS.get("mass_driver", {}).get(tier, {})
	var rail_length_mult = upgrade_data.get("rail_length", 0.5)
	var power_glow = upgrade_data.get("power_glow", 0.3)

	var rail_color = Color(0.35, 0.38, 0.42)
	var coil_color = Color(0.7, 0.5, 0.2)
	var energy_color = Color(0.3, 0.6, 1.0, power_glow)

	# Rail length scales with tier
	var rail_length = 200.0 * scale * _camera_zoom * rail_length_mult
	var rail_width = (5.0 + tier * 1.5) * scale * _camera_zoom
	var rail_sep = 12.0 * scale * _camera_zoom
	# Angled toward horizon-left for dramatic perspective
	var end_pos = Vector2(base_pos.x - rail_length * 0.4, base_pos.y - rail_length * 0.85)

	# GANTRY SUPPORT STRUCTURE - industrial framework (aerial reference)
	var gantry_color = Color(0.42, 0.40, 0.38)
	var gantry_dark = Color(0.30, 0.28, 0.26)
	var gantry_light = Color(0.55, 0.52, 0.48)
	var num_gantries = 4 + tier  # More gantries at higher tiers

	for i in range(num_gantries):
		var t = float(i) / (num_gantries - 1)
		var gantry_base = base_pos.lerp(end_pos, t)
		var gantry_height = (30.0 + tier * 5.0) * scale * _camera_zoom * (1.0 - t * 0.4)
		var gantry_width = (20.0 + tier * 3.0) * scale * _camera_zoom * (1.0 - t * 0.3)

		# Vertical support pylons
		var left_pylon = gantry_base + Vector2(-gantry_width, 0)
		var right_pylon = gantry_base + Vector2(gantry_width, 0)
		draw_line(left_pylon, left_pylon + Vector2(0, gantry_height), gantry_color, 4.0 * _camera_zoom)
		draw_line(right_pylon, right_pylon + Vector2(0, gantry_height), gantry_color, 4.0 * _camera_zoom)

		# Top crossbeam
		var top_left = left_pylon + Vector2(0, gantry_height)
		var top_right = right_pylon + Vector2(0, gantry_height)
		draw_line(top_left, top_right, gantry_light, 3.0 * _camera_zoom)

		# Diagonal cross-bracing (structural detail)
		if depth_ratio < 0.5:
			var mid_height = gantry_height * 0.5
			# X-brace left
			draw_line(left_pylon + Vector2(0, mid_height * 0.3),
				left_pylon + Vector2(gantry_width * 0.5, mid_height), gantry_dark, 1.5 * _camera_zoom)
			draw_line(left_pylon + Vector2(0, mid_height),
				left_pylon + Vector2(gantry_width * 0.5, mid_height * 0.3), gantry_dark, 1.5 * _camera_zoom)
			# X-brace right
			draw_line(right_pylon + Vector2(0, mid_height * 0.3),
				right_pylon + Vector2(-gantry_width * 0.5, mid_height), gantry_dark, 1.5 * _camera_zoom)
			draw_line(right_pylon + Vector2(0, mid_height),
				right_pylon + Vector2(-gantry_width * 0.5, mid_height * 0.3), gantry_dark, 1.5 * _camera_zoom)

		# Suspended rail support (hangs from top crossbeam)
		var rail_hang_y = gantry_base.y - gantry_height * 0.8
		draw_line(Vector2(gantry_base.x, gantry_base.y - gantry_height),
			Vector2(gantry_base.x, rail_hang_y), gantry_dark, 2.0 * _camera_zoom)

		# Warning light on top (aviation safety)
		if i % 2 == 0:
			var light_pulse = sin(_time * 3.0 + i) * 0.3 + 0.7
			draw_circle(Vector2(gantry_base.x, gantry_base.y - gantry_height - 3),
				2.5 * _camera_zoom * light_pulse, Color(1.0, 0.3, 0.2, light_pulse))

	# Ground-level service track (parallel to main rail)
	var service_color = Color(0.35, 0.33, 0.30)
	draw_line(base_pos + Vector2(-rail_sep * 3, 5), end_pos + Vector2(-rail_sep * 2, 5),
		service_color, 2.0 * _camera_zoom)

	# Twin rails (main electromagnetic track)
	draw_line(base_pos + Vector2(-rail_sep, 0), end_pos + Vector2(-rail_sep * 0.3, 0), rail_color, rail_width)
	draw_line(base_pos + Vector2(rail_sep, 0), end_pos + Vector2(rail_sep * 0.3, 0), rail_color, rail_width)

	# Electromagnetic coils (BIG and glowing)
	var num_coils = 8
	for i in range(num_coils):
		var t = float(i + 1) / (num_coils + 1)
		var coil_pos = base_pos.lerp(end_pos, t)
		var coil_width_outer = width * 0.6 * (1.0 - t * 0.4)
		var coil_width_inner = coil_width_outer * 0.6

		# Coil ring
		draw_circle(coil_pos, coil_width_outer, coil_color)
		draw_circle(coil_pos, coil_width_inner, rail_color.darkened(0.2))

		# Energy glow (animated)
		var coil_phase = fmod(_time * 3.0 + i * 0.3, 1.0)
		var glow_alpha = 0.3 + coil_phase * 0.4
		draw_circle(coil_pos, coil_width_outer * 1.3, Color(energy_color.r, energy_color.g, energy_color.b, glow_alpha * (1.0 - t)))

	# Launch bay at base
	var bay_width = 35.0 * scale * _camera_zoom
	var bay_height = 25.0 * scale * _camera_zoom
	draw_polygon(PackedVector2Array([
		base_pos + Vector2(-bay_width, 0),
		base_pos + Vector2(bay_width, 0),
		base_pos + Vector2(bay_width * 0.7, -bay_height),
		base_pos + Vector2(-bay_width * 0.7, -bay_height)
	]), [Color(0.45, 0.48, 0.52)])

	# PROJECTILE LAUNCH (dramatic!)
	var launch_cycle = fmod(_time * 0.3, 1.0)
	if launch_cycle < 0.4:
		var proj_t = launch_cycle / 0.4
		var proj_pos = base_pos.lerp(end_pos, proj_t)

		# Projectile with trail
		var trail_length = 8
		for trail_i in range(trail_length):
			var trail_t = maxf(0, proj_t - trail_i * 0.03)
			var trail_pos = base_pos.lerp(end_pos, trail_t)
			var trail_alpha = (1.0 - float(trail_i) / trail_length) * (1.0 - proj_t * 0.5)
			var trail_size = (8.0 - trail_i * 0.8) * scale * _camera_zoom
			draw_circle(trail_pos, trail_size, Color(1.0, 0.7, 0.2, trail_alpha))

		# Main projectile (bright!)
		var proj_size = 10.0 * scale * _camera_zoom
		draw_circle(proj_pos, proj_size * 1.5, Color(1.0, 0.9, 0.5, 0.5))
		draw_circle(proj_pos, proj_size, Color(1.0, 0.95, 0.8))

		# Muzzle flash at launch point
		if proj_t < 0.15:
			var flash_size = 30.0 * scale * _camera_zoom * (1.0 - proj_t / 0.15)
			draw_circle(base_pos + Vector2(0, -bay_height), flash_size, Color(1.0, 0.8, 0.4, 0.6))

# =============================================================================
# UPGRADE CONSTRUCTION VISUALS
# =============================================================================

func _draw_upgrade_scaffolding(base_pos: Vector2, top_pos: Vector2, width: float,
		height: float, scale: float, depth_ratio: float, upgrade_progress: float):
	"""
	Beautiful construction scaffolding with animated cranes for upgrading buildings.
	Creates a visual spectacle of a city being built - scaffolding, cranes, workers, sparks.
	"""
	# Skip scaffolding for very distant buildings
	if depth_ratio > 0.65:
		return

	var hw = width * 0.55  # Scaffolding extends beyond building
	var scaffold_height = height * (0.8 + upgrade_progress * 0.4)  # Grows with progress

	# Colors - industrial orange/yellow construction theme
	var scaffold_color = Color(0.75, 0.55, 0.25, 0.7)  # Construction orange
	var crane_color = Color(0.9, 0.65, 0.2, 0.85)  # Bright yellow crane
	var cable_color = Color(0.4, 0.38, 0.35, 0.6)  # Steel cables
	var spark_color = Color(1.0, 0.85, 0.3, 0.9)  # Welding sparks
	var worker_color = Color(1.0, 0.6, 0.2, 0.8)  # Worker vests (orange)

	# ========== SCAFFOLDING FRAMEWORK ==========
	# Vertical poles on corners
	var left_base = base_pos + Vector2(-hw * 1.2, 0)
	var right_base = base_pos + Vector2(hw * 1.2, 0)
	var left_top = Vector2(left_base.x, top_pos.y - scaffold_height * 0.1)
	var right_top = Vector2(right_base.x, top_pos.y - scaffold_height * 0.1)

	# Main vertical supports
	draw_line(left_base, left_top, scaffold_color, 2.5 * _camera_zoom)
	draw_line(right_base, right_top, scaffold_color, 2.5 * _camera_zoom)

	# Horizontal platforms (walkways)
	var num_platforms = int(3 + upgrade_progress * 3)  # More platforms as progress increases
	for i in range(num_platforms):
		var t = float(i + 1) / (num_platforms + 1)
		var platform_y = lerp(base_pos.y, left_top.y, t)
		var platform_color = scaffold_color.lightened(0.1)
		draw_line(Vector2(left_base.x, platform_y), Vector2(right_base.x, platform_y),
			platform_color, 2.0 * _camera_zoom)

		# Diagonal cross-bracing (structural)
		if i > 0:
			var prev_y = lerp(base_pos.y, left_top.y, float(i) / (num_platforms + 1))
			# X-brace left side
			draw_line(Vector2(left_base.x, prev_y), Vector2(left_base.x + hw * 0.3, platform_y),
				scaffold_color.darkened(0.1), 1.0 * _camera_zoom)
			# X-brace right side
			draw_line(Vector2(right_base.x, prev_y), Vector2(right_base.x - hw * 0.3, platform_y),
				scaffold_color.darkened(0.1), 1.0 * _camera_zoom)

		# Workers on platforms (small dots with safety vests)
		if depth_ratio < 0.4 and randf() < 0.3:  # Random workers
			var worker_x = lerp(left_base.x + 5, right_base.x - 5, randf())
			var worker_wobble = sin(_time * 3.0 + i * 2.0) * 2.0
			draw_circle(Vector2(worker_x + worker_wobble, platform_y - 3 * _camera_zoom),
				2.5 * _camera_zoom, worker_color)

	# ========== TOWER CRANE ==========
	# Elegant tower crane on the left side
	var crane_base = left_base + Vector2(-hw * 0.3, 0)
	var crane_tower_height = scaffold_height * 1.3  # Crane is taller than building
	var crane_top = Vector2(crane_base.x, base_pos.y - crane_tower_height)

	# Tower mast (vertical)
	draw_line(crane_base, crane_top, crane_color, 3.0 * _camera_zoom)

	# Counter-jib (short arm behind)
	var counter_length = hw * 0.6
	draw_line(crane_top, crane_top + Vector2(-counter_length, 0), crane_color, 2.5 * _camera_zoom)
	# Counterweight
	draw_rect(Rect2(crane_top.x - counter_length - 8 * _camera_zoom, crane_top.y - 4 * _camera_zoom,
		10 * _camera_zoom, 8 * _camera_zoom), crane_color.darkened(0.2))

	# Main jib (long arm over building)
	var jib_length = hw * 2.5
	var jib_end = crane_top + Vector2(jib_length, -5)  # Slight upward angle
	draw_line(crane_top, jib_end, crane_color, 2.5 * _camera_zoom)

	# Jib support cables (tension wires)
	var tower_apex = crane_top + Vector2(0, -15 * _camera_zoom)
	draw_line(tower_apex, crane_top + Vector2(-counter_length, 0), cable_color, 1.0 * _camera_zoom)
	draw_line(tower_apex, jib_end, cable_color, 1.0 * _camera_zoom)

	# ========== ANIMATED CRANE HOOK ==========
	# Hook moves back and forth along jib
	var hook_phase = fmod(_time * 0.4, 1.0)
	var hook_t = sin(hook_phase * PI) * 0.7 + 0.15  # Oscillates along jib
	var hook_pos = crane_top.lerp(jib_end, hook_t)

	# Hoisting cable
	var load_depth = 30 * _camera_zoom + sin(_time * 1.5) * 10 * _camera_zoom  # Bobbing
	var load_pos = hook_pos + Vector2(0, load_depth)
	draw_line(hook_pos, load_pos, cable_color, 1.5 * _camera_zoom)

	# Hook
	draw_circle(hook_pos, 3 * _camera_zoom, crane_color.lightened(0.1))

	# Load being lifted (construction panel/beam)
	var load_color = Color(0.6, 0.58, 0.55, 0.8)
	draw_rect(Rect2(load_pos.x - 10 * _camera_zoom, load_pos.y,
		20 * _camera_zoom, 5 * _camera_zoom), load_color)

	# ========== WELDING SPARKS ==========
	# Animated sparks at construction point
	var spark_phase = fmod(_time * 2.0, 1.0)
	var active_platform = int(spark_phase * num_platforms)
	if active_platform < num_platforms and depth_ratio < 0.5:
		var spark_y = lerp(base_pos.y, left_top.y, float(active_platform + 1) / (num_platforms + 1))
		var spark_x = lerp(base_pos.x - hw * 0.5, base_pos.x + hw * 0.5, fmod(_time * 1.3, 1.0))

		# Spark burst
		var num_sparks = 6
		for s in range(num_sparks):
			var spark_angle = s * TAU / num_sparks + _time * 5.0
			var spark_dist = (3 + sin(_time * 10 + s) * 2) * _camera_zoom
			var spark_offset = Vector2(cos(spark_angle), sin(spark_angle)) * spark_dist
			var spark_alpha = 0.5 + sin(_time * 15 + s * 3) * 0.3
			draw_circle(Vector2(spark_x, spark_y) + spark_offset, 1.5 * _camera_zoom,
				Color(spark_color.r, spark_color.g, spark_color.b, spark_alpha))

		# Core welding point (bright)
		draw_circle(Vector2(spark_x, spark_y), 3 * _camera_zoom, Color(1.0, 1.0, 0.9, 0.9))

	# ========== PROGRESS INDICATOR ==========
	# Subtle progress bar at base
	var bar_width = hw * 2.0
	var bar_height = 4 * _camera_zoom
	var bar_y = base_pos.y + 8 * _camera_zoom

	# Background
	draw_rect(Rect2(base_pos.x - bar_width / 2, bar_y, bar_width, bar_height),
		Color(0.2, 0.2, 0.2, 0.4))
	# Fill
	draw_rect(Rect2(base_pos.x - bar_width / 2, bar_y, bar_width * upgrade_progress, bar_height),
		Color(0.3, 0.8, 0.4, 0.7))
	# Border
	draw_rect(Rect2(base_pos.x - bar_width / 2, bar_y, bar_width, bar_height),
		Color(0.5, 0.5, 0.5, 0.5), false, 1.0)

# =============================================================================
# LIFEPOD AND COLONIST DRAWING
# =============================================================================

func _draw_lifepod_obj(obj: Dictionary):
	if obj.get("is_perspective", false):
		_draw_lifepod_perspective(obj)
		return

	# Isometric mode
	var lx = obj.x
	var ly = obj.y
	var lh = obj.height

	# Glow on ground
	var glow_center = _iso_transform(lx, ly, 0)
	var glow_pulse = 0.6 + sin(_time * 2.0) * 0.2
	var glow_color = Color(0.4, 0.7, 1.0, glow_pulse * 0.3)
	var glow_r = LIFEPOD_RADIUS * 1.5 * _camera_zoom
	_draw_ellipse(glow_center, glow_r, glow_r * 0.5, glow_color)

	# Hex prism
	_draw_hex_prism(lx, ly, LIFEPOD_RADIUS, lh, COLOR_LIFEPOD_TOP, COLOR_LIFEPOD_LEFT, COLOR_LIFEPOD_RIGHT)

	# Label
	var label_pos = _iso_transform(lx, ly, lh + 2)
	draw_string(ThemeDB.fallback_font, label_pos - Vector2(7, -2) * _camera_zoom, "LP",
		HORIZONTAL_ALIGNMENT_LEFT, -1, int(11 * _camera_zoom), Color.WHITE)

	# Beacon
	var beacon_pos = _iso_transform(lx, ly, lh + 6)
	var beacon_alpha = 0.4 + sin(_time * 3.0) * 0.3
	draw_circle(beacon_pos, 4.0 * _camera_zoom, Color(0.5, 0.8, 1.0, beacon_alpha))

func _draw_lifepod_perspective(obj: Dictionary):
	"""Draw lifepod in perspective view"""
	var lateral = obj.get("lateral", 0.0)
	var world_depth = obj.get("world_depth", MIN_DEPTH)
	var lh = obj.height

	var scale = _get_perspective_scale(world_depth)
	var scale_mult = scale / PERSPECTIVE_BASE_SCALE

	var base_pos = _perspective_transform(lateral, world_depth, 0)
	var top_pos = _perspective_transform(lateral, world_depth, lh)

	# Glow on ground
	var glow_pulse = 0.6 + sin(_time * 2.0) * 0.2
	var glow_color = Color(0.4, 0.7, 1.0, glow_pulse * 0.4)
	var glow_r = LIFEPOD_RADIUS * scale_mult * _camera_zoom * 1.5
	_draw_ellipse(base_pos, glow_r, glow_r * 0.4, glow_color)

	# Draw as perspective block (dome-like)
	var width = LIFEPOD_RADIUS * scale_mult * _camera_zoom * 2.0
	_draw_perspective_dome(base_pos, width, lh, scale_mult, COLOR_LIFEPOD_TOP, 0.0)

	# Label
	draw_string(ThemeDB.fallback_font, top_pos - Vector2(7, 5) * _camera_zoom, "LP",
		HORIZONTAL_ALIGNMENT_LEFT, -1, int(11 * scale_mult * _camera_zoom), Color.WHITE)

	# Beacon
	var beacon_pos = _perspective_transform(lateral, world_depth, lh + 4)
	var beacon_alpha = 0.4 + sin(_time * 3.0) * 0.3
	draw_circle(beacon_pos, 4.0 * scale_mult * _camera_zoom, Color(0.5, 0.8, 1.0, beacon_alpha))

func _draw_colonist_obj(obj: Dictionary):
	# Colonist colors - bright orange suit for visibility against Mars terrain
	var suit_color = Color(1.0, 0.6, 0.2)  # Orange spacesuit
	var helmet_color = Color(0.9, 0.95, 1.0, 0.9)  # White/reflective helmet

	if obj.get("is_perspective", false):
		var lateral = obj.get("lateral", 0.0)
		var world_depth = obj.get("world_depth", MIN_DEPTH)
		var scale = _get_perspective_scale(world_depth)
		var scale_mult = scale / PERSPECTIVE_BASE_SCALE

		var screen_pos = _perspective_transform(lateral, world_depth, 1.5)
		var colonist_size = COLONIST_SIZE * 1.5 * scale_mult * _camera_zoom

		# Shadow first
		var shadow_pos = _perspective_transform(lateral + 0.5, world_depth, 0)
		draw_circle(shadow_pos, colonist_size * 0.8, Color(0, 0, 0, 0.3))

		# Body (orange suit)
		draw_circle(screen_pos, colonist_size, suit_color)
		# Helmet (smaller, on top)
		var head_pos = _perspective_transform(lateral, world_depth, 2.5)
		draw_circle(head_pos, colonist_size * 0.6, helmet_color)
	else:
		var screen_pos = _iso_transform(obj.x, obj.y, 1)
		var colonist_size = COLONIST_SIZE * 1.5 * _camera_zoom
		# Shadow
		var shadow_pos = _iso_transform(obj.x + 1, obj.y + 0.5, 0)
		draw_circle(shadow_pos, colonist_size * 0.8, Color(0, 0, 0, 0.3))
		# Body
		draw_circle(screen_pos, colonist_size, suit_color)
		# Helmet
		var head_pos = _iso_transform(obj.x, obj.y, 2)
		draw_circle(head_pos, colonist_size * 0.6, helmet_color)

func _draw_drone_obj(obj: Dictionary):
	"""Draw a worker drone - small cyan robot with blinking lights"""
	var drone_id = obj.get("drone_id", 0)
	var blink = sin(_time * 8.0 + drone_id * 1.5) * 0.5 + 0.5  # Fast blink

	# Drone colors - cyan/teal mechanical look
	var body_color = Color(0.2, 0.8, 0.9)  # Cyan body
	var light_color = Color(0.4, 1.0, 0.4, blink)  # Green status light, blinking
	var thruster_color = Color(0.3, 0.6, 1.0, 0.6 + blink * 0.3)  # Blue thruster glow

	if obj.get("is_perspective", false):
		var lateral = obj.get("lateral", 0.0)
		var world_depth = obj.get("world_depth", MIN_DEPTH)
		var scale = _get_perspective_scale(world_depth)
		var scale_mult = scale / PERSPECTIVE_BASE_SCALE

		var screen_pos = _perspective_transform(lateral, world_depth, 2)
		var drone_size = 3.0 * scale_mult * _camera_zoom

		# Thruster glow (underneath)
		var thruster_pos = _perspective_transform(lateral, world_depth, 1.5)
		draw_circle(thruster_pos, drone_size * 1.2, thruster_color)

		# Main body (boxy drone shape approximated as circle)
		draw_circle(screen_pos, drone_size, body_color)

		# Status light on top
		var light_pos = _perspective_transform(lateral, world_depth, 2.5)
		draw_circle(light_pos, drone_size * 0.4, light_color)
	else:
		var screen_pos = _iso_transform(obj.x, obj.y, 2)
		var drone_size = 3.0 * _camera_zoom

		# Thruster glow
		var thruster_pos = _iso_transform(obj.x, obj.y, 1.5)
		draw_circle(thruster_pos, drone_size * 1.2, thruster_color)

		# Body
		draw_circle(screen_pos, drone_size, body_color)

		# Light
		var light_pos = _iso_transform(obj.x, obj.y, 2.5)
		draw_circle(light_pos, drone_size * 0.4, light_color)

# =============================================================================
# RIM LIGHTING
# =============================================================================

func _draw_rim_light(cx: float, cy: float, radius: float, height: float, shape: int):
	"""Draw dramatic sun-facing rim lighting on buildings"""
	# Rim light color - warm golden highlight from sun
	var rim_color = Color(1.0, 0.95, 0.85, 0.5)

	# Sun direction (from upper-left in isometric view)
	var sun_offset = radius * 0.8

	# Different shapes need different rim treatments
	match shape:
		BuildingShape.HEX_PRISM, BuildingShape.TOWER:
			# Draw highlight on upper-left edges of hex
			var top_left = _iso_transform(cx - sun_offset, cy - sun_offset * 0.5, height)
			var top_center = _iso_transform(cx, cy, height)
			var mid_left = _iso_transform(cx - sun_offset, cy - sun_offset * 0.5, height * 0.5)
			# Top edge glow
			draw_line(top_left, top_center, rim_color, 2.5 * _camera_zoom)
			# Vertical edge glow
			draw_line(top_left, mid_left, rim_color, 2.0 * _camera_zoom)

		BuildingShape.DOME, BuildingShape.ARCOLOGY:
			# Arc highlight on dome surface
			var arc_start = _iso_transform(cx - radius * 0.7, cy - radius * 0.3, height * 0.6)
			var arc_mid = _iso_transform(cx - radius * 0.3, cy - radius * 0.5, height * 0.85)
			var arc_end = _iso_transform(cx + radius * 0.2, cy - radius * 0.4, height * 0.7)
			draw_line(arc_start, arc_mid, rim_color, 2.5 * _camera_zoom)
			draw_line(arc_mid, arc_end, rim_color, 2.0 * _camera_zoom)

		BuildingShape.GREENHOUSE:
			# Triangular highlight on glass panels
			var panel_top = _iso_transform(cx, cy, height + 3)
			var panel_edge = _iso_transform(cx - radius * 0.8, cy - radius * 0.4, 3)
			draw_line(panel_top, panel_edge, rim_color.lightened(0.2), 2.0 * _camera_zoom)

		BuildingShape.PROCEDURAL_SKYSCRAPER:
			# Multiple edge highlights for skyscrapers (more dramatic)
			var rim_bright = Color(1.0, 0.98, 0.9, 0.7)
			# Main vertical edge
			var sk_top = _iso_transform(cx - radius * 0.6, cy - radius * 0.3, height * 1.5)
			var sk_mid = _iso_transform(cx - radius * 0.6, cy - radius * 0.3, height * 0.75)
			var sk_bot = _iso_transform(cx - radius * 0.6, cy - radius * 0.3, 0)
			draw_line(sk_top, sk_mid, rim_bright, 3.0 * _camera_zoom)
			draw_line(sk_mid, sk_bot, rim_color, 2.0 * _camera_zoom)
			# Top edge
			var sk_top_right = _iso_transform(cx + radius * 0.3, cy - radius * 0.4, height * 1.5)
			draw_line(sk_top, sk_top_right, rim_bright, 2.5 * _camera_zoom)

		BuildingShape.STADIUM:
			# Curved rim on stadium bowl
			for i in range(5):
				var t = float(i) / 4.0
				var ang = -PI * 0.6 + t * PI * 0.4
				var r = radius * 2.2
				var p1 = _iso_transform(cx + cos(ang) * r, cy + sin(ang) * r * 0.5, height * 0.4)
				var p2 = _iso_transform(cx + cos(ang + 0.2) * r, cy + sin(ang + 0.2) * r * 0.5, height * 0.4)
				draw_line(p1, p2, rim_color, 2.0 * _camera_zoom)

# =============================================================================
# HEX PRISM DRAWING
# =============================================================================

func _draw_hex_prism(cx: float, cy: float, radius: float, height: float,
		top_color: Color, left_color: Color, right_color: Color):
	"""Draw a hexagonal prism at world position (cx, cy) with given height"""

	# Generate hex vertices in world space, then transform
	var base_verts: Array[Vector2] = []
	var top_verts: Array[Vector2] = []

	for i in range(6):
		var angle = PI / 6.0 + i * PI / 3.0  # Flat-top hex
		var wx = cx + cos(angle) * radius
		var wy = cy + sin(angle) * radius
		base_verts.append(_iso_transform(wx, wy, 0))
		top_verts.append(_iso_transform(wx, wy, height))

	# Draw sides - we draw all 6 but the back ones get occluded naturally
	# Draw in order: back sides first (indices 2,3,4), then front (5,0,1)
	var side_order = [2, 3, 4, 5, 0, 1]

	for i in side_order:
		var next_i = (i + 1) % 6

		var side_poly = PackedVector2Array([
			base_verts[i], base_verts[next_i],
			top_verts[next_i], top_verts[i]
		])

		# Left-facing sides (indices 2,3,4) get left_color, right-facing get right_color
		var side_color = left_color if i in [2, 3, 4] else right_color
		draw_polygon(side_poly, [side_color])

		# Vertical edge
		draw_line(base_verts[i], top_verts[i], side_color.darkened(0.2), 1.0)

	# Top face
	var top_poly = PackedVector2Array(top_verts)
	draw_polygon(top_poly, [top_color])

	# Top edge highlight
	for i in range(6):
		draw_line(top_verts[i], top_verts[(i + 1) % 6], top_color.lightened(0.25), 1.5)

func _draw_ellipse(center: Vector2, rx: float, ry: float, color: Color):
	var points = PackedVector2Array()
	for i in range(20):
		var angle = i * TAU / 20.0
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	if _is_valid_polygon(points):
		draw_polygon(points, [color])

func _is_valid_polygon(points: PackedVector2Array) -> bool:
	"""Check if polygon points form a valid drawable polygon.
	Returns false if points are degenerate (NaN, too close together, or collinear)."""
	if points.size() < 3:
		return false

	# Check for NaN or INF values and calculate bounding box
	var min_x = INF
	var max_x = -INF
	var min_y = INF
	var max_y = -INF

	for point in points:
		if is_nan(point.x) or is_nan(point.y) or is_inf(point.x) or is_inf(point.y):
			return false
		min_x = minf(min_x, point.x)
		max_x = maxf(max_x, point.x)
		min_y = minf(min_y, point.y)
		max_y = maxf(max_y, point.y)

	# Check if polygon has meaningful area (not too small)
	var width = max_x - min_x
	var height = max_y - min_y
	if width < 1.0 or height < 1.0:
		return false

	# Check for nearly-coincident consecutive points (causes triangulation failures)
	var min_dist_sq = 0.25  # 0.5 pixel minimum distance
	for i in range(points.size()):
		var next_i = (i + 1) % points.size()
		var dist_sq = points[i].distance_squared_to(points[next_i])
		if dist_sq < min_dist_sq:
			return false

	return true

func _safe_draw_polygon(points: PackedVector2Array, colors: PackedColorArray) -> void:
	"""Wrapper that validates polygon before drawing to prevent triangulation errors."""
	if _is_valid_polygon(points):
		draw_polygon(points, colors)

# =============================================================================
# BUILDING SHAPE VARIANTS
# =============================================================================

func _draw_tower(cx: float, cy: float, width: float, height: float,
		base_color: Color, window_color: Color = Color(0.9, 0.95, 1.0, 0.8)):
	"""Draw a rectangular tower with windows - for apartments, factories"""
	var hw = width * 0.5

	# 4 corners at base and top
	var bl = _iso_transform(cx - hw, cy - hw, 0)
	var br = _iso_transform(cx + hw, cy - hw, 0)
	var fl = _iso_transform(cx - hw, cy + hw, 0)
	var fr = _iso_transform(cx + hw, cy + hw, 0)

	var tbl = _iso_transform(cx - hw, cy - hw, height)
	var tbr = _iso_transform(cx + hw, cy - hw, height)
	var tfl = _iso_transform(cx - hw, cy + hw, height)
	var tfr = _iso_transform(cx + hw, cy + hw, height)

	var left_color = base_color.darkened(0.25)
	var right_color = base_color.darkened(0.1)
	var top_color = base_color.lightened(0.1)

	# Left face (back-left to front-left)
	draw_polygon(PackedVector2Array([bl, tbl, tfl, fl]), [left_color])
	# Right face (front-left to front-right)
	draw_polygon(PackedVector2Array([fl, tfl, tfr, fr]), [right_color])
	# Top face
	draw_polygon(PackedVector2Array([tbl, tbr, tfr, tfl]), [top_color])

	# Windows on right face
	var window_rows = int(height / 8.0)
	var window_cols = 2
	for row in range(window_rows):
		for col in range(window_cols):
			var wz = 4 + row * 8.0
			var wy = cy + hw * 0.3 - col * hw * 0.5
			var wx = cx + hw * 0.9
			var win_pos = _iso_transform(wx, wy, wz)
			var win_lit = (hash(row * 10 + col + int(cx)) % 3) != 0  # 66% lit
			var wc = window_color if win_lit else window_color.darkened(0.6)
			draw_rect(Rect2(win_pos - Vector2(2, 3) * _camera_zoom, Vector2(4, 6) * _camera_zoom), wc)

	# Windows on left face
	for row in range(window_rows):
		for col in range(window_cols):
			var wz = 4 + row * 8.0
			var wy = cy - hw * 0.9
			var wx = cx - hw * 0.3 + col * hw * 0.5
			var win_pos = _iso_transform(wx, wy, wz)
			var win_lit = (hash(row * 10 + col + 100 + int(cy)) % 3) != 0
			var wc = window_color if win_lit else window_color.darkened(0.6)
			draw_rect(Rect2(win_pos - Vector2(2, 3) * _camera_zoom, Vector2(4, 6) * _camera_zoom), wc)

	# Roof antenna/spire
	var spire_base = _iso_transform(cx, cy, height)
	var spire_top = _iso_transform(cx, cy, height + 8)
	draw_line(spire_base, spire_top, Color.GRAY, 2.0 * _camera_zoom)
	# Blinking light
	var blink = fmod(_time, 1.0) < 0.5
	if blink:
		draw_circle(spire_top, 3 * _camera_zoom, Color.RED)

func _draw_dome(cx: float, cy: float, radius: float, height: float, base_color: Color):
	"""Draw a hemispherical dome - for arcologies, research centers"""
	var dome_color = Color(0.4, 0.7, 0.9, 0.6)  # Translucent cyan
	var frame_color = base_color.lightened(0.2)

	# Draw base hex
	_draw_hex_prism(cx, cy, radius, 4.0, base_color, base_color.darkened(0.2), base_color.darkened(0.1))

	# INTERIOR GLOW - warm light from inside the dome
	var glow_intensity = 0.25 + sin(_time * 1.5) * 0.08
	var interior_glow = Color(1.0, 0.95, 0.85, glow_intensity)
	var glow_pos = _iso_transform(cx, cy, 4.0 + height * 0.4)
	draw_circle(glow_pos, radius * 0.7 * _camera_zoom, interior_glow)

	# WINDOW LIGHTS - small bright dots around the dome base
	for i in range(6):
		var win_angle = i * TAU / 6.0
		var win_x = cx + cos(win_angle) * radius * 0.85
		var win_y = cy + sin(win_angle) * radius * 0.85
		var win_pos = _iso_transform(win_x, win_y, 6.0)
		# Twinkling effect
		var twinkle = 0.6 + sin(_time * 3.0 + i * 1.2) * 0.3
		draw_circle(win_pos, 3 * _camera_zoom, Color(1.0, 0.95, 0.8, twinkle))

	# Draw dome as series of rings
	var rings = 6
	for ring in range(rings):
		var t = float(ring) / rings
		var ring_z = 4.0 + sin(t * PI * 0.5) * height
		var ring_r = radius * cos(t * PI * 0.5)

		var points = PackedVector2Array()
		for i in range(16):
			var angle = i * TAU / 16.0
			var wx = cx + cos(angle) * ring_r
			var wy = cy + sin(angle) * ring_r
			points.append(_iso_transform(wx, wy, ring_z))

		# Draw ring outline
		for i in range(16):
			draw_line(points[i], points[(i + 1) % 16], frame_color, 1.5 * _camera_zoom)

	# Dome fill (top portion)
	var apex = _iso_transform(cx, cy, 4.0 + height)
	draw_circle(apex, radius * 0.3 * _camera_zoom, dome_color)

	# Apex light - brighter pulsing
	var glow_alpha = 0.6 + sin(_time * 2.0) * 0.3
	draw_circle(apex, 6 * _camera_zoom, Color(0.5, 0.9, 1.0, glow_alpha))
	draw_circle(apex, 3 * _camera_zoom, Color(0.8, 1.0, 1.0, glow_alpha * 0.8))

func _draw_space_elevator(cx: float, cy: float, height: float):
	"""Draw space elevator - THE CENTERPIECE megastructure"""
	var base_color = Color(0.3, 0.4, 0.5)

	# Hexagonal base platform
	_draw_hex_prism(cx, cy, 25.0, 8.0, base_color.lightened(0.1), base_color.darkened(0.2), base_color)

	# Three cables going up
	var cable_offsets = [Vector2(-8, 0), Vector2(4, -7), Vector2(4, 7)]
	var cable_colors = [Color(0.6, 0.8, 1.0), Color(0.5, 0.7, 0.9), Color(0.7, 0.85, 1.0)]

	for i in range(3):
		var offset = cable_offsets[i]
		var color = cable_colors[i]

		# Cable with wave motion
		var prev_pos = _iso_transform(cx + offset.x, cy + offset.y, 8.0)
		var segments = 20
		for seg in range(1, segments + 1):
			var t = float(seg) / segments
			var z = 8.0 + t * height
			var wave = sin(_time * 3.0 + t * 8.0 + i * 2.0) * 2.0
			var wx = cx + offset.x + wave * (1.0 - t)  # Wave diminishes with height
			var wy = cy + offset.y
			var pos = _iso_transform(wx, wy, z)
			draw_line(prev_pos, pos, color, (3.0 - t * 2.0) * _camera_zoom)
			prev_pos = pos

		# Energy pulses traveling up
		var pulse_t = fmod(_time * 0.5 + i * 0.33, 1.0)
		var pulse_z = 8.0 + pulse_t * height
		var pulse_pos = _iso_transform(cx + offset.x, cy + offset.y, pulse_z)
		draw_circle(pulse_pos, (6 - pulse_t * 4) * _camera_zoom, Color(0.5, 0.9, 1.0, 1.0 - pulse_t))

	# Counterweight at top
	var top_pos = _iso_transform(cx, cy, 8.0 + height)
	draw_circle(top_pos, 12 * _camera_zoom, Color(0.4, 0.5, 0.6))
	draw_circle(top_pos, 8 * _camera_zoom, Color(0.5, 0.6, 0.7))

	# Glow ring at base
	var base_center = _iso_transform(cx, cy, 8.0)
	var glow_alpha = 0.3 + sin(_time * 4.0) * 0.2
	_draw_ellipse(base_center, 30 * _camera_zoom, 15 * _camera_zoom, Color(0.3, 0.6, 1.0, glow_alpha))

func _draw_solar_array(cx: float, cy: float, width: float):
	"""Draw flat solar panel array"""
	var panel_color = Color(0.15, 0.2, 0.35)
	var frame_color = Color(0.4, 0.45, 0.5)
	var highlight = Color(0.3, 0.5, 0.8, 0.3)

	# Low base
	_draw_hex_prism(cx, cy, width * 0.3, 2.0, frame_color, frame_color.darkened(0.2), frame_color)

	# Angled panels (2x2 grid)
	var panel_w = width * 0.8
	var panel_h = 3.0  # Slight tilt

	for px in [-0.5, 0.5]:
		for py in [-0.5, 0.5]:
			var pcx = cx + px * panel_w * 0.6
			var pcy = cy + py * panel_w * 0.6

			var p1 = _iso_transform(pcx - panel_w * 0.25, pcy - panel_w * 0.25, 2.0)
			var p2 = _iso_transform(pcx + panel_w * 0.25, pcy - panel_w * 0.25, 2.0 + panel_h)
			var p3 = _iso_transform(pcx + panel_w * 0.25, pcy + panel_w * 0.25, 2.0 + panel_h)
			var p4 = _iso_transform(pcx - panel_w * 0.25, pcy + panel_w * 0.25, 2.0)

			draw_polygon(PackedVector2Array([p1, p2, p3, p4]), [panel_color])
			# Grid lines
			draw_line(p1, p3, frame_color, 1.0)
			draw_line(p2, p4, frame_color, 1.0)
			# Sun reflection
			var reflect_pos = (p1 + p3) * 0.5
			draw_circle(reflect_pos, 4 * _camera_zoom, highlight)

func _draw_terraforming_tower(cx: float, cy: float, height: float):
	"""Draw atmospheric processor with vapor plume"""
	var tower_color = Color(0.5, 0.55, 0.6)

	# Tapered tower body
	var base_r = 15.0
	var top_r = 8.0
	var segments = 8

	for seg in range(segments):
		var t1 = float(seg) / segments
		var t2 = float(seg + 1) / segments
		var r1 = lerp(base_r, top_r, t1)
		var r2 = lerp(base_r, top_r, t2)
		var z1 = t1 * height
		var z2 = t2 * height

		# Draw ring segment
		for i in range(6):
			var angle1 = i * TAU / 6.0
			var angle2 = (i + 1) * TAU / 6.0

			var b1 = _iso_transform(cx + cos(angle1) * r1, cy + sin(angle1) * r1, z1)
			var b2 = _iso_transform(cx + cos(angle2) * r1, cy + sin(angle2) * r1, z1)
			var t1p = _iso_transform(cx + cos(angle1) * r2, cy + sin(angle1) * r2, z2)
			var t2p = _iso_transform(cx + cos(angle2) * r2, cy + sin(angle2) * r2, z2)

			var shade = 0.8 + 0.2 * cos(angle1)  # Simple shading
			draw_polygon(PackedVector2Array([b1, b2, t2p, t1p]), [tower_color * shade])

	# Processing rings
	for ring_z in [height * 0.3, height * 0.6, height * 0.9]:
		var ring_r = lerp(base_r, top_r, ring_z / height) + 3.0
		var ring_center = _iso_transform(cx, cy, ring_z)
		_draw_ellipse(ring_center, ring_r * _camera_zoom, ring_r * 0.5 * _camera_zoom, Color(0.6, 0.65, 0.7))

	# Vapor plume
	var plume_particles = 8
	for i in range(plume_particles):
		var pt = fmod(_time * 0.3 + i * 0.125, 1.0)
		var pz = height + pt * 40.0
		var spread = pt * 15.0
		var px = cx + sin(_time + i * 2.0) * spread
		var py = cy + cos(_time * 0.7 + i * 1.5) * spread
		var ppos = _iso_transform(px, py, pz)
		var palpha = (1.0 - pt) * 0.4
		draw_circle(ppos, (8 + pt * 12) * _camera_zoom, Color(0.8, 0.85, 0.9, palpha))

func _draw_arcology(cx: float, cy: float, radius: float, height: float):
	"""Draw MASSIVE arcology - a city under a giant dome"""
	# Multi-level base structure
	var levels = 4
	for level in range(levels):
		var level_r = radius * (1.0 - level * 0.15)
		var level_z = level * 12.0
		var level_h = 10.0
		var shade = 0.6 + level * 0.1
		var level_color = Color(0.5 * shade, 0.55 * shade, 0.65 * shade)
		_draw_hex_prism(cx, cy, level_r, level_h, level_color.lightened(0.1), level_color.darkened(0.1), level_color)
		# Windows on each level
		for i in range(12):
			var angle = i * TAU / 12.0
			var wx = cx + cos(angle) * level_r * 0.85
			var wy = cy + sin(angle) * level_r * 0.85
			var wpos = _iso_transform(wx, wy, level_z + 5)
			var lit = (hash(level * 20 + i) % 3) != 0
			var wcolor = Color(1.0, 0.95, 0.7, 0.9) if lit else Color(0.2, 0.25, 0.3, 0.6)
			draw_circle(wpos, 3 * _camera_zoom, wcolor)

	# Giant transparent dome over everything
	var dome_base_z = levels * 12.0
	var dome_color = Color(0.4, 0.7, 0.9, 0.25)
	var frame_color = Color(0.6, 0.8, 1.0, 0.6)

	# Dome rings
	var dome_rings = 8
	for ring in range(dome_rings):
		var t = float(ring) / dome_rings
		var ring_z = dome_base_z + sin(t * PI * 0.5) * height
		var ring_r = radius * cos(t * PI * 0.5)

		var points = PackedVector2Array()
		for i in range(24):
			var angle = i * TAU / 24.0
			points.append(_iso_transform(cx + cos(angle) * ring_r, cy + sin(angle) * ring_r, ring_z))

		for i in range(24):
			draw_line(points[i], points[(i + 1) % 24], frame_color, 1.5 * _camera_zoom)

	# Vertical dome struts
	for i in range(8):
		var angle = i * TAU / 8.0
		var prev_pos = _iso_transform(cx + cos(angle) * radius, cy + sin(angle) * radius, dome_base_z)
		for seg in range(1, dome_rings + 1):
			var t = float(seg) / dome_rings
			var seg_z = dome_base_z + sin(t * PI * 0.5) * height
			var seg_r = radius * cos(t * PI * 0.5)
			var pos = _iso_transform(cx + cos(angle) * seg_r, cy + sin(angle) * seg_r, seg_z)
			draw_line(prev_pos, pos, frame_color, 2.0 * _camera_zoom)
			prev_pos = pos

	# Glowing apex
	var apex = _iso_transform(cx, cy, dome_base_z + height)
	var glow_pulse = 0.5 + sin(_time * 2.0) * 0.3
	draw_circle(apex, 12 * _camera_zoom, Color(0.5, 0.8, 1.0, glow_pulse * 0.5))
	draw_circle(apex, 6 * _camera_zoom, Color(0.7, 0.9, 1.0, glow_pulse))

func _draw_greenhouse(cx: float, cy: float, radius: float, height: float):
	"""Draw glass greenhouse dome with visible plants"""
	var glass_color = Color(0.5, 0.8, 0.5, 0.35)
	var frame_color = Color(0.4, 0.5, 0.4)
	var plant_green = Color(0.2, 0.7, 0.3)

	# Low base
	_draw_hex_prism(cx, cy, radius, 3.0, frame_color, frame_color.darkened(0.2), frame_color)

	# Glass dome panels
	var panels = 6
	for i in range(panels):
		var angle1 = i * TAU / panels
		var angle2 = (i + 1) * TAU / panels
		var mid_angle = (angle1 + angle2) * 0.5

		# Panel corners
		var b1 = _iso_transform(cx + cos(angle1) * radius, cy + sin(angle1) * radius, 3.0)
		var b2 = _iso_transform(cx + cos(angle2) * radius, cy + sin(angle2) * radius, 3.0)
		var apex = _iso_transform(cx, cy, 3.0 + height)

		# Draw triangular glass panel
		draw_polygon(PackedVector2Array([b1, b2, apex]), [glass_color])
		draw_line(b1, apex, frame_color, 2.0 * _camera_zoom)
		draw_line(b2, apex, frame_color, 2.0 * _camera_zoom)

	# Plants inside (visible through glass) - deterministic positions
	for i in range(12):
		# Deterministic spiral layout for plant positions
		var angle = i * TAU / 12.0 + 0.3
		var dist = radius * 0.35 * (0.5 + float(i % 3) * 0.25)
		var px = cx + cos(angle) * dist
		var py = cy + sin(angle) * dist
		# Varied heights based on index
		var plant_h = 5.0 + sin(i * 0.9) * 4.0
		var plant_pos = _iso_transform(px, py, 3.0 + plant_h)
		# Bright green gradient
		var plant_color = plant_green.lerp(Color(0.2, 0.9, 0.3), float(i) / 12.0)
		# Larger, more visible plants
		var plant_size = (5 + sin(i * 1.5) * 2) * _camera_zoom
		draw_circle(plant_pos, plant_size, plant_color)
		# Add stem for taller plants
		if plant_h > 6:
			var stem_base = _iso_transform(px, py, 3.0)
			draw_line(stem_base, plant_pos, Color(0.15, 0.5, 0.2, 0.7), 1.5 * _camera_zoom)

	# Sunlight reflection on glass
	var sun_pos = _iso_transform(cx - radius * 0.3, cy - radius * 0.3, 3.0 + height * 0.6)
	draw_circle(sun_pos, 8 * _camera_zoom, Color(1.0, 1.0, 0.9, 0.4))

func _draw_reactor(cx: float, cy: float, height: float):
	"""Draw fission/fusion reactor with glowing core"""
	var shell_color = Color(0.4, 0.45, 0.5)
	var core_color = Color(0.3, 0.8, 1.0)
	var warning_color = Color(1.0, 0.8, 0.0)

	# Containment building (cylindrical)
	var base_r = 18.0
	_draw_hex_prism(cx, cy, base_r, height * 0.7, shell_color, shell_color.darkened(0.2), shell_color.darkened(0.1))

	# Cooling towers (two smaller cylinders)
	for offset in [Vector2(-15, -10), Vector2(15, 10)]:
		var tx = cx + offset.x
		var ty = cy + offset.y
		_draw_hex_prism(tx, ty, 8.0, height * 0.5, shell_color.darkened(0.1), shell_color.darkened(0.3), shell_color.darkened(0.2))
		# Steam from cooling towers
		for i in range(3):
			var st = fmod(_time * 0.4 + i * 0.33, 1.0)
			var steam_z = height * 0.5 + st * 20.0
			var steam_pos = _iso_transform(tx + sin(_time + i) * st * 5, ty, steam_z)
			draw_circle(steam_pos, (4 + st * 6) * _camera_zoom, Color(0.9, 0.92, 0.95, (1.0 - st) * 0.4))

	# Glowing core visible through top
	var core_z = height * 0.4
	var core_pos = _iso_transform(cx, cy, core_z)
	var pulse = 0.6 + sin(_time * 4.0) * 0.4
	draw_circle(core_pos, 14 * _camera_zoom, Color(core_color.r, core_color.g, core_color.b, pulse * 0.3))
	draw_circle(core_pos, 8 * _camera_zoom, Color(core_color.r, core_color.g, core_color.b, pulse * 0.6))
	draw_circle(core_pos, 4 * _camera_zoom, Color(1.0, 1.0, 1.0, pulse))

	# Energy arcs (occasional)
	if fmod(_time, 2.0) < 0.3:
		var arc_angle = _time * 5.0
		var arc_end = _iso_transform(cx + cos(arc_angle) * 12, cy + sin(arc_angle) * 12, core_z + 5)
		draw_line(core_pos, arc_end, core_color, 2.0 * _camera_zoom)

	# Warning stripes on base
	var stripe_pos = _iso_transform(cx, cy + base_r * 0.8, height * 0.35)
	draw_circle(stripe_pos, 5 * _camera_zoom, warning_color)

func _draw_landing_pad(cx: float, cy: float, width: float):
	"""Draw landing pad with rocket/ship"""
	var pad_color = Color(0.35, 0.38, 0.4)
	var marking_color = Color(0.9, 0.9, 0.2)
	var ship_color = Color(0.7, 0.72, 0.75)

	# Flat hexagonal pad
	_draw_hex_prism(cx, cy, width, 2.0, pad_color.lightened(0.1), pad_color.darkened(0.1), pad_color)

	# Landing circle markings
	var circle_center = _iso_transform(cx, cy, 2.1)
	_draw_ellipse(circle_center, width * 0.7 * _camera_zoom, width * 0.35 * _camera_zoom, Color(marking_color.r, marking_color.g, marking_color.b, 0.5))
	_draw_ellipse(circle_center, width * 0.5 * _camera_zoom, width * 0.25 * _camera_zoom, Color(marking_color.r, marking_color.g, marking_color.b, 0.3))

	# "H" marking
	var h_pos = _iso_transform(cx, cy, 2.2)
	draw_string(ThemeDB.fallback_font, h_pos - Vector2(6, 4) * _camera_zoom, "H", HORIZONTAL_ALIGNMENT_LEFT, -1, int(16 * _camera_zoom), marking_color)

	# Landed rocket/ship (sometimes)
	var has_ship = sin(_time * 0.1 + cx * 0.01) > -0.3  # Ship present most of time
	if has_ship:
		# Rocket body
		var rocket_h = 35.0
		var rocket_r = 6.0

		# Main body (tapered cylinder approximated with hex)
		for seg in range(4):
			var t1 = float(seg) / 4
			var t2 = float(seg + 1) / 4
			var r1 = rocket_r * (1.0 - t1 * 0.3)
			var r2 = rocket_r * (1.0 - t2 * 0.3)
			var z1 = 2.0 + t1 * rocket_h
			var z2 = 2.0 + t2 * rocket_h

			for i in range(6):
				var angle1 = i * TAU / 6.0
				var angle2 = (i + 1) * TAU / 6.0
				var b1 = _iso_transform(cx + cos(angle1) * r1, cy + sin(angle1) * r1, z1)
				var b2 = _iso_transform(cx + cos(angle2) * r1, cy + sin(angle2) * r1, z1)
				var t1p = _iso_transform(cx + cos(angle1) * r2, cy + sin(angle1) * r2, z2)
				var t2p = _iso_transform(cx + cos(angle2) * r2, cy + sin(angle2) * r2, z2)
				var shade = ship_color * (0.8 + 0.2 * cos(angle1))
				draw_polygon(PackedVector2Array([b1, b2, t2p, t1p]), [shade])

		# Nose cone
		var nose_base = _iso_transform(cx, cy, 2.0 + rocket_h)
		var nose_tip = _iso_transform(cx, cy, 2.0 + rocket_h + 10)
		for i in range(6):
			var angle = i * TAU / 6.0
			var base_pt = _iso_transform(cx + cos(angle) * rocket_r * 0.7, cy + sin(angle) * rocket_r * 0.7, 2.0 + rocket_h)
			draw_polygon(PackedVector2Array([base_pt, _iso_transform(cx + cos(angle + TAU/6) * rocket_r * 0.7, cy + sin(angle + TAU/6) * rocket_r * 0.7, 2.0 + rocket_h), nose_tip]), [Color(0.85, 0.2, 0.2)])

		# Engine glow (if recently landed - pulsing)
		var engine_glow = max(0, sin(_time * 0.5) * 0.5)
		if engine_glow > 0:
			var glow_pos = _iso_transform(cx, cy, 3.0)
			draw_circle(glow_pos, (8 + engine_glow * 4) * _camera_zoom, Color(1.0, 0.6, 0.2, engine_glow * 0.6))

func _draw_comms_tower(cx: float, cy: float, height: float):
	"""Draw communications tower with satellite dish"""
	var tower_color = Color(0.5, 0.52, 0.55)
	var dish_color = Color(0.7, 0.72, 0.75)
	var signal_color = Color(0.3, 0.8, 1.0)

	# Lattice tower (simplified as tapered hex)
	var base_r = 8.0
	var top_r = 4.0

	for seg in range(6):
		var t1 = float(seg) / 6
		var t2 = float(seg + 1) / 6
		var r1 = lerp(base_r, top_r, t1)
		var r2 = lerp(base_r, top_r, t2)
		var z1 = t1 * height
		var z2 = t2 * height

		# Just draw the edges for lattice effect
		for i in range(6):
			var angle = i * TAU / 6.0
			var b = _iso_transform(cx + cos(angle) * r1, cy + sin(angle) * r1, z1)
			var t = _iso_transform(cx + cos(angle) * r2, cy + sin(angle) * r2, z2)
			draw_line(b, t, tower_color, 2.0 * _camera_zoom)

		# Horizontal rings
		if seg % 2 == 0:
			for i in range(6):
				var angle1 = i * TAU / 6.0
				var angle2 = (i + 1) * TAU / 6.0
				var p1 = _iso_transform(cx + cos(angle1) * r1, cy + sin(angle1) * r1, z1)
				var p2 = _iso_transform(cx + cos(angle2) * r1, cy + sin(angle2) * r1, z1)
				draw_line(p1, p2, tower_color, 1.5 * _camera_zoom)

	# Satellite dish at top
	var dish_z = height * 0.85
	var dish_r = 12.0
	var dish_center = _iso_transform(cx + 8, cy, dish_z)

	# Dish (ellipse facing up-right)
	_draw_ellipse(dish_center, dish_r * _camera_zoom, dish_r * 0.6 * _camera_zoom, dish_color)
	# Dish rim
	var rim_points = PackedVector2Array()
	for i in range(16):
		var angle = i * TAU / 16.0
		rim_points.append(dish_center + Vector2(cos(angle) * dish_r, sin(angle) * dish_r * 0.6) * _camera_zoom)
	for i in range(16):
		draw_line(rim_points[i], rim_points[(i + 1) % 16], tower_color, 1.5 * _camera_zoom)

	# Feed horn
	var feed_pos = _iso_transform(cx + 8 + 6, cy, dish_z + 4)
	draw_line(dish_center, feed_pos, tower_color, 2.0 * _camera_zoom)
	draw_circle(feed_pos, 3 * _camera_zoom, tower_color)

	# Signal waves (animated)
	for wave in range(3):
		var wt = fmod(_time * 0.8 + wave * 0.33, 1.0)
		var wave_r = 5 + wt * 20
		var wave_pos = feed_pos + Vector2(wt * 15, -wt * 8) * _camera_zoom
		draw_arc(wave_pos, wave_r * _camera_zoom, -PI * 0.3, PI * 0.3, 8, Color(signal_color.r, signal_color.g, signal_color.b, (1.0 - wt) * 0.6), 2.0 * _camera_zoom)

	# Blinking light at very top
	var top_pos = _iso_transform(cx, cy, height)
	var blink = fmod(_time, 1.5) < 0.3
	if blink:
		draw_circle(top_pos, 4 * _camera_zoom, Color.RED)

func _draw_stadium(cx: float, cy: float, radius: float, height: float):
	"""Draw stadium/arena building (isometric)"""
	var wall_color = Color(0.7, 0.72, 0.75)
	var field_color = Color(0.35, 0.55, 0.35)  # Green sports field
	var seat_color = Color(0.5, 0.4, 0.35)
	var light_color = Color(1.0, 0.95, 0.8, 0.6)

	# Stadium is an elliptical bowl
	var outer_r = radius
	var inner_r = radius * 0.6
	var bowl_h = height

	# Draw seating tiers (bowl shape)
	for tier_idx in range(4):
		var t = float(tier_idx) / 4
		var tier_r = lerp(outer_r, inner_r, t)
		var tier_z = t * bowl_h

		var tier_points = PackedVector2Array()
		for i in range(16):
			var angle = i * TAU / 16.0
			tier_points.append(_iso_transform(cx + cos(angle) * tier_r, cy + sin(angle) * tier_r, tier_z))

		# Draw tier as polygon (with validation)
		if tier_points.size() >= 3 and _is_valid_polygon(tier_points):
			draw_polygon(tier_points, [seat_color.lerp(wall_color, t)])

	# Inner field (at bowl bottom)
	var field_points = PackedVector2Array()
	for i in range(16):
		var angle = i * TAU / 16.0
		field_points.append(_iso_transform(cx + cos(angle) * inner_r * 0.9, cy + sin(angle) * inner_r * 0.9, bowl_h * 0.1))
	if field_points.size() >= 3 and _is_valid_polygon(field_points):
		draw_polygon(field_points, [field_color])

	# Field markings
	var center = _iso_transform(cx, cy, bowl_h * 0.1)
	draw_arc(center, inner_r * 0.3 * _camera_zoom, 0, TAU, 16, Color.WHITE, 1.5 * _camera_zoom)

	# Stadium lights on poles
	for i in range(4):
		var angle = i * TAU / 4 + 0.4
		var pole_x = cx + cos(angle) * outer_r * 1.1
		var pole_y = cy + sin(angle) * outer_r * 1.1
		var pole_base = _iso_transform(pole_x, pole_y, 0)
		var pole_top = _iso_transform(pole_x, pole_y, height * 2.5)
		draw_line(pole_base, pole_top, wall_color, 2 * _camera_zoom)

		# Light cluster
		draw_circle(pole_top, 6 * _camera_zoom, light_color)

		# Light beams down onto field
		var beam_end = _iso_transform(cx + cos(angle) * inner_r * 0.5, cy + sin(angle) * inner_r * 0.5, 0)
		draw_line(pole_top, beam_end, Color(1.0, 0.98, 0.9, 0.15), 8 * _camera_zoom)

func _draw_perspective_stadium(base_pos: Vector2, width: float, height: float, scale: float, depth_ratio: float, tier: int = 1):
	"""Draw stadium in perspective view"""
	var w = width * scale
	var h = height * scale

	# Skip drawing if too small (prevents degenerate polygon errors)
	if w < 5.0 or h < 5.0:
		# Draw simple ellipse fallback for tiny stadiums
		_draw_ellipse(base_pos + Vector2(0, -h * 0.5), w, h * 0.5, Color(0.5, 0.4, 0.35))
		return

	var wall_color = Color(0.7, 0.72, 0.75)
	var field_color = Color(0.35, 0.55, 0.35)
	var seat_color = Color(0.5, 0.4, 0.35)

	# Atmospheric haze
	var haze = depth_ratio * 0.5
	wall_color = wall_color.lerp(Color(0.6, 0.55, 0.5), haze)
	field_color = field_color.lerp(Color(0.5, 0.5, 0.45), haze)
	seat_color = seat_color.lerp(Color(0.55, 0.52, 0.48), haze)

	# Elliptical bowl - front rim lower, back rim higher
	var bowl_front = base_pos + Vector2(0, -h * 0.3)
	var bowl_back = base_pos + Vector2(0, -h * 0.8)

	# Draw seating area (simplified ellipse) - use fewer points for small scales
	var point_count = 17 if w > 20 else 9
	var outer_points = PackedVector2Array()
	for i in range(point_count):
		var angle = i * PI / (point_count - 1)  # Half ellipse (front facing)
		var rim_y = lerpf(bowl_front.y, bowl_back.y, 0.5 + sin(angle) * 0.5)
		outer_points.append(Vector2(base_pos.x + cos(angle - PI/2) * w, rim_y))

	# Validate polygon before drawing
	if outer_points.size() >= 3 and _is_valid_polygon(outer_points):
		draw_polygon(outer_points, [seat_color])

	# Inner field
	var field_w = w * 0.5
	var field_h = h * 0.2
	var field_center = base_pos + Vector2(0, -h * 0.4)
	_draw_ellipse(field_center, field_w, field_h, field_color)

	# Stadium lights (4 poles)
	var light_color = Color(1.0, 0.95, 0.8, 0.7 - haze * 0.3)
	for i in range(4):
		var angle = i * PI / 3 - PI / 6
		var pole_x = base_pos.x + cos(angle) * w * 0.9
		var pole_base = base_pos + Vector2(cos(angle) * w * 0.9, 0)
		var pole_top = pole_base + Vector2(0, -h * 2.0)
		draw_line(pole_base, pole_top, wall_color, 2 * scale)
		draw_circle(pole_top, 4 * scale, light_color)

		# Light cone
		var cone = PackedVector2Array([
			pole_top,
			field_center + Vector2(-field_w * 0.3, 0),
			field_center + Vector2(field_w * 0.3, 0)
		])
		if _is_valid_polygon(cone):
			draw_polygon(cone, [Color(1.0, 0.98, 0.9, 0.05)])

func _draw_procedural_skyscraper(cx: float, cy: float, radius: float, height: float, seed_val: int):
	"""Draw procedurally generated skyscraper (isometric)"""
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val

	# Generate building parameters from seed
	var num_sections = 2 + rng.randi_range(0, 3)  # 2-5 sections
	var base_width = radius * (0.8 + rng.randf() * 0.4)
	var taper = 0.7 + rng.randf() * 0.3  # How much narrower at top

	# Colors with slight variation
	var base_color = Color(0.65 + rng.randf() * 0.15, 0.68 + rng.randf() * 0.12, 0.72 + rng.randf() * 0.1)
	var accent_color = Color(0.4 + rng.randf() * 0.2, 0.6 + rng.randf() * 0.3, 0.8 + rng.randf() * 0.2)
	var window_color = Color(0.9, 0.95, 1.0, 0.6)

	var current_z = 0.0
	var current_width = base_width

	for section in range(num_sections):
		var section_height = height / num_sections * (1.0 + rng.randf() * 0.5)
		var section_width = current_width * (0.85 + rng.randf() * 0.15)

		# Draw section as hex prism
		var colors = base_color if section % 2 == 0 else base_color.lightened(0.1)
		_draw_hex_prism(cx, cy + (section * 2), section_width * 0.7, section_height,
			colors, colors.darkened(0.2), colors.darkened(0.1))

		# Windows (grid pattern)
		var window_rows = int(section_height / 8)
		for row in range(window_rows):
			var window_z = current_z + row * 8 + 4
			for win in range(3):
				var window_angle = win * TAU / 3
				var win_x = cx + cos(window_angle) * section_width * 0.5
				var win_y = cy + sin(window_angle) * section_width * 0.5
				var win_pos = _iso_transform(win_x, win_y, window_z)
				if rng.randf() > 0.3:  # 70% of windows lit
					draw_circle(win_pos, 2 * _camera_zoom, window_color)

		current_z += section_height
		current_width = section_width * taper

	# Spire or antenna at top
	if rng.randf() > 0.5:
		var spire_base = _iso_transform(cx, cy, current_z)
		var spire_top = _iso_transform(cx, cy, current_z + height * 0.2)
		draw_line(spire_base, spire_top, base_color.darkened(0.2), 2 * _camera_zoom)
		draw_circle(spire_top, 3 * _camera_zoom, accent_color)

func _draw_perspective_procedural_skyscraper(base_pos: Vector2, top_pos: Vector2, width: float, height: float,
		scale: float, top_c: Color, left_c: Color, right_c: Color, depth_ratio: float, tier: int, seed_val: int):
	"""Draw procedurally generated skyscraper in perspective"""
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val

	# Generate parameters
	var num_sections = 2 + rng.randi_range(0, 3)
	var taper_style = rng.randi_range(0, 2)  # 0=straight, 1=stepped, 2=curved

	# Atmospheric haze
	var haze = depth_ratio * 0.5
	var haze_color = Color(0.6, 0.55, 0.5)
	top_c = top_c.lerp(haze_color, haze)
	left_c = left_c.lerp(haze_color, haze)
	right_c = right_c.lerp(haze_color, haze)

	var w = width * scale
	var h = height * scale * PERSPECTIVE_HEIGHT_SCALE / PERSPECTIVE_BASE_SCALE

	# Generate glass/opacity variation
	var glass_alpha = 0.3 + rng.randf() * 0.4  # 0.3-0.7
	var glass_color = Color(0.5 + rng.randf() * 0.3, 0.7 + rng.randf() * 0.2, 0.9, glass_alpha)
	glass_color = glass_color.lerp(haze_color, haze * 0.5)

	var current_y = base_pos.y
	var current_w = w

	for section in range(num_sections):
		var section_h = h / num_sections * (0.8 + rng.randf() * 0.4)
		var next_w = current_w * (0.75 + rng.randf() * 0.2)

		# Section base and top
		var sec_base = Vector2(base_pos.x, current_y)
		var sec_top = Vector2(base_pos.x, current_y - section_h)

		# Alternate between solid and glass sections
		var is_glass = rng.randf() > 0.6

		if taper_style == 1 and section > 0:
			# Stepped: draw setback
			current_w = next_w
			sec_base = Vector2(base_pos.x, current_y - 2)

		if is_glass:
			# Glass section with visible floors
			var panel_color = glass_color
			var outline = Color(0.4, 0.5, 0.6, 0.5 - haze * 0.3)

			# Glass panels
			var glass_points = PackedVector2Array([
				sec_base + Vector2(-current_w * 0.5, 0),
				sec_top + Vector2(-next_w * 0.5, 0),
				sec_top + Vector2(next_w * 0.5, 0),
				sec_base + Vector2(current_w * 0.5, 0)
			])
			draw_polygon(glass_points, [panel_color])

			# Floor lines
			var floors = int(section_h / 8)
			for fl in range(floors):
				var fl_y = sec_base.y - fl * 8
				var fl_w = lerp(current_w, next_w, float(fl) / floors)
				draw_line(Vector2(base_pos.x - fl_w * 0.45, fl_y),
					Vector2(base_pos.x + fl_w * 0.45, fl_y), outline, 1)

			# Outline
			for i in range(glass_points.size()):
				draw_line(glass_points[i], glass_points[(i + 1) % glass_points.size()], outline, 1)
		else:
			# Solid section
			var solid_points = PackedVector2Array([
				sec_base + Vector2(-current_w * 0.5, 0),
				sec_top + Vector2(-next_w * 0.5, 0),
				sec_top + Vector2(next_w * 0.5, 0),
				sec_base + Vector2(current_w * 0.5, 0)
			])
			var section_color = left_c if section % 2 == 0 else right_c
			draw_polygon(solid_points, [section_color])

			# Windows (random pattern)
			var window_color = Color(1.0, 0.95, 0.8, 0.6 - haze * 0.3)
			var windows_per_row = int(current_w / 6)
			var window_rows = int(section_h / 10)
			for wr in range(window_rows):
				for wc in range(windows_per_row):
					if rng.randf() > 0.4:  # 60% windows lit
						var win_x = base_pos.x - current_w * 0.4 + wc * (current_w * 0.8 / windows_per_row)
						var win_y = sec_base.y - wr * 10 - 5
						draw_rect(Rect2(win_x - 1.5, win_y - 2, 3, 4), window_color)

		current_y -= section_h
		current_w = next_w

	# Crown/top feature
	var crown_style = rng.randi_range(0, 2)
	match crown_style:
		0:  # Spire
			var spire_h = h * 0.15
			draw_line(Vector2(base_pos.x, current_y), Vector2(base_pos.x, current_y - spire_h),
				top_c.darkened(0.2), 3 * scale)
			draw_circle(Vector2(base_pos.x, current_y - spire_h), 4 * scale, Color(1.0, 0.9, 0.8, 0.7))
		1:  # Helipad
			_draw_ellipse(Vector2(base_pos.x, current_y - 2), current_w * 0.4, current_w * 0.2, top_c)
		2:  # Antenna array
			for ant in range(3):
				var ant_x = base_pos.x + (ant - 1) * current_w * 0.25
				draw_line(Vector2(ant_x, current_y), Vector2(ant_x, current_y - h * 0.08),
					Color(0.5, 0.52, 0.55), 1.5)

func _draw_force_field():
	"""Draw colony-wide force field dome (called separately, not per-building)"""
	if not _force_field_active:
		return

	var field_color = Color(0.3, 0.6, 1.0, 0.15)
	var grid_color = Color(0.4, 0.7, 1.0, 0.3)
	var field_radius = 180.0  # Covers most of the colony
	var field_height = 120.0

	# Hexagonal grid on the dome surface
	var rings = 6
	for ring in range(rings):
		var t = float(ring) / rings
		var ring_z = sin(t * PI * 0.5) * field_height
		var ring_r = field_radius * cos(t * PI * 0.5)

		var points = PackedVector2Array()
		var segments = 24
		for i in range(segments):
			var angle = i * TAU / segments
			# Add shimmer
			var shimmer = sin(_time * 3.0 + angle * 4.0 + ring * 2.0) * 2.0
			var wx = WORLD_CENTER_X + cos(angle) * (ring_r + shimmer)
			var wy = WORLD_CENTER_Y + sin(angle) * (ring_r + shimmer)
			points.append(_iso_transform(wx, wy, ring_z))

		for i in range(segments):
			var alpha = 0.2 + sin(_time * 2.0 + i * 0.5) * 0.1
			draw_line(points[i], points[(i + 1) % segments], Color(grid_color.r, grid_color.g, grid_color.b, alpha), 1.5 * _camera_zoom)

	# Vertical energy lines
	for i in range(12):
		var angle = i * TAU / 12.0
		var prev_pos = _iso_transform(WORLD_CENTER_X + cos(angle) * field_radius, WORLD_CENTER_Y + sin(angle) * field_radius, 0)
		for seg in range(1, rings + 1):
			var t = float(seg) / rings
			var seg_z = sin(t * PI * 0.5) * field_height
			var seg_r = field_radius * cos(t * PI * 0.5)
			var pos = _iso_transform(WORLD_CENTER_X + cos(angle) * seg_r, WORLD_CENTER_Y + sin(angle) * seg_r, seg_z)
			var alpha = 0.15 + sin(_time * 2.5 + i + seg) * 0.1
			draw_line(prev_pos, pos, Color(grid_color.r, grid_color.g, grid_color.b, alpha), 1.0 * _camera_zoom)
			prev_pos = pos

	# Impact flickers (random)
	if fmod(_time, 3.0) < 0.15:
		var impact_angle = fmod(_time * 7.0, TAU)
		var impact_h = 0.3 + fmod(_time * 3.0, 0.4)
		var impact_z = sin(impact_h * PI * 0.5) * field_height
		var impact_r = field_radius * cos(impact_h * PI * 0.5)
		var impact_pos = _iso_transform(
			WORLD_CENTER_X + cos(impact_angle) * impact_r,
			WORLD_CENTER_Y + sin(impact_angle) * impact_r,
			impact_z
		)
		draw_circle(impact_pos, 15 * _camera_zoom, Color(0.5, 0.8, 1.0, 0.6))
		draw_circle(impact_pos, 8 * _camera_zoom, Color(0.7, 0.9, 1.0, 0.8))

func _draw_mass_driver(cx: float, cy: float, length: float):
	"""Draw electromagnetic mass driver / railgun launcher"""
	var rail_color = Color(0.4, 0.42, 0.45)
	var coil_color = Color(0.6, 0.4, 0.2)  # Copper coils
	var energy_color = Color(0.3, 0.7, 1.0)

	# Base platform
	_draw_hex_prism(cx, cy, 20.0, 6.0, rail_color.lightened(0.1), rail_color.darkened(0.2), rail_color)

	# The rail extends outward at an angle (pointing toward horizon)
	var rail_angle = -PI * 0.15  # Slight upward angle
	var rail_dir = Vector2(1.0, -0.3).normalized()

	# Two parallel rails
	var rail_spacing = 8.0
	var rail_height_start = 8.0
	var rail_height_end = 25.0

	for rail_side in [-1, 1]:
		var offset = rail_side * rail_spacing * 0.5
		var start_pos = _iso_transform(cx + offset, cy, rail_height_start)
		var end_pos = _iso_transform(cx + rail_dir.x * length + offset, cy + rail_dir.y * length * 0.5, rail_height_end)

		# Main rail
		draw_line(start_pos, end_pos, rail_color, 4.0 * _camera_zoom)

		# Rail glow when active
		var glow_alpha = 0.3 + sin(_time * 4.0) * 0.2
		draw_line(start_pos, end_pos, Color(energy_color.r, energy_color.g, energy_color.b, glow_alpha), 2.0 * _camera_zoom)

	# Electromagnetic coils along the rail
	var num_coils = 8
	for i in range(num_coils):
		var t = float(i) / (num_coils - 1)
		var coil_x = cx + rail_dir.x * length * t
		var coil_y = cy + rail_dir.y * length * 0.5 * t
		var coil_z = lerp(rail_height_start, rail_height_end, t)
		var coil_pos = _iso_transform(coil_x, coil_y, coil_z)

		# Coil ring
		var coil_active = fmod(_time * 2.0 + i * 0.3, 1.0) < 0.3
		var coil_c = coil_color if not coil_active else energy_color
		_draw_ellipse(coil_pos, 10 * _camera_zoom, 5 * _camera_zoom, coil_c)

	# Payload / projectile being launched (occasionally)
	var launch_cycle = fmod(_time, 4.0)
	if launch_cycle < 1.5:
		var proj_t = launch_cycle / 1.5
		var proj_x = cx + rail_dir.x * length * proj_t
		var proj_y = cy + rail_dir.y * length * 0.5 * proj_t
		var proj_z = lerp(rail_height_start, rail_height_end, proj_t) + proj_t * 20  # Arc upward
		var proj_pos = _iso_transform(proj_x, proj_y, proj_z)

		# Projectile
		draw_circle(proj_pos, 5 * _camera_zoom, Color(0.8, 0.8, 0.85))

		# Plasma trail
		for trail in range(5):
			var trail_t = max(0, proj_t - trail * 0.08)
			var trail_x = cx + rail_dir.x * length * trail_t
			var trail_y = cy + rail_dir.y * length * 0.5 * trail_t
			var trail_z = lerp(rail_height_start, rail_height_end, trail_t) + trail_t * 20
			var trail_pos = _iso_transform(trail_x, trail_y, trail_z)
			draw_circle(trail_pos, (4 - trail * 0.6) * _camera_zoom, Color(0.5, 0.8, 1.0, 0.6 - trail * 0.1))

	# Control tower
	var tower_pos = _iso_transform(cx - 15, cy + 10, 0)
	_draw_hex_prism(cx - 15, cy + 10, 8.0, 18.0, rail_color, rail_color.darkened(0.2), rail_color.darkened(0.1))

	# Blinking warning light
	if fmod(_time, 0.8) < 0.4:
		var warn_pos = _iso_transform(cx - 15, cy + 10, 20)
		draw_circle(warn_pos, 3 * _camera_zoom, Color(1.0, 0.3, 0.1))

func _draw_fusion_reactor(cx: float, cy: float, height: float):
	"""Draw tokamak fusion reactor with plasma torus"""
	var shell_color = Color(0.45, 0.48, 0.52)
	var plasma_color = Color(0.9, 0.4, 0.8)  # Hot pink plasma
	var coil_color = Color(0.3, 0.5, 0.7)

	# Main containment building (cylindrical)
	_draw_hex_prism(cx, cy, 25.0, height * 0.6, shell_color, shell_color.darkened(0.25), shell_color.darkened(0.1))

	# Tokamak torus (donut shape) visible through top
	var torus_z = height * 0.35
	var torus_major_r = 15.0  # Distance from center to tube center
	var torus_minor_r = 6.0   # Tube radius

	# Draw torus as series of circles
	var torus_segments = 16
	for i in range(torus_segments):
		var angle = i * TAU / torus_segments
		var tube_cx = cx + cos(angle) * torus_major_r
		var tube_cy = cy + sin(angle) * torus_major_r
		var tube_pos = _iso_transform(tube_cx, tube_cy, torus_z)

		# Plasma glow inside tube
		var plasma_pulse = 0.5 + sin(_time * 6.0 + angle * 2) * 0.3
		draw_circle(tube_pos, torus_minor_r * _camera_zoom, Color(plasma_color.r, plasma_color.g, plasma_color.b, plasma_pulse))

		# Tube outline
		_draw_ellipse(tube_pos, torus_minor_r * 1.2 * _camera_zoom, torus_minor_r * 0.6 * _camera_zoom,
			Color(shell_color.r, shell_color.g, shell_color.b, 0.7))

	# Magnetic field coils (vertical rings)
	for i in range(6):
		var coil_angle = i * TAU / 6
		var coil_x = cx + cos(coil_angle) * (torus_major_r + 5)
		var coil_y = cy + sin(coil_angle) * (torus_major_r + 5)

		# Vertical coil
		var coil_bottom = _iso_transform(coil_x, coil_y, torus_z - 8)
		var coil_top = _iso_transform(coil_x, coil_y, torus_z + 8)
		draw_line(coil_bottom, coil_top, coil_color, 3 * _camera_zoom)

		# Coil glow
		var glow = 0.3 + sin(_time * 3.0 + i) * 0.2
		draw_line(coil_bottom, coil_top, Color(0.4, 0.7, 1.0, glow), 2 * _camera_zoom)

	# Central plasma core glow
	var core_pos = _iso_transform(cx, cy, torus_z)
	var core_pulse = 0.4 + sin(_time * 8.0) * 0.3
	draw_circle(core_pos, 20 * _camera_zoom, Color(plasma_color.r, plasma_color.g, plasma_color.b, core_pulse * 0.3))
	draw_circle(core_pos, 10 * _camera_zoom, Color(1.0, 0.8, 0.9, core_pulse * 0.5))

	# Energy output conduits
	for angle in [0, TAU/3, TAU*2/3]:
		var conduit_end_x = cx + cos(angle) * 35
		var conduit_end_y = cy + sin(angle) * 35
		var start = _iso_transform(cx + cos(angle) * 25, cy + sin(angle) * 25, torus_z)
		var end_p = _iso_transform(conduit_end_x, conduit_end_y, 5)

		draw_line(start, end_p, coil_color, 3 * _camera_zoom)

		# Energy pulse traveling down conduit
		var pulse_t = fmod(_time * 1.5 + angle, 1.0)
		var pulse_pos = start.lerp(end_p, pulse_t)
		draw_circle(pulse_pos, 4 * _camera_zoom, Color(0.5, 0.9, 1.0, 1.0 - pulse_t))

	# Status lights on top
	var status_pos = _iso_transform(cx, cy, height * 0.6 + 3)
	var status_pulse = 0.5 + sin(_time * 2.0) * 0.5
	draw_circle(status_pos, 5 * _camera_zoom, Color(0.2, 1.0, 0.4, status_pulse))

# =============================================================================
# DUST / WEATHER
# =============================================================================

func _update_dust(delta: float):
	for p in _dust_particles:
		p.x += p.vx * delta
		p.y += p.vy * delta
		p.z += p.vz * delta

		# Wrap
		if p.x < 0: p.x = WORLD_SIZE
		if p.x > WORLD_SIZE: p.x = 0
		if p.y < 0: p.y = WORLD_SIZE
		if p.y > WORLD_SIZE: p.y = 0
		if p.z < 0: p.z = 15
		if p.z > 15: p.z = 0

		if _sandstorm_active:
			p.vx = lerp(p.vx, 40.0, delta * 0.5)

func _draw_dust():
	for p in _dust_particles:
		var screen = _iso_transform(p.x, p.y, p.z)
		var dust_color = COLOR_GROUND_LIGHT
		dust_color.a = p.alpha * (2.0 if _sandstorm_active else 1.0)
		draw_circle(screen, p.size * _camera_zoom, dust_color)

	if _sandstorm_active:
		var overlay = COLOR_GROUND_LIGHT
		overlay.a = _sandstorm_intensity * 0.2
		draw_rect(Rect2(Vector2.ZERO, size), overlay)

# =============================================================================
# HELPERS
# =============================================================================

func _get_colonist_world_pos(colonist: Dictionary) -> Vector2:
	var id_hash = hash(colonist.get("id", ""))
	var t = fmod(_time * 0.08 + float(id_hash) * 0.0001, 1.0)

	if _building_layout.size() > 0:
		var keys = _building_layout.keys()
		var idx = id_hash % keys.size()
		var layout = _building_layout[keys[idx]]
		var bpos = Vector2(layout.world_x, layout.world_y)
		var center = Vector2(WORLD_CENTER_X, WORLD_CENTER_Y)
		return center.lerp(bpos, sin(t * PI))

	return Vector2(WORLD_CENTER_X, WORLD_CENTER_Y)

func _get_building_category(building_type: int) -> String:
	match building_type:
		_MCSTypes.BuildingType.HABITAT, _MCSTypes.BuildingType.BARRACKS, _MCSTypes.BuildingType.QUARTERS:
			return "housing"
		_MCSTypes.BuildingType.AGRIDOME, _MCSTypes.BuildingType.HYDROPONICS, _MCSTypes.BuildingType.PROTEIN_VATS:
			return "food"
		_MCSTypes.BuildingType.POWER_STATION, _MCSTypes.BuildingType.SOLAR_FARM, \
		_MCSTypes.BuildingType.REACTOR, _MCSTypes.BuildingType.FUSION_PLANT:
			return "power"
		_MCSTypes.BuildingType.EXTRACTOR, _MCSTypes.BuildingType.ICE_MINER, _MCSTypes.BuildingType.ATMO_PROCESSOR:
			return "water"
		_MCSTypes.BuildingType.FABRICATOR, _MCSTypes.BuildingType.FOUNDRY, _MCSTypes.BuildingType.PRECISION:
			return "industry"
		_MCSTypes.BuildingType.MEDICAL:
			return "medical"
		_MCSTypes.BuildingType.RESEARCH:
			return "research"
		_:
			return "housing"

func _get_building_height_key(building_type: int) -> String:
	match building_type:
		_MCSTypes.BuildingType.HABITAT: return "hab_pod"
		_MCSTypes.BuildingType.BARRACKS: return "apartment_block"
		_MCSTypes.BuildingType.QUARTERS: return "apartment_block"
		_MCSTypes.BuildingType.AGRIDOME: return "greenhouse"
		_MCSTypes.BuildingType.HYDROPONICS: return "hydroponics"
		_MCSTypes.BuildingType.PROTEIN_VATS: return "hydroponics"
		_MCSTypes.BuildingType.POWER_STATION: return "solar_array"
		_MCSTypes.BuildingType.SOLAR_FARM: return "solar_array"
		_MCSTypes.BuildingType.EXTRACTOR: return "water_extractor"
		_MCSTypes.BuildingType.ICE_MINER: return "water_extractor"
		_MCSTypes.BuildingType.ATMO_PROCESSOR: return "oxygenator"
		_MCSTypes.BuildingType.FABRICATOR: return "factory"
		_MCSTypes.BuildingType.FOUNDRY: return "factory"
		_MCSTypes.BuildingType.PRECISION: return "workshop"
		_MCSTypes.BuildingType.MEDICAL: return "medical_bay"
		_MCSTypes.BuildingType.ACADEMY: return "lab"
		_MCSTypes.BuildingType.RESEARCH: return "research_center"
		_MCSTypes.BuildingType.RECREATION: return "hab_pod"
		_MCSTypes.BuildingType.REACTOR: return "fission_reactor"
		_MCSTypes.BuildingType.FUSION_PLANT: return "fission_reactor"
		_MCSTypes.BuildingType.STORAGE: return "storage"
		_: return "hab_pod"

func _get_building_label(building_type: int) -> String:
	match building_type:
		_MCSTypes.BuildingType.HABITAT: return "H"
		_MCSTypes.BuildingType.BARRACKS: return "B"
		_MCSTypes.BuildingType.QUARTERS: return "Q"
		_MCSTypes.BuildingType.AGRIDOME: return "A"
		_MCSTypes.BuildingType.HYDROPONICS: return "HY"
		_MCSTypes.BuildingType.PROTEIN_VATS: return "PV"
		_MCSTypes.BuildingType.POWER_STATION: return "P"
		_MCSTypes.BuildingType.SOLAR_FARM: return "SF"
		_MCSTypes.BuildingType.EXTRACTOR: return "E"
		_MCSTypes.BuildingType.ICE_MINER: return "IM"
		_MCSTypes.BuildingType.ATMO_PROCESSOR: return "AP"
		_MCSTypes.BuildingType.FABRICATOR: return "F"
		_MCSTypes.BuildingType.FOUNDRY: return "FO"
		_MCSTypes.BuildingType.PRECISION: return "PR"
		_MCSTypes.BuildingType.MEDICAL: return "M"
		_MCSTypes.BuildingType.ACADEMY: return "AC"
		_MCSTypes.BuildingType.RESEARCH: return "R"
		_MCSTypes.BuildingType.RECREATION: return "RC"
		_MCSTypes.BuildingType.REACTOR: return "RX"
		_MCSTypes.BuildingType.FUSION_PLANT: return "FP"
		_MCSTypes.BuildingType.STORAGE: return "ST"
		_MCSTypes.BuildingType.STARPORT: return "SP"
		_MCSTypes.BuildingType.ORBITAL: return "OR"
		_MCSTypes.BuildingType.CATCHER: return "CA"
		_: return "?"

enum BuildingShape {
	HEX_PRISM, TOWER, DOME, SOLAR_ARRAY, TERRAFORMING_TOWER,
	ARCOLOGY, GREENHOUSE, REACTOR, LANDING_PAD, COMMS_TOWER, SPACE_ELEVATOR,
	MASS_DRIVER, FUSION_REACTOR, STADIUM, PROCEDURAL_SKYSCRAPER
}

func _get_building_shape(building_type: int, tier: int = 1) -> BuildingShape:
	"""Determine which visual shape to use for a building type"""
	match building_type:
		# DOME - low bunker/dome structures (survival era basics)
		_MCSTypes.BuildingType.HABITAT, _MCSTypes.BuildingType.MEDICAL, \
		_MCSTypes.BuildingType.ACADEMY:
			return BuildingShape.DOME
		# RECREATION - becomes stadium at higher tiers
		_MCSTypes.BuildingType.RECREATION:
			if tier >= 3:
				return BuildingShape.STADIUM
			return BuildingShape.DOME
		# TOWER - tall rectangular buildings (growth era and later)
		_MCSTypes.BuildingType.BARRACKS, _MCSTypes.BuildingType.FABRICATOR, \
		_MCSTypes.BuildingType.FOUNDRY, _MCSTypes.BuildingType.PRECISION, \
		_MCSTypes.BuildingType.STORAGE, _MCSTypes.BuildingType.LOGISTICS:
			return BuildingShape.TOWER
		# QUARTERS - becomes procedural skyscraper at higher tiers
		_MCSTypes.BuildingType.QUARTERS:
			if tier >= 4:
				return BuildingShape.PROCEDURAL_SKYSCRAPER
			return BuildingShape.ARCOLOGY
		# ARCOLOGY - mega domes for research
		_MCSTypes.BuildingType.RESEARCH:
			return BuildingShape.ARCOLOGY
		# GREENHOUSE - glass domes with plants
		_MCSTypes.BuildingType.AGRIDOME, _MCSTypes.BuildingType.HYDROPONICS, \
		_MCSTypes.BuildingType.PROTEIN_VATS:
			return BuildingShape.GREENHOUSE
		# SOLAR_ARRAY - flat panel arrays
		_MCSTypes.BuildingType.POWER_STATION, _MCSTypes.BuildingType.SOLAR_FARM:
			return BuildingShape.SOLAR_ARRAY
		# REACTOR - glowing core power plants
		_MCSTypes.BuildingType.REACTOR, _MCSTypes.BuildingType.FUSION_PLANT:
			return BuildingShape.REACTOR
		# HEX_PRISM - small industrial (extractor, etc)
		_MCSTypes.BuildingType.EXTRACTOR, _MCSTypes.BuildingType.ICE_MINER, \
		_MCSTypes.BuildingType.ATMO_PROCESSOR:
			return BuildingShape.HEX_PRISM
		# LANDING_PAD - flat pads with ships
		_MCSTypes.BuildingType.STARPORT, _MCSTypes.BuildingType.ORBITAL, \
		_MCSTypes.BuildingType.CATCHER:
			return BuildingShape.LANDING_PAD
		# COMMS_TOWER - lattice towers with dishes
		_MCSTypes.BuildingType.COMMS:
			return BuildingShape.COMMS_TOWER
		# MEGASTRUCTURES
		_MCSTypes.BuildingType.MASS_DRIVER:
			return BuildingShape.MASS_DRIVER
		_MCSTypes.BuildingType.SPACE_ELEVATOR:
			return BuildingShape.SPACE_ELEVATOR
		# Default: hex prism for anything else
		_:
			return BuildingShape.HEX_PRISM

# =============================================================================
# PUBLIC API
# =============================================================================

func set_store(_store: Node):
	pass  # Not needed currently

func update_from_state(state: Dictionary):
	_buildings = state.get("buildings", [])
	_colonists = state.get("colonists", [])
	_year = state.get("year", 1)
	_stability = state.get("stability", 1.0)

	var phase = state.get("phase", 0)
	match phase:
		0: _colony_tier = "survival"
		1: _colony_tier = "growth"
		2: _colony_tier = "society"
		3: _colony_tier = "independence"
		_: _colony_tier = "survival"

	_layout_buildings()

func _layout_buildings():
	"""Main layout dispatcher - routes to perspective or isometric"""
	_building_layout.clear()

	if _buildings.size() == 0:
		return

	if PERSPECTIVE_ENABLED:
		_layout_buildings_perspective()
	else:
		_layout_buildings_isometric()

func _layout_buildings_perspective():
	"""Arrange buildings in rows from foreground to horizon (perspective view)"""
	var tier_mult = TIER_MULTIPLIERS.get(_colony_tier, 1.0)

	# MEGASTRUCTURES get FIXED positions so they don't move around!
	var megastructure_types = [
		_MCSTypes.BuildingType.SPACE_ELEVATOR,
		_MCSTypes.BuildingType.MASS_DRIVER,
	]
	var megastructure_positions = {
		_MCSTypes.BuildingType.SPACE_ELEVATOR: {"lateral": -3.0, "depth": 0.08},  # Left foreground, FIXED
		_MCSTypes.BuildingType.MASS_DRIVER: {"lateral": 5.0, "depth": 0.12},      # Right foreground, FIXED
	}

	# Separate megastructures from regular buildings
	var regular_buildings = []
	var megastructures = []
	for building in _buildings:
		var btype = building.get("type", 0)
		if btype in megastructure_types:
			megastructures.append(building)
		else:
			regular_buildings.append(building)

	# Place megastructures at fixed positions FIRST
	for building in megastructures:
		var bid = building.get("id", "mega")
		var btype = building.get("type", 0)
		var building_tier = building.get("tier", 1)

		var fixed_pos = megastructure_positions.get(btype, {"lateral": 0.0, "depth": 0.05})
		var height_key = _get_building_height_key(btype)
		var base_h = BUILDING_HEIGHTS.get(height_key, 8.0)
		# DRAMATIC tier scaling: Tier 1 = bunker, Tier 5 = skyscraper!
		var tier_scale = 1.0 + (building_tier - 1) * 1.0  # 100% per tier (5x at tier 5)

		_building_layout[bid] = {
			"lateral": fixed_pos.lateral,
			"depth": fixed_pos.depth * MAX_DEPTH,
			"world_x": fixed_pos.lateral,
			"world_y": fixed_pos.depth * MAX_DEPTH,
			"height": base_h * tier_mult * tier_scale,
			"category": _get_building_category(btype),
			"depth_ratio": fixed_pos.depth,
			"tier": building_tier,
		}

	# STABLE POSITIONS: Use building ID hash to determine position
	# This prevents shuffling when buildings upgrade or new ones are added
	# Each building gets a permanent slot based on its ID

	for building in regular_buildings:
		var bid = building.get("id", "")
		var btype = building.get("type", 0)
		var building_tier = building.get("tier", 1)

		# Use hash of building ID for stable, deterministic position
		var hash_val = bid.hash()
		var hash_norm = abs(hash_val) / float(0x7FFFFFFF)  # Normalize to 0-1

		# Determine row (depth) based on hash - spread evenly across rows
		var row_idx = int(hash_norm * PERSPECTIVE_ROWS.size()) % PERSPECTIVE_ROWS.size()
		var row = PERSPECTIVE_ROWS[row_idx]
		var base_depth = row.depth * MAX_DEPTH
		var spread = row.spread * MAX_LATERAL

		# Determine lateral position within row
		var lateral_hash = abs((hash_val * 7919) % 0x7FFFFFFF) / float(0x7FFFFFFF)
		var lateral = lerp(-spread, spread, lateral_hash)

		# Small jitter for visual variety
		var jitter_x = sin(hash_val * 0.1) * spread * 0.05
		var jitter_depth = cos(hash_val * 0.07) * MAX_DEPTH * 0.01
		lateral += jitter_x
		var depth = base_depth + jitter_depth

		var height_key = _get_building_height_key(btype)
		var base_h = BUILDING_HEIGHTS.get(height_key, 8.0)
		# DRAMATIC tier scaling: Tier 1 = bunker, Tier 5 = skyscraper!
		var tier_scale = 1.0 + (building_tier - 1) * 1.0  # 100% per tier (5x at tier 5)

		_building_layout[bid] = {
			"lateral": lateral,
			"depth": depth,
			"world_x": lateral,
			"world_y": depth,
			"height": base_h * tier_mult * tier_scale,
			"category": _get_building_category(btype),
			"depth_ratio": row.depth,
			"tier": building_tier,
		}

func _layout_buildings_isometric():
	"""Arrange buildings in rings around the lifepod (original isometric layout)"""
	var tier_mult = TIER_MULTIPLIERS.get(_colony_tier, 1.0)
	var ring_radius = 55.0
	var ring_spacing = 45.0
	var per_ring = 6

	var idx = 0
	var ring = 0

	while idx < _buildings.size():
		var r = ring_radius + ring * ring_spacing
		var slots = per_ring + ring * 2

		for slot in range(slots):
			if idx >= _buildings.size():
				break

			var angle = (float(slot) / slots) * TAU
			if ring % 2 == 1:
				angle += PI / slots

			var wx = WORLD_CENTER_X + cos(angle) * r
			var wy = WORLD_CENTER_Y + sin(angle) * r

			var building = _buildings[idx]
			var bid = building.get("id", "building_%d" % idx)
			var btype = building.get("type", 0)
			var building_tier = building.get("tier", 1)  # 1-5, upgrades over time

			var height_key = _get_building_height_key(btype)
			var base_h = BUILDING_HEIGHTS.get(height_key, 8.0)
			# DRAMATIC tier scaling: Tier 1 = bunker, Tier 5 = skyscraper!
			var tier_scale = 1.0 + (building_tier - 1) * 1.0  # 100% per tier (5x at tier 5)

			_building_layout[bid] = {
				"world_x": wx,
				"world_y": wy,
				"height": base_h * tier_mult * tier_scale,
				"category": _get_building_category(btype),
				"tier": building_tier,
			}

			idx += 1

		ring += 1

# Compatibility API
func update_state(buildings: Array, colonists: Array):
	_buildings = buildings
	_colonists = colonists
	_layout_buildings()

func set_game_time(days: float, ts: float):
	_year = int(days / 365) + 1
	_time_scale = ts  # Sync animation speed with game speed

func set_robot_count(_c: int): pass
func set_priority_alerts(_a: Array): pass
func trigger_event_effect(_e: String, _d: float = 1.0): pass
func trigger_building_crisis(_b: String): pass

func start_sandstorm(intensity: float = 1.0):
	_sandstorm_active = true
	_sandstorm_intensity = intensity

func stop_sandstorm():
	_sandstorm_active = false
	_sandstorm_intensity = 0.0

func activate_force_field(strength: float = 1.0):
	_force_field_active = true
	_force_field_strength = strength

func deactivate_force_field():
	_force_field_active = false

func set_colony_tier(tier: String):
	"""Manually set tier for testing: survival, growth, society, independence, transcendence"""
	_colony_tier = tier

func set_camera_zoom(z: float):
	_camera_zoom = clamp(z, 0.3, 5.0)  # Allow much closer zoom for epic views

func set_camera_offset(offset: Vector2):
	_camera_pan = offset
