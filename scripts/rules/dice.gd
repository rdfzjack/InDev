class_name Dice
extends RefCounted
## 骰子。表达式："1d8"、"2d6+3"、"1d4+1"、"8d6"、"3"。
## 所有随机都走 Dice.rng，测试时可以设种子。

static var rng := RandomNumberGenerator.new()

## 一次掷骰的完整记录（日志要显示明细）
class Roll:
	var expr := ""
	var dice: Array[int] = []   # 每颗骰子的点数
	var sides := 0
	var bonus := 0
	var total := 0
	var crit := false           # 伤害骰是否因重击翻倍

	func _to_string() -> String:
		if dice.is_empty():
			return str(total)
		var s := "%dd%d(%s)" % [dice.size(), sides, ",".join(dice.map(func(d): return str(d)))]
		if bonus > 0:
			s += "+%d" % bonus
		elif bonus < 0:
			s += "%d" % bonus
		return s


## d20 检定的记录
class D20:
	var natural := 0
	var other := 0            # 优势/劣势时被丢掉的那颗；没有则 0
	var mode := 0             # 1 优势 / -1 劣势 / 0 普通
	var bonus := 0
	var total := 0

	func is_nat20() -> bool:
		return natural == 20

	func is_nat1() -> bool:
		return natural == 1


static func parse(expr: String) -> Array:
	# 返回 [count, sides, bonus]
	var e := expr.replace(" ", "")
	var bonus := 0
	var plus := e.find("+")
	var minus := e.rfind("-")
	if plus > 0:
		bonus = int(e.substr(plus + 1))
		e = e.substr(0, plus)
	elif minus > 0:
		bonus = -int(e.substr(minus + 1))
		e = e.substr(0, minus)
	var d := e.find("d")
	if d < 0:
		return [0, 0, int(e) + bonus]
	var count := int(e.substr(0, d)) if d > 0 else 1
	return [count, int(e.substr(d + 1)), bonus]


## crit = true 时骰子数量翻倍（加值不翻）
static func roll(expr: String, crit := false) -> Roll:
	var p := parse(expr)
	var r := Roll.new()
	r.expr = expr
	r.sides = p[1]
	r.bonus = p[2]
	r.crit = crit
	var n: int = p[0] * (2 if crit else 1)
	var sum := 0
	for i in n:
		var v := rng.randi_range(1, r.sides)
		r.dice.append(v)
		sum += v
	r.total = sum + r.bonus
	return r


static func d20(bonus := 0, mode := 0) -> D20:
	var r := D20.new()
	var a := rng.randi_range(1, 20)
	var b := rng.randi_range(1, 20)
	r.mode = clampi(mode, -1, 1)
	if r.mode == 1:
		r.natural = maxi(a, b)
		r.other = mini(a, b)
	elif r.mode == -1:
		r.natural = mini(a, b)
		r.other = maxi(a, b)
	else:
		r.natural = a
	r.bonus = bonus
	r.total = r.natural + bonus
	return r


## 平均值（AI 估算用）
static func average(expr: String) -> float:
	var p := parse(expr)
	return p[0] * (p[1] + 1) / 2.0 + p[2]


## 命中概率：d20 + bonus >= target，nat1 必失，nat20 必中
static func hit_chance(bonus: int, target: int, mode := 0) -> float:
	var need := clampi(target - bonus, 2, 20)   # 至少要掷出 need
	var p := (21 - need) / 20.0
	if mode == 1:
		return 1.0 - (1.0 - p) * (1.0 - p)
	if mode == -1:
		return p * p
	return p


## 豁免成功概率：d20 + bonus >= dc（豁免没有 nat1/nat20 规则）
static func save_chance(bonus: int, dc: int, mode := 0) -> float:
	var p := clampf((21 - (dc - bonus)) / 20.0, 0.0, 1.0)
	if mode == 1:
		return 1.0 - (1.0 - p) * (1.0 - p)
	if mode == -1:
		return p * p
	return p


static func mod(score: int) -> int:
	return floori((score - 10) / 2.0)
