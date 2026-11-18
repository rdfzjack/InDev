class_name Npc
extends Actor
## 能对话的 NPC。点击 → 打开 dialogue 的 node 节点。

@export_file("*.dlg") var dialogue := ""
@export var dialogue_node := "start"
## 对话时字变大（喊话）
@export var shout := false
## 走到多远就能对话（默认队伍的 2.2 米）
var interact_range = null


func _join_groups() -> void:
	add_to_group("npc")


func interact() -> bool:
	if dialogue == "":
		return false
	DialogueBox.open(dialogue, dialogue_node, self)
	return true
