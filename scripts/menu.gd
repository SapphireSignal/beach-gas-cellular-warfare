extends Control
## Title screen, LAN browser and lobby.
##
## The whole point of the browser is that nobody should have to read an IP
## address off somebody else's phone. The host's device broadcasts over the
## local WiFi and everyone else just sees their name in a list.
##
## The join code and manual entry are fallbacks: some networks drop broadcast
## traffic but still allow direct device-to-device connections, so typing the
## code can work even when the list stays empty.

# ---------------------------------------------------------------------------
# Type scale
#
# These were bare numbers scattered across the file, ranging 12 to 21, and they
# were far too small — the menu is built in a 1280x720 stretch viewport and an
# iPhone in landscape maps 720 units onto about 390 points, so everything here
# lands on screen at roughly **half** its number:
#
#     font 12  ->  6.5 pt      font 21  ->  11.4 pt
#     row 34   ->  18.4 pt tall, against Apple's 44 pt minimum tap target
#
# So the sizes below look absurd read as points and are correct read through
# that 0.54 scale. Divide by two to see what a thumb actually gets. Anything
# added here should go through these rather than a fresh literal, or the menu
# drifts back to being unreadable one button at a time.
# ---------------------------------------------------------------------------

const FONT_SMALL := 24     ## footnotes, changelog body   ~13 pt
const FONT_BODY := 28      ## most labels and list rows   ~15 pt
const FONT_LABEL := 32     ## headings, values            ~17 pt, iOS body size
const FONT_BUTTON := 38    ## anything you tap            ~21 pt

const ROW_TIGHT := 64      ## dense list rows             ~35 pt
const ROW_TAP := 82        ## anything thumb-sized        ~44 pt, the minimum

@onready var cut: ColorRect = $Cut
@onready var title: Label = $Title
@onready var subtitle: Label = $Subtitle
@onready var title_rule: ColorRect = $TitleRule
@onready var tagline: Label = $Tagline
@onready var main_panel: VBoxContainer = $MainPanel
@onready var browse_panel: VBoxContainer = $BrowsePanel
@onready var lobby_panel: VBoxContainer = $LobbyPanel
@onready var playing_as: Label = $MainPanel/PlayingAs
@onready var host_btn: Button = $MainPanel/HostBtn
@onready var join_btn: Button = $MainPanel/JoinBtn
@onready var practice_btn: Button = $MainPanel/PracticeBtn
@onready var customize_btn: Button = $MainPanel/ExtrasRow/CustomizeBtn
@onready var character_btn: Button = $MainPanel/ExtrasRow/CharacterBtn
@onready var settings_btn: Button = $MainPanel/ExtrasRow/SettingsBtn

@onready var character_panel: VBoxContainer = $CharacterPanel
@onready var character_preview = $CharacterPanel/Columns/Preview
@onready var char_name: Label = $CharacterPanel/Columns/Right/CharName
@onready var char_blurb: Label = $CharacterPanel/Columns/Right/CharBlurb
@onready var char_grid: GridContainer = $CharacterPanel/Columns/Right/CharGrid
@onready var char_done: Button = $CharacterPanel/CharDoneBtn

@onready var settings_panel: VBoxContainer = $SettingsPanel
@onready var quality_row: HBoxContainer = $SettingsPanel/Columns/Left/QualityRow
@onready var quality_blurb: Label = $SettingsPanel/Columns/Left/QualityBlurb
@onready var fps_row: HBoxContainer = $SettingsPanel/Columns/Left/FpsRow
@onready var show_fps_btn: Button = $SettingsPanel/Columns/Left/ShowFpsBtn
@onready var master_slider: HSlider = $SettingsPanel/Columns/Left/MasterSlider
@onready var sfx_slider: HSlider = $SettingsPanel/Columns/Left/SfxSlider
@onready var fire_row: HBoxContainer = $SettingsPanel/Columns/Right/FireRow
@onready var fire_blurb: Label = $SettingsPanel/Columns/Right/FireBlurb
@onready var aim_assist_btn: Button = $SettingsPanel/Columns/Right/AimAssistBtn
@onready var sens_slider: HSlider = $SettingsPanel/Columns/Right/SensSlider
@onready var settings_done: Button = $SettingsPanel/SettingsDoneBtn
@onready var customize_panel: VBoxContainer = $CustomizePanel
@onready var case_grid: GridContainer = $CustomizePanel/CaseGrid
@onready var theme_grid: GridContainer = $CustomizePanel/ThemeGrid
@onready var customize_back: Button = $CustomizePanel/CustomizeBack
@onready var scan_label: Label = $BrowsePanel/ScanLabel
@onready var host_list: VBoxContainer = $BrowsePanel/HostList
@onready var code_edit: LineEdit = $BrowsePanel/CodeRow/CodeEdit
@onready var code_btn: Button = $BrowsePanel/CodeRow/CodeBtn
@onready var back_btn: Button = $BrowsePanel/BackBtn
@onready var code_label: Label = $LobbyPanel/CodeLabel
@onready var player_list: VBoxContainer = $LobbyPanel/Columns/LeftCol/PlayerList
@onready var map_preview = $LobbyPanel/Columns/RightCol/MapPreview
@onready var map_blurb: Label = $LobbyPanel/Columns/RightCol/MapBlurb
@onready var map_grid: GridContainer = $LobbyPanel/Columns/RightCol/MapGrid
@onready var start_btn: Button = $LobbyPanel/StartBtn
@onready var leave_btn: Button = $LobbyPanel/LeaveBtn
@onready var how_to_btn: Button = $MainPanel/InfoRow/HowToBtn
@onready var leaderboard_btn: Button = $MainPanel/InfoRow/LeaderboardBtn
@onready var leaderboard_panel: VBoxContainer = $LeaderboardPanel
@onready var leaderboard_list: VBoxContainer = $LeaderboardPanel/LeaderboardScroll/LeaderboardList
@onready var leaderboard_back: Button = $LeaderboardPanel/LeaderboardBack
@onready var career_btn: Button = $MainPanel/InfoRow/CareerBtn
@onready var career_panel: VBoxContainer = $CareerPanel
@onready var career_list: VBoxContainer = $CareerPanel/CareerScroll/CareerList
@onready var career_back: Button = $CareerPanel/CareerBack
@onready var how_to_panel: VBoxContainer = $HowToPanel
@onready var how_to_list: VBoxContainer = $HowToPanel/HowToScroll/HowToList
@onready var how_to_back: Button = $HowToPanel/HowToBack
@onready var changelog_btn: Button = $ChangelogBtn
@onready var version_label: Label = $VersionLabel
@onready var changelog_panel: VBoxContainer = $ChangelogPanel
@onready var changelog_list: VBoxContainer = $ChangelogPanel/ChangelogScroll/ChangelogList
@onready var changelog_back: Button = $ChangelogPanel/ChangelogBack
@onready var status_label: Label = $StatusLabel
@onready var net_label: Label = $NetLabel

var _state := "main"
var _scan_dots := 0.0


func _ready() -> void:
	_style(host_btn, Color(1.0, 0.32, 0.36))
	_style(join_btn, Color(0.35, 0.72, 1.0))
	_style(practice_btn, Color(0.7, 0.62, 0.95))
	_style(customize_btn, Color(0.55, 0.58, 0.72))
	_style(character_btn, Color(0.95, 0.62, 0.35))
	_style(settings_btn, Color(0.55, 0.58, 0.72))
	_style(customize_back, Color(0.30, 0.95, 0.55))
	_style(char_done, Color(0.30, 0.95, 0.55))
	_style(settings_done, Color(0.30, 0.95, 0.55))
	_style(show_fps_btn, Color(0.55, 0.58, 0.72))
	_style(aim_assist_btn, Color(0.55, 0.58, 0.72))
	_style(code_btn, Color(0.35, 0.72, 1.0))
	_style(start_btn, Color(0.30, 0.95, 0.55))
	_style(back_btn, Color(0.6, 0.62, 0.7))
	_style(leave_btn, Color(0.6, 0.62, 0.7))
	changelog_btn.add_theme_font_size_override("font_size", FONT_SMALL)
	_style(changelog_btn, Color(0.48, 0.51, 0.64))
	_style(changelog_back, Color(0.30, 0.95, 0.55))
	_style(how_to_btn, Color(0.35, 0.72, 1.0))
	_style(how_to_back, Color(0.30, 0.95, 0.55))
	_style(leaderboard_btn, Color(1.0, 0.78, 0.30))
	_style(leaderboard_back, Color(0.30, 0.95, 0.55))
	_style(career_btn, Color(0.72, 0.58, 1.00))
	_style(career_back, Color(0.30, 0.95, 0.55))
	version_label.text = "v%s" % Changelog.VERSION

	host_btn.pressed.connect(_on_host)
	join_btn.pressed.connect(_on_join_pressed)
	practice_btn.pressed.connect(_on_practice)
	customize_btn.pressed.connect(func(): _go("customize"))
	customize_back.pressed.connect(func(): _go("main"))
	character_btn.pressed.connect(func(): _go("character"))
	char_done.pressed.connect(func(): _go("main"))
	settings_btn.pressed.connect(func(): _go("settings"))
	settings_done.pressed.connect(func(): _go("main"))
	changelog_btn.pressed.connect(func(): _go("changelog"))
	changelog_back.pressed.connect(func(): _go("main"))
	how_to_btn.pressed.connect(func(): _go("howto"))
	how_to_back.pressed.connect(func(): _go("main"))
	leaderboard_btn.pressed.connect(func(): _go("leaderboard"))
	leaderboard_back.pressed.connect(func(): _go("main"))
	career_btn.pressed.connect(func(): _go("career"))
	career_back.pressed.connect(func(): _go("main"))
	show_fps_btn.pressed.connect(_toggle_fps_counter)
	aim_assist_btn.pressed.connect(_toggle_aim_assist)
	master_slider.value_changed.connect(func(v): Settings.master_volume = v; Settings.apply_audio())
	sfx_slider.value_changed.connect(func(v): Settings.sfx_volume = v; Settings.apply_audio())
	sens_slider.value_changed.connect(func(v): Settings.look_sensitivity = v)
	for slider in [master_slider, sfx_slider, sens_slider]:
		slider.drag_ended.connect(func(_changed): Settings.save())
	code_btn.pressed.connect(_on_manual_join)
	back_btn.pressed.connect(func(): _go("main"))
	start_btn.pressed.connect(Net.begin_match)
	leave_btn.pressed.connect(_on_leave)
	code_edit.text_submitted.connect(func(_t): _on_manual_join())

	Net.lobby_changed.connect(_refresh)
	Net.hosts_found.connect(_refresh_host_list)
	Net.net_error.connect(_on_error)

	_build_swatches()
	_build_character_grid()
	_refresh_settings()
	_refresh_identity()
	_build_changelog()
	_build_how_to()

	# First run gets the rules unprompted. After that it's a button.
	if Loadout.seen_how_to:
		_go("main")
	else:
		Loadout.seen_how_to = true
		Loadout.save()
		_go("howto")

	if "--tour" in OS.get_cmdline_user_args():
		_tour_panels()


## Open every panel and build every character, for `--tour`.
##
## Half of this menu is built in code the moment a panel opens, and every
## character's props are built the moment you select them — so a plain launch
## proves nothing about the other eight screens or the other eleven people. Any
## of them could be broken for a week and a headless check would still pass.
## Add `--shots` to write a PNG of each one to user://.
func _tour_panels() -> void:
	var shots := "--shots" in OS.get_cmdline_user_args()
	var was := Loadout.character_index

	for state in ["main", "howto", "leaderboard", "career", "changelog",
			"customize", "settings", "browse"]:
		_go(state)
		await _settle(shots, state)

	_go("character")
	for i in Characters.count():
		_pick_character(i)
		await _settle(shots, "character_%s" % Characters.get_entry(i)["id"])

	_pick_character(was)
	_go("main")
	print("TOUR ok")
	get_tree().quit(0)


func _settle(shots: bool, label: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not shots:
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://shot_%s.png" % label)


func _process(delta: float) -> void:
	if _state == "browse":
		_scan_dots = fmod(_scan_dots + delta, 3.0)
		var found := Net.found_hosts.size()
		if found == 0:
			scan_label.text = "looking for games on this WiFi%s" % ".".repeat(int(_scan_dots) + 1)
		else:
			scan_label.text = "%d game%s found — tap to join" % [found, "" if found == 1 else "s"]


## Driven by main.gd from the backdrop's own shot timer, so the 3D behind the
## menu dips to black between camera angles instead of hard-cutting.
func set_backdrop_fade(amount: float) -> void:
	if cut != null:
		cut.modulate.a = clampf(amount, 0.0, 1.0)


## Called by main.gd when a match ends and we drop back here.
func refresh_after_match() -> void:
	if Net.is_connected_to_game():
		Net.reopen_lobby()
		_go("lobby")
	else:
		_go("main")


# ---------------------------------------------------------------------------

func _on_host() -> void:
	
	if Net.host_game(_my_name()):
		_go("lobby")


func _on_practice() -> void:
	if Net.start_practice(_my_name(), 1):
		_go("lobby")


func _on_join_pressed() -> void:
	
	Net.look_for_hosts()
	_go("browse")


func _on_manual_join() -> void:
	
	var code := code_edit.text.strip_edges()
	if code.is_empty():
		_status("Type the code shown on the host's screen.", true)
		return
	if Net.join_game(_my_name(), code):
		_status("connecting to %s…" % code, false)


func _join_ip(ip: String) -> void:
	
	if Net.join_game(_my_name(), ip):
		_status("connecting…", false)


func _on_leave() -> void:
	Net.leave()
	_go("main")


func _on_error(msg: String) -> void:
	_status(msg, true)
	if not Net.is_connected_to_game() and _state == "lobby":
		_go("main")


# ---------------------------------------------------------------------------

func _go(state: String) -> void:
	_state = state
	main_panel.visible = state == "main"
	browse_panel.visible = state == "browse"
	lobby_panel.visible = state == "lobby"
	customize_panel.visible = state == "customize"
	character_panel.visible = state == "character"
	settings_panel.visible = state == "settings"
	changelog_panel.visible = state == "changelog"
	how_to_panel.visible = state == "howto"
	leaderboard_panel.visible = state == "leaderboard"
	career_panel.visible = state == "career"
	if state == "leaderboard":
		_build_leaderboard()
	elif state == "career":
		_build_career()

	# The masthead belongs to the title screen. Every panel used to open
	# underneath it and the tagline ran straight into the first row of controls —
	# "GRAPHICS QUALITY" sat about four pixels under it. Each panel carries its
	# own heading instead, and gets the whole screen to breathe in.
	var at_title := state == "main"
	title.visible = at_title
	subtitle.visible = at_title
	title_rule.visible = at_title
	tagline.visible = at_title
	# The version tag belongs on the title screen, not stamped over every panel.
	changelog_btn.visible = at_title
	version_label.visible = at_title
	# The turntable is live 3D; there's no reason to render it off-screen.
	character_preview.set_active(state == "character")
	if state == "character":
		_show_character(Loadout.character_index)
	if state != "browse":
		Net.stop_looking_for_hosts()
	# Belt and braces on persistence: sliders normally save when you let go of
	# them, but clicking the track never fires a drag-end, so leaving the panel
	# always commits whatever's on screen.
	if _state == "settings" and state != "settings":
		Settings.save()
	if state == "main":
		_status("", false)
	_refresh()
	_update_net_label()


func _refresh() -> void:
	if _state == "lobby":
		_refresh_lobby()
	elif _state == "browse":
		_refresh_host_list()
	# Getting connected while browsing means we're in somebody's lobby now.
	if _state == "browse" and Net.is_connected_to_game() and not Net.players.is_empty():
		_go("lobby")


func _refresh_lobby() -> void:
	_refresh_maps()
	for child in player_list.get_children():
		child.queue_free()

	for id in Net.players:
		var entry := Characters.get_entry(Net.character_of(int(id)))
		var accent: Color = entry["accent"]

		# One row: a bar in their character's colour, their name, their case,
		# and who they are to you. You can read the whole lobby at a glance.
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.custom_minimum_size = Vector2(0, ROW_TIGHT)

		var stripe := ColorRect.new()
		stripe.color = accent
		stripe.custom_minimum_size = Vector2(5, 0)
		row.add_child(stripe)

		var portrait := ColorRect.new()
		portrait.color = Color(entry["skin"])
		portrait.custom_minimum_size = Vector2(22, 22)
		portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var hair := ColorRect.new()
		hair.color = Color(entry["hair"])
		hair.custom_minimum_size = Vector2(22, 7)
		hair.position = Vector2.ZERO
		portrait.add_child(hair)
		row.add_child(portrait)

		var who: String = str(Net.players[id].get("name", "?"))
		var tags: Array[String] = []
		if int(id) == Net.my_id():
			tags.append("you")
		if int(id) == 1:
			tags.append("host")
		if Net.is_bot(int(id)):
			tags.append("bot")

		var label := Label.new()
		label.text = who + ("   (%s)" % ", ".join(tags) if not tags.is_empty() else "")
		label.add_theme_font_size_override("font_size", FONT_LABEL)
		label.add_theme_color_override("font_color", Color(0.92, 0.94, 1.0))
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)

		# Their phone case, as a dot on the right.
		var case_dot := ColorRect.new()
		case_dot.color = Loadout.case_color_for(Net.case_of(int(id)))
		case_dot.custom_minimum_size = Vector2(14, 14)
		case_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(case_dot)

		player_list.add_child(row)

	var count := Net.players.size()
	if Net.is_host():
		code_label.text = "JOIN CODE   %s\nor address   %s" % [Net.join_code(), Net.local_ip()]
		start_btn.visible = true
		start_btn.disabled = count < 2
		start_btn.text = "START MATCH" if count >= 2 else "waiting for someone to join…"
	else:
		code_label.text = "in the lobby — waiting for the host to start"
		start_btn.visible = false


func _refresh_maps() -> void:
	var selected: String = Net.selected_map
	map_preview.show_map(selected)
	var info := Maps.get_map(selected)
	map_blurb.text = str(info["blurb"])

	for child in map_grid.get_children():
		child.queue_free()

	# Only the host gets to change it; everyone else sees the choice greyed out.
	var can_choose := Net.is_host()
	for entry in Maps.LIST:
		var id: String = str(entry["id"])
		var available: bool = bool(entry["available"])
		var chosen := id == selected

		var b := Button.new()
		b.text = str(entry["name"]) if available else "%s  🔒" % entry["name"]
		b.custom_minimum_size = Vector2(0, ROW_TAP)
		b.add_theme_font_size_override("font_size", FONT_SMALL)
		b.disabled = not available or not can_choose

		var accent := Color(0.30, 0.95, 0.55) if available else Color(0.45, 0.47, 0.58)
		if chosen:
			accent = Color(1.0, 0.82, 0.30)
		_style(b, accent)

		if available and can_choose:
			b.pressed.connect(Net.choose_map.bind(id))
		map_grid.add_child(b)


func _refresh_host_list() -> void:
	if _state != "browse":
		return
	for child in host_list.get_children():
		child.queue_free()

	for ip in Net.found_hosts:
		var info: Dictionary = Net.found_hosts[ip]
		var compatible: bool = int(info["version"]) == Net.PROTOCOL_VERSION
		var b := Button.new()
		if compatible:
			b.text = "%s   ·   %d/%d   ·   %s" % [info["name"], int(info["players"]),
				int(info["max"]), info.get("map", "?")]
		else:
			b.text = "%s   ·   different version" % info["name"]
			b.disabled = true
		b.custom_minimum_size = Vector2(0, ROW_TAP)
		b.add_theme_font_size_override("font_size", FONT_BUTTON)
		_style(b, Color(0.30, 0.95, 0.55) if compatible else Color(0.9, 0.5, 0.45))
		b.pressed.connect(_join_ip.bind(str(info["ip"])))
		host_list.add_child(b)


func _update_net_label() -> void:
	var ip := Net.local_ip()
	if ip.is_empty():
		net_label.text = "no network — connect to WiFi first"
	else:
		net_label.text = "this device: %s" % ip


func _status(msg: String, is_error: bool) -> void:
	status_label.text = msg
	status_label.add_theme_color_override("font_color",
		Color(1.0, 0.45, 0.45) if is_error else Color(0.7, 0.85, 1.0))


# ---------------------------------------------------------------------------

## Your character is your name — there's no separate handle to type in, and the
## select screen already says who you are.
func _my_name() -> String:
	return Characters.display_name(Loadout.character_index)


# ---------------------------------------------------------------------------
# Cosmetics
# ---------------------------------------------------------------------------

func _build_swatches() -> void:
	for child in case_grid.get_children():
		child.queue_free()
	for child in theme_grid.get_children():
		child.queue_free()

	for i in Loadout.CASES.size():
		var entry: Dictionary = Loadout.CASES[i]
		case_grid.add_child(_swatch(str(entry["name"]), entry["color"], i == Loadout.case_index,
			func(): _pick_case(i)))

	for i in Loadout.THEMES.size():
		var entry: Dictionary = Loadout.THEMES[i]
		theme_grid.add_child(_swatch(str(entry["name"]), entry["accent"], i == Loadout.theme_index,
			func(): _pick_theme(i)))


func _pick_case(index: int) -> void:
	Loadout.case_index = index
	Loadout.save()
	_build_swatches()


func _pick_theme(index: int) -> void:
	Loadout.theme_index = index
	Loadout.save()
	_build_swatches()


# ---------------------------------------------------------------------------
# Character select
# ---------------------------------------------------------------------------

func _build_character_grid() -> void:
	for child in char_grid.get_children():
		child.queue_free()

	for i in Characters.count():
		var entry := Characters.get_entry(i)
		var b := Button.new()
		b.text = str(entry["name"])
		b.custom_minimum_size = Vector2(0, ROW_TAP)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", FONT_BODY)
		# Their own accent colour, so the grid reads as twelve people rather
		# than twelve identical buttons.
		_style(b, entry["accent"] if i == Loadout.character_index
			else Color(entry["accent"]).darkened(0.35))
		b.pressed.connect(_pick_character.bind(i))
		char_grid.add_child(b)


func _pick_character(index: int) -> void:
	Loadout.character_index = index
	Loadout.save()
	_build_character_grid()
	_show_character(index)
	_refresh_identity()


## Who's actually winning, by character. Every name on the roster, most kills
## first, with the one you're playing as marked.
##
## It's the standings for this phone rather than for the group — a real
## cross-player table would need a server nobody wants to run — but since your
## character *is* your name in a match, "which of these twelve has the most
## kills" is the question people were asking anyway.
func _build_leaderboard() -> void:
	for child in leaderboard_list.get_children():
		child.queue_free()

	if not Stats.has_history():
		_row(leaderboard_list, "Nothing on the board yet", "go and play one", "",
			Color(0.55, 0.58, 0.72))
		return

	_heading(leaderboard_list, "BY KILLS")
	var rank := 0
	for row in Stats.leaderboard():
		rank += 1
		var index := int(row["character"])
		var entry := Characters.get_entry(index)
		var mine := index == Loadout.character_index
		var accent: Color = entry["accent"]
		_row(leaderboard_list,
			"%d.   %s%s" % [rank, row["name"], "   (you)" if mine else ""],
			"%d" % int(row["kills"]),
			"%d deaths" % int(row["deaths"]),
			Color(1.0, 0.82, 0.35) if mine else accent,
			int(row["kills"]) == 0)

	if Stats.last_match.is_empty():
		return

	_spacer(leaderboard_list)
	_heading(leaderboard_list, "LAST MATCH")
	for i in Stats.last_match.size():
		var row: Dictionary = Stats.last_match[i]
		var entry := Characters.get_entry(int(row["character"]))
		var you: bool = bool(row.get("you", false))
		_row(leaderboard_list,
			"%d.   %s%s" % [i + 1, row["name"], "   (you)" if you else ""],
			"%d" % int(row["kills"]),
			"%d deaths" % int(row["deaths"]),
			Color(1.0, 0.82, 0.35) if you else Color(entry["accent"]))


## Everything you personally have done, across every character and every match.
func _build_career() -> void:
	for child in career_list.get_children():
		child.queue_free()

	_heading(career_list, "ALL TIME")
	_row(career_list, "Kills", str(Stats.kills), "")
	_row(career_list, "Deaths", str(Stats.deaths), "")
	_row(career_list, "K/D", "%.2f" % Stats.kd(), "")
	_row(career_list, "Matches played", str(Stats.matches), "")
	_spacer(career_list)

	_heading(career_list, "BEST")
	_row(career_list, "Killstreak", str(Stats.best_streak), "in one life")
	_row(career_list, "Kills in a match", str(Stats.best_match_kills), "")
	_spacer(career_list)

	_heading(career_list, "WHO YOU PLAY")
	var played := 0
	for row in Stats.leaderboard():
		if int(row["kills"]) == 0 and int(row["deaths"]) == 0:
			continue
		played += 1
		var entry := Characters.get_entry(int(row["character"]))
		_row(career_list, str(row["name"]), "%d" % int(row["kills"]),
			"%d deaths" % int(row["deaths"]), Color(entry["accent"]))
	if played == 0:
		_row(career_list, "Nobody yet", "—", "", Color(0.55, 0.58, 0.72), true)


func _heading(into: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", FONT_LABEL)
	label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))
	into.add_child(label)


## One line of a table: colour bar, name, a big number, and a quiet note after
## it. `faded` is for roster entries nobody has touched — present, so you can
## see who's left to try, but not competing for attention.
func _row(into: VBoxContainer, left: String, value: String, note: String,
		accent := Color(0.55, 0.58, 0.72), faded := false) -> void:
	var alpha := 0.38 if faded else 1.0

	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, ROW_TIGHT)
	row.add_theme_constant_override("separation", 14)

	var stripe := ColorRect.new()
	stripe.color = Color(accent.r, accent.g, accent.b, alpha)
	stripe.custom_minimum_size = Vector2(4, 0)
	row.add_child(stripe)

	var name_label := Label.new()
	name_label.text = left
	name_label.add_theme_font_size_override("font_size", FONT_BODY)
	name_label.add_theme_color_override("font_color", Color(0.86, 0.89, 0.96, alpha))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_label)

	if not note.is_empty():
		var note_label := Label.new()
		note_label.text = note
		note_label.add_theme_font_size_override("font_size", FONT_SMALL)
		note_label.add_theme_color_override("font_color", Color(0.58, 0.62, 0.75, alpha))
		note_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(note_label)

	var value_label := Label.new()
	value_label.text = value
	value_label.custom_minimum_size = Vector2(64, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", FONT_LABEL)
	value_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.92 * alpha))
	value_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(value_label)

	# Keeps the numbers clear of the scroll bar, which otherwise sits right on
	# top of the leaderboard's kill counts.
	var gutter := Control.new()
	gutter.custom_minimum_size = Vector2(18, 0)
	row.add_child(gutter)

	into.add_child(row)


func _spacer(into: VBoxContainer) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 28)
	into.add_child(spacer)


## The rules, for somebody who has never seen this before. Written for a
## coworker who has been handed a phone, not for a manual.
func _build_how_to() -> void:
	var sections := [
		["THE POINT", [
			"Everyone against everyone. Zap people, they respawn, the score keeps going. There's no round to win — you just play until you're done.",
			"Your phone is the weapon. The laser comes out of the camera lens.",
		]],
		["YOUR THREE APPS", [
			"ZAP — your gun. Five hits puts someone down. Fire too fast and it overheats and locks you out for five seconds, so pace it.",
			"TRACK — sonar. Shows everyone on your radar for three seconds. But it also tells them they've been scanned, so it's not free.",
			"CALL — rings their phone from anywhere on the map. Walls and distance don't matter. For five seconds they're slowed and can't shoot at all, and ice covers them so everyone can see it.",
		]],
		["THE COMBO", [
			"TRACK to find them, CALL to pin them, ZAP while they can't shoot back. That's the game.",
		]],
		["THINGS THAT GIVE YOU AWAY", [
			"Shots are loud and you can hear which direction they came from.",
			"A ringing phone is audible to everyone nearby, not just the victim.",
			"Your phone screen glows in the dark, and its colour says which app you're on. Red means someone is holding a laser.",
		]],
		["CONTROLS ON A PHONE", [
			"Left side of the screen moves you — the stick appears wherever your thumb lands. Push it most of the way out to run.",
			"Drag the right side to look. Tap the right side to shoot, so your aiming thumb never has to leave it.",
			"Buttons on the right for TRACK, CALL, JUMP and CROUCH.",
		]],
		["GETTING INTO A GAME", [
			"Everyone on the same WiFi. No internet needed.",
			"One person hits HOST. Everyone else hits JOIN and taps their name in the list.",
			"If the list is empty, type the join code from the host's screen.",
		]],
	]

	for child in how_to_list.get_children():
		child.queue_free()

	for section in sections:
		var heading := Label.new()
		heading.text = str(section[0])
		heading.add_theme_font_size_override("font_size", FONT_LABEL)
		heading.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))
		how_to_list.add_child(heading)

		for line in section[1]:
			var body := Label.new()
			body.text = "   %s" % line
			body.add_theme_font_size_override("font_size", FONT_BODY)
			body.add_theme_color_override("font_color", Color(0.74, 0.78, 0.88))
			body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			body.custom_minimum_size = Vector2(690, 0)
			how_to_list.add_child(body)

		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 22)
		how_to_list.add_child(spacer)


## Built once from Changelog.ENTRIES. Newest release at the top, current one
## marked, each note on its own line.
func _build_changelog() -> void:
	for child in changelog_list.get_children():
		child.queue_free()

	for entry in Changelog.ENTRIES:
		var version := str(entry["version"])
		var current := version == Changelog.VERSION

		var heading := Label.new()
		heading.text = "v%s   %s%s" % [version, entry["title"],
			"      ← you're on this" if current else ""]
		heading.add_theme_font_size_override("font_size", FONT_LABEL)
		heading.add_theme_color_override("font_color",
			Color(1.0, 0.82, 0.35) if current else Color(0.88, 0.90, 0.97))
		heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		changelog_list.add_child(heading)

		for note in entry["notes"]:
			var line := Label.new()
			line.text = "   ·  %s" % note
			line.add_theme_font_size_override("font_size", FONT_SMALL)
			line.add_theme_color_override("font_color", Color(0.64, 0.68, 0.80))
			line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			line.custom_minimum_size = Vector2(600, 0)
			changelog_list.add_child(line)

		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 22)
		changelog_list.add_child(spacer)


func _refresh_identity() -> void:
	playing_as.text = "PLAYING AS   %s" % _my_name().to_upper()


func _show_character(index: int) -> void:
	var entry := Characters.get_entry(index)
	char_name.text = str(entry["name"])
	char_blurb.text = str(entry["blurb"])
	character_preview.show_character(index)


# ---------------------------------------------------------------------------
# Settings
# ---------------------------------------------------------------------------

func _refresh_settings() -> void:
	for child in quality_row.get_children():
		child.queue_free()
	for i in Settings.QUALITY_NAMES.size():
		var b := Button.new()
		b.text = Settings.QUALITY_NAMES[i]
		b.custom_minimum_size = Vector2(0, ROW_TAP)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", FONT_BODY)
		_style(b, Color(0.30, 0.95, 0.55) if i == Settings.quality else Color(0.45, 0.48, 0.60))
		b.pressed.connect(_pick_quality.bind(i))
		quality_row.add_child(b)
	quality_blurb.text = Settings.QUALITY_BLURBS[Settings.quality]

	for child in fps_row.get_children():
		child.queue_free()
	for i in Settings.FPS_NAMES.size():
		var b := Button.new()
		b.text = Settings.FPS_NAMES[i]
		b.custom_minimum_size = Vector2(0, ROW_TAP)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", FONT_BODY)
		_style(b, Color(0.35, 0.72, 1.0) if i == Settings.fps_index else Color(0.45, 0.48, 0.60))
		b.pressed.connect(_pick_fps.bind(i))
		fps_row.add_child(b)

	show_fps_btn.text = "FPS COUNTER:  ON" if Settings.show_fps else "FPS COUNTER:  OFF"
	_style(show_fps_btn, Color(0.30, 0.95, 0.55) if Settings.show_fps else Color(0.45, 0.48, 0.60))

	for child in fire_row.get_children():
		child.queue_free()
	for i in Settings.FIRE_NAMES.size():
		var b := Button.new()
		b.text = Settings.FIRE_NAMES[i]
		b.custom_minimum_size = Vector2(0, ROW_TAP)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", FONT_BODY)
		_style(b, Color(0.30, 0.95, 0.55) if i == Settings.fire_mode else Color(0.45, 0.48, 0.60))
		b.pressed.connect(_pick_fire_mode.bind(i))
		fire_row.add_child(b)
	fire_blurb.text = ("Tap the right side of the screen to shoot. Your aiming thumb never has to leave it."
		if Settings.fire_mode == Settings.Fire.TAP
		else "Fires by itself when somebody is under your crosshair. Easier, but you stop aiming.")

	aim_assist_btn.text = "AIM ASSIST:  ON" if Settings.aim_assist else "AIM ASSIST:  OFF"
	_style(aim_assist_btn, Color(0.30, 0.95, 0.55) if Settings.aim_assist else Color(0.45, 0.48, 0.60))

	master_slider.set_value_no_signal(Settings.master_volume)
	sfx_slider.set_value_no_signal(Settings.sfx_volume)
	sens_slider.set_value_no_signal(Settings.look_sensitivity)


func _pick_quality(index: int) -> void:
	Settings.quality = index as Settings.Quality
	Settings.save()
	_refresh_settings()


func _pick_fps(index: int) -> void:
	Settings.fps_index = index
	Settings.save()
	_refresh_settings()


func _pick_fire_mode(index: int) -> void:
	Settings.fire_mode = index as Settings.Fire
	Settings.save()
	_refresh_settings()


func _toggle_aim_assist() -> void:
	Settings.aim_assist = not Settings.aim_assist
	Settings.save()
	_refresh_settings()


func _toggle_fps_counter() -> void:
	Settings.show_fps = not Settings.show_fps
	Settings.save()
	_refresh_settings()


func _swatch(label: String, color: Color, selected: bool, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(0, ROW_TAP)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", FONT_BODY)

	# Dark cases need light text and vice versa, or half the swatches are unreadable.
	var ink := Color(0.05, 0.05, 0.07) if color.get_luminance() > 0.45 else Color(1, 1, 1)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(state, ink)

	for state in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = color if state != "hover" else color.lightened(0.12)
		sb.border_color = Color(1, 1, 1, 0.95) if selected else Color(0, 0, 0, 0.35)
		sb.set_border_width_all(3 if selected else 1)
		sb.set_corner_radius_all(8)
		b.add_theme_stylebox_override(state, sb)

	b.pressed.connect(on_press)
	return b


## Buttons get a dark body, a thick accent bar down the left edge and a coloured
## glow that grows on hover. The bar is what does the work — a strip of pure
## colour against near-black reads as deliberate at any size, and it gives every
## button an obvious identity without shouting.
func _style(button: Button, accent: Color) -> void:
	# Set it unless the caller already chose one. The old guard tested
	# get_theme_font_size() <= 0, which never fires: that returns the theme's
	# default (16), not zero, so no menu button ever got the size it was meant
	# to have. That is why the buttons stayed tiny after the type scale landed.
	if not button.has_theme_font_size_override("font_size"):
		button.add_theme_font_size_override("font_size", FONT_BUTTON)
	button.add_theme_color_override("font_color", Color(0.94, 0.95, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	button.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	button.add_theme_color_override("font_focus_color", Color(1, 1, 1))
	button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.30))
	button.add_theme_constant_override("outline_size", 0)

	button.add_theme_stylebox_override("normal", _box(accent, 0.16, 0.0, 5))
	button.add_theme_stylebox_override("hover", _box(accent, 0.32, 10.0, 7))
	button.add_theme_stylebox_override("pressed", _box(accent, 0.50, 4.0, 8))
	button.add_theme_stylebox_override("focus", _box(accent, 0.20, 6.0, 5))
	button.add_theme_stylebox_override("disabled", _box(accent.darkened(0.72), 0.07, 0.0, 3))


func _box(accent: Color, fill: float, glow: float, bar: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	# Tinted near-black rather than a wash of the accent: keeps the label
	# readable and lets the edge bar be the brightest thing on the button.
	sb.bg_color = Color(0.05, 0.055, 0.075).lerp(accent, fill * 0.55)
	sb.bg_color.a = 0.90

	sb.border_color = Color(accent.r, accent.g, accent.b, 0.90)
	sb.border_width_left = bar
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.border_width_right = 1
	sb.border_blend = true

	sb.set_corner_radius_all(9)
	sb.corner_detail = 6
	sb.anti_aliasing = true

	if glow > 0.0:
		sb.shadow_color = Color(accent.r, accent.g, accent.b, 0.32)
		sb.shadow_size = int(glow)

	sb.content_margin_top = 11
	sb.content_margin_bottom = 11
	sb.content_margin_left = 20
	sb.content_margin_right = 16
	return sb
