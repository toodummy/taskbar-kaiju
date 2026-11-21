extends RefCounted
## All balance numbers for Taskbar Kaiju. Tweak here, not in main.gd.

const START_COINS := 30
const MIGRATION_GIFT_BASE := 50       # old v1 saves get this + per-icon-eaten bonus
const MIGRATION_GIFT_PER_EATEN := 2

# --- earning Crunch ---
const COIN_BITE_BASE := 2             # + icon xp / COIN_BITE_XP_DIV
const COIN_BITE_XP_DIV := 5
const COIN_HANDFED_MULT := 1.5
const COIN_PET := 1
const COIN_PET_COOLDOWN := 2.0
const COIN_LEVEL_BASE := 5            # + level * COIN_LEVEL_PER
const COIN_LEVEL_PER := 2
const COIN_STAGE_UP := 40
const COIN_OFFLINE_PER_MIN := 0.35
const COIN_BURN_MULT := 0.6           # icons roasted by fire breath
const FRENZY_COIN_MULT := 2.0

# --- base behaviour ---
const MOOD_DRAIN_PER_SEC := 1.0 / 15.0
const MOOD_OFFLINE_DIV := 60.0        # mood lost = seconds away / this
const OFFLINE_XP_PER_MIN := 0.6
const PASSIVE_XP_PER_MIN := 1.0
const SPAWN_INTERVAL := Vector2(30.0, 50.0)
const ICON_CAP := 7

const SPECIES_ORDER := ["dino", "octo", "mecha", "yeti"]
const SPECIES := {
	"dino": {"name": "Chomp", "title": "Spiky Dino", "price": 0,
		"desc": "The classic. Balanced in every way.",
		"xp": 1.0, "fed_xp": 1.0, "coin": 1.0, "mood": 1.0, "pet": 1.0, "speed": 1.0},
	"octo": {"name": "Gloop", "title": "Slime Octopus", "price": 300,
		"desc": "Hand-fed snacks give +60% XP. Very wiggly.",
		"xp": 1.0, "fed_xp": 1.6, "coin": 1.0, "mood": 1.0, "pet": 1.2, "speed": 0.9},
	"mecha": {"name": "MEK-0", "title": "Robo Mecha", "price": 250,
		"desc": "+50% Crunch per bite. Stomps extra hard.",
		"xp": 1.0, "fed_xp": 1.0, "coin": 1.5, "mood": 1.15, "pet": 0.8, "speed": 1.1},
	"yeti": {"name": "Fluffo", "title": "Fluffy Yeti", "price": 400,
		"desc": "Mood drains 40% slower. Pets count double.",
		"xp": 1.0, "fed_xp": 1.0, "coin": 1.0, "mood": 0.6, "pet": 2.0, "speed": 0.95},
}

const FOOD_ORDER := ["burger", "cake", "soda", "gummy", "pepper"]
const FOODS := {
	"burger": {"name": "Byte Burger", "price": 40, "desc": "2x XP for 60 s", "dur": 60.0},
	"cake": {"name": "Cuddle Cake", "price": 30, "desc": "Mood to 100%"},
	"soda": {"name": "Rage Soda", "price": 60, "desc": "FRENZY 25 s: eats it all, 2x Crunch", "dur": 25.0},
	"gummy": {"name": "Growth Gummy", "price": 120, "desc": "Instant level up"},
	"pepper": {"name": "Ghost Pepper", "price": 50, "desc": "Breathes FIRE. Roasts icons for Crunch.", "dur": 3.2},
}

const UPGRADE_ORDER := ["appetite", "teeth", "chill", "dreams", "auto", "roar"]
const UPGRADES := {
	"appetite": {"name": "Big Appetite", "desc": "+20% XP per bite", "base": 60, "growth": 1.6, "max": 10, "per": 0.20},
	"teeth": {"name": "Golden Teeth", "desc": "+1 Crunch per bite", "base": 50, "growth": 1.55, "max": 10, "per": 1.0},
	"chill": {"name": "Chill Vibes", "desc": "-10% mood drain", "base": 80, "growth": 1.7, "max": 6, "per": 0.10},
	"dreams": {"name": "Sweet Dreams", "desc": "+30% offline XP & Crunch", "base": 70, "growth": 1.6, "max": 8, "per": 0.30},
	"auto": {"name": "Auto-Snacker", "desc": "Icons spawn 15% faster, +1 max", "base": 100, "growth": 1.8, "max": 5, "per": 0.15},
	"roar": {"name": "Mega Roar", "desc": "+25% roar & stomp, +3 Crunch/roar", "base": 90, "growth": 1.7, "max": 5, "per": 0.25},
}

static func upgrade_cost(id: String, lvl: int) -> int:
	var u: Dictionary = UPGRADES[id]
	return int(round(u.base * pow(u.growth, lvl) / 5.0) * 5.0)
