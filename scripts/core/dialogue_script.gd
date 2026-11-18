class_name DialogueScript
extends RefCounted
## .dlg 对话文件解析。纯文本，放在 data/dialogue/，打包后也是明文（设计要求可解包）。
##
## 语法（一行一条）：
##   # 注释
##   ~ 节点名                     开始一个节点
##   说话人id: 文本               台词。narrator = 旁白，protagonist/husband/poet/sl 见 characters.tsv，
##                                其他 id 原样显示（比如 NPC_Villager_04）
##   - 选项文本 -> 节点            选项。-> END 结束对话；不写 -> 则继续往下走
##   - [flag] 选项文本 -> 节点     有条件的选项；[!flag] 取反。可以连写多个 [..][..]
##   条件标签（选项和台词前都能写）：
##     [flag] [!flag]               剧情标记
##     [class:bard] [race:tiefling]  说话的玩家角色的职业 / 种族（选项前会显示 [吟游诗人]）
##     [insight:12] [perception:12]  被动洞悉 / 察觉 >= 12 才出现（前面显示【洞悉】）
##     [check:persuasion:12]         技能检定（只用于选项）：-> 成功节点 | 失败节点
##        额外参数用逗号：[check:persuasion:12,ability=str,lie]
##          ability=xxx 换成别的属性（"说服检定用力量"）；lie = 旁白的评语和结果相反
##        DC 可以是负数、45、或者 {难度}（原样显示）
##   @ cam 镜头 [参数]           镜头，作用于之后的台词（直到下一个 @ cam）：
##     auto（默认）/ speaker / reverse / close <角色id> / wide / ots <被拍的id> <越肩的id>
##   -> 节点                      跳转
##   $ 命令 参数...               set/clear/join/leave/bump/glitch/narrate/emit，见 DialogueRunner
##   @ no_idk                     本节点的选项里不插入"我不知道/我没意见/哈哈哈"
##   @ idk -> 节点                选了那三个之后去哪（默认：等同于第一个选项）
##
## 本地化：台词和选项行尾的 " #id" 是台词 ID（比如 #husband.recruit.01），用来查翻译表。
## 不用手写——运行 tools/dlg_tool.gd 会给缺 ID 的行自动盖上，并导出 data/text/dialogue.tsv。
##
## 每个节点内，连续的选项会合成一组；选项组之后的行在选完后不会执行（要用 -> 跳）。

var nodes: Dictionary = {}     # name -> { "ops": Array, "no_idk": bool, "idk_to": String }
var path := ""


const FULLWIDTH_COLON := "\uFF1A"
static var _id_re: RegEx


## 拆出行尾的 " #id"。返回 [正文, id]
static func split_id(s: String) -> Array:
	if _id_re == null:
		_id_re = RegEx.create_from_string("\\s#([A-Za-z0-9_.]+)\\s*$")
	var m := _id_re.search(s)
	if m == null:
		return [s, ""]
	return [s.substr(0, m.get_start()).strip_edges(), m.get_string(1)]


## 拆出开头的 [..][..] 条件。返回 [剩下的文本, [{type, ...}]]
static func strip_conds(s: String) -> Array:
	var conds: Array = []
	s = s.strip_edges()
	while s.begins_with("["):
		var close := s.find("]")
		if close < 0:
			break
		conds.append(parse_cond(s.substr(1, close - 1).strip_edges()))
		s = s.substr(close + 1).strip_edges()
	return [s, conds]


static func parse_cond(c: String) -> Dictionary:
	# 通用条件（好感度、数值比较、物品、天数……）交给 Cond
	if c.begins_with("approval:") or c.begins_with("item:") or c.begins_with("day") or c.contains(">") or c.contains("<") or c.contains("="):
		return {"type": "cond", "expr": c}
	if c.begins_with("!"):
		return {"type": "flag", "flag": c.substr(1), "neg": true}
	var parts := c.split(":")
	match parts[0]:
		"class", "race", "party":
			return {"type": parts[0], "value": parts[1]}
		"insight", "perception":
			return {"type": "passive", "skill": parts[0], "dc": int(parts[1])}
		"check":
			var rest := ":".join(parts.slice(1))
			var items := rest.split(",")
			var head := items[0].split(":")
			var d := {"type": "check", "skill": head[0], "dc_text": head[1] if head.size() > 1 else "10", "ability": "", "lie": false}
			for it in items.slice(1):
				var kv := it.strip_edges()
				if kv == "lie":
					d["lie"] = true
				elif kv.begins_with("ability="):
					d["ability"] = kv.substr(8)
			return d
	return {"type": "flag", "flag": c, "neg": false}


static func load_file(p: String) -> DialogueScript:
	var ds := DialogueScript.new()
	ds.path = p
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		push_error("DialogueScript: cannot open %s" % p)
		return ds
	ds.parse(f.get_as_text())
	return ds


func parse(src: String) -> void:
	var cur: Dictionary = {}
	var lineno := 0
	for raw in src.split("\n"):
		lineno += 1
		var s := raw.strip_edges()
		if s == "" or s.begins_with("#"):
			continue
		if s.begins_with("~"):
			var name := s.substr(1).strip_edges()
			cur = {"ops": [], "no_idk": false, "idk_to": ""}
			nodes[name] = cur
			continue
		if cur.is_empty():
			push_error("%s:%d content outside of a node" % [path, lineno])
			continue
		var ops: Array = cur["ops"]
		if s.begins_with("@"):
			var d := s.substr(1).strip_edges()
			if d.begins_with("cam"):
				var parts := Array(d.split(" ", false))
				parts.pop_front()
				ops.append({"t": "cam", "shot": parts[0] if parts.size() > 0 else "auto", "args": parts.slice(1)})
				continue
			if d == "no_idk":
				cur["no_idk"] = true
			elif d.begins_with("idk"):
				cur["idk_to"] = d.get_slice("->", 1).strip_edges()
			continue
		if s.begins_with("->"):
			ops.append({"t": "goto", "to": s.substr(2).strip_edges()})
			continue
		if s.begins_with("$"):
			ops.append({"t": "cmd", "args": Array(s.substr(1).strip_edges().split(" ", false))})
			continue
		if s.begins_with("-"):
			var sp := split_id(s.substr(1).strip_edges())
			var cp := strip_conds(sp[0])
			var body: String = cp[0]
			var to := ""
			var to_fail := ""
			var arrow := body.rfind("->")
			if arrow >= 0:
				to = body.substr(arrow + 2).strip_edges()
				body = body.substr(0, arrow).strip_edges()
				if to.contains("|"):
					to_fail = to.get_slice("|", 1).strip_edges()
					to = to.get_slice("|", 0).strip_edges()
			ops.append({"t": "opt", "text": body, "to": to, "to_fail": to_fail, "conds": cp[1], "id": sp[1]})
			continue
		var lc := strip_conds(s)
		s = lc[0]
		var colon := s.find(":")
		var colon_fw := s.find(FULLWIDTH_COLON)
		if colon < 0 or (colon_fw >= 0 and colon_fw < colon):
			colon = colon_fw
		if colon > 0:
			var lp := split_id(s.substr(colon + 1).strip_edges())
			ops.append({"t": "line", "who": s.substr(0, colon).strip_edges(), "text": lp[0], "id": lp[1], "conds": lc[1]})
		else:
			push_error("%s:%d cannot parse: %s" % [path, lineno, s])


func has_node(n: String) -> bool:
	return nodes.has(n)
