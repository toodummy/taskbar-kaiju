# Taskbar Kaiju (prototype v2: Crunch Shop)
Godot 4.7.2 (GDScript, Compatibility renderer). A desktop pet: a cartoon kaiju lives
in a transparent, borderless, always-on-top, click-through window over your desktop,
walks along the taskbar, eats FAKE icons it spawns itself, and grows through 5 stages.

SAFETY: the game never reads, moves, deletes or modifies real files or real desktop
icons. Every icon is a drawn sprite created by icon.gd. The only file written is the
game's own save: user://save.json
  Windows: %APPDATA%\TaskbarKaiju\save.json   Linux: ~/.local/share/TaskbarKaiju/save.json

## Play
- Click the kaiju to pet it (hearts, mood up; spam it and it gets annoyed).
- Drag any fake icon into its mouth: 2x XP + big mood boost.
- It hunts by itself: an icon shakes, drops to the taskbar, and it stomps over and chomps.
- Mood drains over time (and while the game is closed). Under 25% it RAMPAGES: turns red,
  moves faster, summons and eats icons much more often. Feed/pet it above 55% to calm it.
- Growth: Hatchling (L1) -> Chunky (L4) -> Brute (L8) -> Titan (L13) -> KAIJU (L19, a giant
  head peeking up from behind the taskbar). Passive XP 1/min while running, 0.6/min offline
  (capped at 8 h).
- Round green face button (bottom-right): stats, Sound on/off, Snacks x3, Reset (click
  twice), Quit. Esc closes the menu.

## v2: Crunch (currency) + CRUNCH SHOP
Earn Crunch by: icon bites (2 + icon XP/5 + Golden Teeth, x1.5 hand-fed, x2 in FRENZY, x species
bonus), petting (1 per 2 s), level-ups (5 + 2*level), stage-ups (40), Mega Roar, roasting icons
with fire breath, and offline time (0.35/min, capped 8 h). Open the shop from the coin pill next
to the face button, or the orange CRUNCH SHOP button in the face menu.
- KAIJUS: Chomp (spiky dino, free), Gloop (slime octopus, 300: +60% hand-fed XP), MEK-0 (robo
  mecha, 250: +50% Crunch per bite, faster mood drain), Fluffo (fluffy yeti, 400: -40% mood
  drain, pets x2). Each keeps its own level/stage/mood; a new one hatches from its own egg.
- FOOD (consumables, then DROP falls onto the desktop and the kaiju runs to eat it): Byte Burger
  (2x XP 60 s), Cuddle Cake (mood 100%), Rage Soda (FRENZY 25 s), Growth Gummy (instant level),
  Ghost Pepper (SPICY -> 3 s sweeping fire breath that roasts the fake icons for Crunch + XP).
- UPGRADES (permanent, cost = base * growth^level): Big Appetite, Golden Teeth, Chill Vibes,
  Sweet Dreams, Auto-Snacker, Mega Roar.
All balance numbers: config.gd. Save is version 2 (per-species data, coins, inventory,
upgrades); a v1 save is migrated automatically (old pet -> dino, plus a 50 + 2/icon-eaten gift).
Roasting only ever affects the game's own fake icon sprites.

## Files
- main.gd     window setup, click-through, state machine, save/offline, UI, demo script
- kaiju.gd    kaiju vector art for 4 species (Geometry2D polygons, thick sticker outlines, squash & stretch)
- icon.gd     the 10 fake icon types (original art, no logos)
- fx.gd       particles, shockwaves, comic text, speech bubble
- sfx.gd      procedural sounds (chomp, burp, roar, pop, purr, level-up, stomp, plop, crack)
- ui_face.gd  menu button
- config.gd   all balance numbers (prices, upgrade curves, earn rates, species stats)
- shop.gd     the CRUNCH SHOP panel (tabs, cards, buy/switch/drop/upgrade, juice)
- hud.gd      Crunch counter pill + active snack timers, procedural coin texture
- cursor.gd   drawn fake cursor used only by the --demo2 showcase
- tools/preview.gd, tools/preview_icons.gd  art preview sheets (not exported)

## Command-line options (after `--`)
--fresh (ignore save)  --demo (v1 scripted showcase) --demo2 (v2 shop showcase; no saving)  --floor=N (stand N px
above the window bottom)  --px=1.35 (UI/art scale)  --passthrough=poly|flag|off

## Click-through
- Linux/macOS: DisplayServer.window_set_mouse_passthrough() with one polygon built from the
  kaiju, icon, menu-button, coin pill, menu and shop panel rects (joined by zero-width bridges), updated as they move.
  Everything else on screen passes clicks to the desktop/apps below.
- Windows ("region" mode, default there): Godot implements the same call with SetWindowRgn,
  which ALSO clips drawing to the polygon, so on Windows the polygon additionally covers every
  visible effect (speech bubble, particles, shockwaves, banners). Side effect: right around
  those effects clicks are captured for a moment. (The MOUSE_PASSTHROUGH window flag was not
  used: on Windows it returns HTTRANSPARENT, which only passes clicks to windows of the same
  app, not to the desktop.)
- `--debug-region` draws the current polygon rects in magenta.

## Export
The Windows preset uses a size-optimized custom export template
(tools/godot_windows_template_release_min.exe, 38 MB instead of 109 MB) built from the official
4.7.2-stable source with: scons platform=windows target=template_release use_mingw=yes
optimize=size lto=none disable_3d=yes vulkan=no d3d12=no angle=no winrt=no openxr=no
accesskit=no sdl=no module_text_server_adv_enabled=no module_text_server_fb_enabled=yes
plus unused modules disabled (ogg/vorbis/theora/webrtc/websocket/enet/upnp/multiplayer/csg/
gridmap/jolt/godot_physics_3d/basis/jpg/webp/ktx/tga/hdr/dds/minimp3/etc.). Remove the
custom_template line in export_presets.cfg to go back to the stock template.
godot --headless --path . --export-release "Windows Desktop" build/windows/TaskbarKaiju.exe
godot --headless --path . --export-release "Linux" build/linux/TaskbarKaiju.x86_64
