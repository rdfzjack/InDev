class_name PartyMember
extends Actor
## 队员。


func _join_groups() -> void:
	add_to_group("party")


## 点击队友：BG3 式对话（data/dialogue/<id>.dlg 的 talk 节点）
func interact() -> bool:
	var path := "res://data/dialogue/%s.dlg" % String(char_id)
	if not FileAccess.file_exists(path):
		return false
	DialogueBox.open(path, "talk", self)
	return true
