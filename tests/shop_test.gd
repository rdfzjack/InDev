extends Node
## Shop / inventory tests + trade screenshot
var fails := 0


func _ready() -> void:
	TradeScreen.freeze_enabled = false
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.first_level = "res://scenes/levels/sandbox.tscn"
	add_child(main)
	await Router.level_loaded
	await _frames(20)
	print("== trade")
	var g0 := Inv.gold
	TradeScreen.open("general")
	await _frames(5)
	var ts := TradeScreen.instance
	var stock := ts._display_stock()
	_ok(stock[2] == null, "third slot is empty")
	_ok(stock[1]["id"] == "item_01", "Item_01 on display")
	var potion_qty := Inv.count("potion_of_healing")
	ts._on_buy(0, stock[0])
	_ok(Inv.count("potion_of_healing") == potion_qty + 1, "bought a potion")
	_ok(Inv.gold == g0 - 30, "paid 30 gold")
	ts._on_sell(0, {"id": "torch", "qty": 1})
	_ok(Inv.gold == g0 - 30, "selling something you don't have does nothing")
	ts._on_sell(0, {"id": "potion_of_healing", "qty": 1})
	_ok(Inv.gold == g0 - 30 + 15, "sold for half price")
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else ""
	if out != "":
		await _frames(10)
		get_viewport().get_texture().get_image().save_png(out + "/trade.png")
	ts._on_buy(2, null)
	_ok(Meta.get_count("clicked_slot3") >= 1, "slot 3 click recorded")
	var cfg := ConfigFile.new()
	cfg.load(Meta.PATH)
	_ok(cfg.get_value("crash", "armed", "") == "shop_slot3", "crash flag armed before freezing")
	cfg.set_value("crash", "armed", "")
	cfg.save(Meta.PATH)
	ts.close()

	print("== equip / use")
	var pr := Game.sheet(&"protagonist")
	var b0 := pr.weapon_attack_bonus(pr.equipment["main_hand"])
	Inv.add("longsword_plus_1")
	_ok(Inv.equip(pr, "longsword_plus_1"), "equip longsword +1")
	_ok(pr.weapon_attack_bonus(pr.equipment["main_hand"]) == b0 + 1, "+1 to hit")
	_ok(Inv.count("longsword") == 1, "old longsword back in the bag")
	var ac0 := pr.ac()
	Inv.add("ring_of_protection")
	Inv.equip(pr, "ring_of_protection")
	_ok(pr.ac() == ac0 + 1, "ring +1 AC")
	Inv.add("bomb")
	_ok(InventoryScreen.use_outside_combat(pr, "bomb"), "use bomb")
	_ok(pr.long_effects.has("inspired"), "bomb actually inspires (4th thing)")
	_ok(Inventory.display_name("item_01") == "Item_01", "Item_01 name")

	print("== items in combat")
	Combat.instant = true
	var pc: PartyController = Router.current_level.get_node("Party")
	var i := 0
	for id in pc.members:
		pc.members[id].global_position = Vector3(-2 + i * 1.5, 0.1, -9)
		i += 1
	await _frames(5)
	Router.current_level.get_node("Encounter").start()
	await _frames(2)
	var me: Combatant = null
	for c in Combat.combatants:
		if c.team == &"party":
			me = c
			break
	Combat.turn_index = Combat.order.find(me)
	me.start_turn()
	_ok(me.has_status(&"inspired") or me.id() != &"protagonist", "inspiration carried into combat")
	var fire := Combat.find_action(me, "item:alchemists_fire")
	Inv.add("alchemists_fire")
	fire = Combat.find_action(me, "item:alchemists_fire")
	_ok(not fire.is_empty(), "alchemist's fire usable in combat")
	var n0 := Inv.count("alchemists_fire")
	var foe: Combatant = Combat.combatants.filter(func(c): return c.team == &"enemy")[0]
	var aim := me.pos() + (foe.pos() - me.pos()).limit_length(8.0)
	_ok(Combat.perform(me, fire, aim), "thrown")
	_ok(Inv.count("alchemists_fire") == n0 - 1, "consumed")
	var pot := Combat.find_action(me, "item:potion_of_healing")
	_ok(pot["cost"] == "bonus", "potion is a bonus action")
	Combat.active = false
	print("\nRESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(1 if fails else 0)


func _ok(c: bool, what: String) -> void:
	print("  ", "OK  " if c else "FAIL", " ", what)
	if not c:
		fails += 1


func _frames(n: int) -> void:
	for k in n:
		await get_tree().process_frame
