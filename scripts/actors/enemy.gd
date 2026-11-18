class_name Enemy
extends Actor
## 敌人。monster_kind 对应 data/rules/monsters.json。
## 名牌显示怪物名；进入 EncounterTrigger 范围后参战。

@export var monster_kind := "goblin"

var sheet: CharacterSheet

func get_display_name() -> String:
	return TextDB.line("rules", "monster_" + monster_kind)


func _ready() -> void:
	char_id = StringName("%s_%d" % [monster_kind, get_instance_id()])
	placeholder_color = Color(0.55, 0.2, 0.15)
	super._ready()
	sheet = CharacterSheet.from_monster(monster_kind, char_id)
	collision_layer = 2 | 16   # 16 = 敌人（点击选中用）


func _join_groups() -> void:
	add_to_group("enemy")


func _build_placeholder() -> void:
	var h := height * (0.75 if Rules.monsters.get(monster_kind, {}).get("size", "") == "small" else 1.0)
	model.add_child(Placeholders.capsule(placeholder_color, h))
