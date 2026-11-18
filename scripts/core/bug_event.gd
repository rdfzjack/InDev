class_name BugEvent
extends RefCounted
## 设计文档第五节的 BugEvent。

var glitch_id: StringName
## clip / interact / stat / position / text / audio / player（玩家行为，比如躺着）
var type: StringName
var instigator: StringName   # 谁身上出的，可为空
var location: Vector3
## gameplay = 影响玩法；funny = 只是好笑
var severity: StringName
var narrator_key: String
## 本条的沉默概率，-1 = 用默认
var silence: float = -1.0
