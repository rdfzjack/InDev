extends Node
## 存档（autoload: Saves）。JSON，存在 user://saves/。
## 结算统计（Meta）不在存档里：读档不会让"读档次数"倒回去。
## 战斗中不能存档。
##
## 角色卡不直接序列化：存升级路线（class_path 里每一步的选择），读档时从头重放，再覆盖可变状态。

signal saved(slot: String)
signal loaded(slot: String)

const DIR := "user://saves/"
const VERSION := 1


func path_of(slot: String) -> String:
	return DIR + slot + ".json"


func can_save() -> bool:
	return not Combat.active and not Router.is_busy() and Router.current_path != ""


func save(slot := "quicksave") -> bool:
	if not can_save():
		return false
	DirAccess.make_dir_recursive_absolute(DIR)
	var data := {
		"version": VERSION,
		"time": Time.get_datetime_string_from_system(),
		"playtime": Meta.playtime_sec,
		"level": Router.current_path,
		"pos": _leader_pos(),
		"game": {
			"party": Game.party.map(func(x): return String(x)),
			"flags": _flags_out(),
			"party_level": Game.party_level,
			"xp": Game.xp,
			"selected": String(Game.selected),
			"shops": Game.shops.duplicate(true),
		},
		"sheets": {},
		"inventory": Inv.snapshot(),
	}
	for id in Game.sheets:
		data["sheets"][String(id)] = _sheet_out(Game.sheets[id])
	var f := FileAccess.open(path_of(slot), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	Meta.bump("saves")
	saved.emit(slot)
	return true


func exists(slot: String) -> bool:
	return FileAccess.file_exists(path_of(slot))


func info(slot: String) -> Dictionary:
	if not exists(slot):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(path_of(slot)))
	return d if d is Dictionary else {}


func list() -> Array:
	var out: Array = []
	if not DirAccess.dir_exists_absolute(DIR):
		return out
	for f in DirAccess.get_files_at(DIR):
		if f.ends_with(".json"):
			out.append(f.get_basename())
	out.sort()
	return out


func load_slot(slot := "quicksave") -> bool:
	var d := info(slot)
	if d.is_empty() or Combat.active or Router.is_busy():
		return false
	var g: Dictionary = d["game"]
	Game.party.assign(g["party"].map(func(x): return StringName(x)))
	Game.flags = {}
	for k in g["flags"]:
		Game.flags[StringName(k)] = g["flags"][k]
	Game.party_level = int(g["party_level"])
	Game.xp = int(g["xp"])
	Game.selected = StringName(g["selected"])
	Game.shops = g["shops"].duplicate(true)
	for sh in Game.shops.values():
		sh["gold"] = int(sh["gold"])
		for e in sh["stock"]:
			e["qty"] = int(e["qty"])
	Game.sheets = {}
	for id in d["sheets"]:
		var s := _sheet_in(StringName(id), d["sheets"][id])
		s.hp_changed.connect(func(): Game.hp_changed.emit(StringName(id)))
		Game.sheets[StringName(id)] = s
	Inv.restore(d["inventory"])
	Meta.bump("loads")
	var p: Array = d.get("pos", [])
	Router.goto(d["level"], "")
	await Router.level_loaded
	if p.size() == 3:
		var pos := Vector3(p[0], p[1], p[2])
		await get_tree().process_frame
		await get_tree().process_frame
		var i := 0
		for m in get_tree().get_nodes_in_group("party"):
			m.global_position = pos + Vector3(i * 1.2, 0.2, i * 0.8)
			i += 1
	Game.party_changed.emit()
	Game.xp_changed.emit()
	Game.selected_changed.emit(Game.selected)
	Bus.report(&"player_load", Game.SL)
	loaded.emit(slot)
	return true


func _leader_pos() -> Array:
	for m in get_tree().get_nodes_in_group("party"):
		if m.get("char_id") == Game.PROTAGONIST:
			var p: Vector3 = m.global_position
			return [p.x, p.y, p.z]
	return []


func _flags_out() -> Dictionary:
	var out := {}
	for k in Game.flags:
		out[String(k)] = Game.flags[k]
	return out


func _sheet_out(s: CharacterSheet) -> Dictionary:
	return {
		"class_path": s.class_path.duplicate(true),
		"hp": s.hp, "temp_hp": s.temp_hp, "dead": s.dead,
		"slots_used": s.slots_used.duplicate(), "pact_used": s.pact_used,
		"resources": s.resources.duplicate(), "equipment": s.equipment.duplicate(),
		"long_effects": s.long_effects.duplicate(),
	}


func _sheet_in(id: StringName, d: Dictionary) -> CharacterSheet:
	var s := CharacterSheet.from_party(id, 0)
	for step in d["class_path"]:
		s.level_up(step)
	s.equipment = d["equipment"].duplicate()
	s.hp = int(d["hp"])
	s.temp_hp = int(d["temp_hp"])
	s.dead = bool(d["dead"])
	s.slots_used = d["slots_used"].map(func(x): return int(x))
	s.pact_used = int(d["pact_used"])
	for k in d["resources"]:
		s.resources[k] = int(d["resources"][k])
	s.long_effects = d["long_effects"].duplicate()
	return s
