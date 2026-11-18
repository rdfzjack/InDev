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
##   - [flag] 选项文本 -> 节点     有条件的选项；[!flag] 取反
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
			var body: String = sp[0]
			var cond := ""
			if body.begins_with("["):
				var close := body.find("]")
				cond = body.substr(1, close - 1).strip_edges()
				body = body.substr(close + 1).strip_edges()
			var to := ""
			var arrow := body.rfind("->")
			if arrow >= 0:
				to = body.substr(arrow + 2).strip_edges()
				body = body.substr(0, arrow).strip_edges()
			ops.append({"t": "opt", "text": body, "to": to, "cond": cond, "id": sp[1]})
			continue
		var colon := s.find(":")
		var colon_fw := s.find(FULLWIDTH_COLON)
		if colon < 0 or (colon_fw >= 0 and colon_fw < colon):
			colon = colon_fw
		if colon > 0:
			var lp := split_id(s.substr(colon + 1).strip_edges())
			ops.append({"t": "line", "who": s.substr(0, colon).strip_edges(), "text": lp[0], "id": lp[1]})
		else:
			push_error("%s:%d cannot parse: %s" % [path, lineno, s])


func has_node(n: String) -> bool:
	return nodes.has(n)
