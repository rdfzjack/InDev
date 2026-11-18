class_name Husband
extends PartyMember
## 你老公。卓尔重甲法师，队长。名牌显示的是关系字段。
## 经常点不动：入队以后 interact() 直接不响应（不报错，不提示）——"碰模了吧，过几天就好"。
## 约谈那一串结束（选了第四次之后）才点得动（husband_talkable）。约谈当晚无论如何都点不动。

## 约谈未响应的次数，决定下一次措辞
var summons_ignored := 0


func _ready() -> void:
	char_id = Game.HUSBAND
	super._ready()


## 被点击时调用。返回 false = 没反应。
func interact() -> bool:
	Meta.bump("clicked_husband")
	if Game.flag(&"husband_summons_pending") or not Game.flag(&"husband_talkable"):
		# 点不动
		return false
	DialogueBox.open("res://data/dialogue/husband.dlg", "talk", self)
	return true
