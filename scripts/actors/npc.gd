class_name Npc
extends Actor
## 能对话的 NPC。点击 → 打开 dialogue 的 node 节点。

@export_file("*.dlg") var dialogue := ""
@export var dialogue_node := "start"


func _join_groups() -> void:
	add_to_group("npc")


func interact() -> bool:
	if dialogue == "":
		return false
	DialogueBox.open(dialogue, dialogue_node, self)
	return true
