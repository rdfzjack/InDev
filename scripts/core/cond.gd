class_name Cond
## 通用条件（任务日志、好感度事件表用）。每条是一个字符串：
##   flag            剧情标记为真
##   !flag           剧情标记为假
##   flag=value      标记等于某个值（字符串比较）
##   flag>=3         标记是数字，大于等于（也支持 > <= < ）
##   party:poet      在队伍里
##   !party:poet     不在队伍里
##   level:village   当前关卡
##   item:crypt_key  背包里有
##   day>=3          第几天
##   approval:poet>=20   好感度（真实值，不是显示值）


static func all(list: Array) -> bool:
	for c in list:
		if not ok(String(c)):
			return false
	return true


static func any(list: Array) -> bool:
	for c in list:
		if ok(String(c)):
			return true
	return false


static func ok(c: String) -> bool:
	c = c.strip_edges()
	if c == "":
		return true
	var neg := c.begins_with("!")
	if neg:
		c = c.substr(1)
	var r := _eval(c)
	return not r if neg else r


static func _eval(c: String) -> bool:
	if c.begins_with("party:"):
		return Game.in_party(StringName(c.substr(6)))
	if c.begins_with("level:"):
		return Router.current_level != null and String(Router.current_level.name) == c.substr(6)
	if c.begins_with("item:"):
		return Inv.count(c.substr(5)) > 0
	for op in [">=", "<=", "!=", ">", "<", "="]:
		var i := c.find(op)
		if i > 0:
			var lhs := c.substr(0, i)
			var rhs := c.substr(i + op.length())
			var v: Variant
			if lhs == "day":
				v = Game.day
			elif lhs.begins_with("approval:"):
				v = Approval.value(StringName(lhs.substr(9)))
			else:
				v = Game.flag(StringName(lhs), null)
			return _compare(v, op, rhs)
	return bool(Game.flag(StringName(c)))


static func _compare(v: Variant, op: String, rhs: String) -> bool:
	if op == "=" or op == "!=":
		var same := v != null and str(v) == rhs or (v is bool and str(int(v)) == rhs)
		return same if op == "=" else not same
	var a := float(v) if (v is int or v is float) else (1.0 if v == true else 0.0)
	var b := rhs.to_float()
	match op:
		">=":
			return a >= b
		"<=":
			return a <= b
		">":
			return a > b
		"<":
			return a < b
	return false
