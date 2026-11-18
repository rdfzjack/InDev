class_name SLMember
extends PartyMember
## SL，提夫林盗贼。
## 远看红色，走近是蓝色——LOD2 烘焙时把牙齿贴图糊到了整张脸上。
## 实现：两套模型用 visibility_range 按距离切换。近处（LOD0）= 蓝，远处（LOD2）= 红。
## 他永远处在被看清楚的位置上，所以他说的是对的。

## 超过这个距离显示 LOD2
@export var lod2_distance := 9.0


func _ready() -> void:
	char_id = Game.SL
	super._ready()


func _build_placeholder() -> void:
	var near := Placeholders.capsule(Color(0.25, 0.45, 0.95), height)
	near.name = "LOD0"
	near.visibility_range_end = lod2_distance
	model.add_child(near)
	var far := Placeholders.capsule(Color(0.85, 0.15, 0.12), height)
	far.name = "LOD2"
	far.visibility_range_begin = lod2_distance
	model.add_child(far)
