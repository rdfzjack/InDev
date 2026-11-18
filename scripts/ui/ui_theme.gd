class_name UITheme
## 全局 UI 主题：深色半透明面板 + 暗金细描边 + 米黄文字（参照 BG3 的视觉语言）。
## 字体到位后在 FONT_* 里填路径即可。

const BG := Color(0.065, 0.055, 0.045, 0.93)
const BG_DEEP := Color(0.03, 0.025, 0.02, 0.96)
const BORDER := Color(0.45, 0.36, 0.22)
const BORDER_BRIGHT := Color(0.78, 0.63, 0.36)
const TEXT := Color(0.87, 0.81, 0.69)
const TEXT_DIM := Color(0.6, 0.55, 0.46)
const TEXT_GOLD := Color(0.95, 0.8, 0.48)
const HP := Color(0.62, 0.1, 0.08)
const NARRATOR := Color(0.9, 0.84, 0.67)

const FONT_UI := "res://assets/fonts/ui.ttf"
const FONT_SERIF := "res://assets/fonts/serif.ttf"

static var _theme: Theme


static func panel(bg := BG, border := BORDER, width := 1, radius := 3, margin := 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 4
	return sb


static func serif_font() -> Font:
	return load(FONT_SERIF) if ResourceLoader.exists(FONT_SERIF) else null


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	if ResourceLoader.exists(FONT_UI):
		t.default_font = load(FONT_UI)
	t.default_font_size = 16
	t.set_stylebox("panel", "PanelContainer", panel())
	t.set_stylebox("panel", "Panel", panel())
	t.set_stylebox("panel", "TooltipPanel", panel(BG_DEEP, BORDER_BRIGHT, 1, 2, 10))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_color("font_color", "Label", TEXT)
	t.set_color("default_color", "RichTextLabel", TEXT)
	# 按钮：平时透明，悬停一层暗金
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0)
	normal.set_content_margin_all(4)
	var hover := panel(Color(0.78, 0.63, 0.36, 0.14), Color(0, 0, 0, 0), 0, 2, 4)
	hover.shadow_size = 0
	var pressed := panel(Color(0.78, 0.63, 0.36, 0.25), Color(0, 0, 0, 0), 0, 2, 4)
	pressed.shadow_size = 0
	for st in ["normal", "disabled"]:
		t.set_stylebox(st, "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("focus", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", TEXT_GOLD)
	t.set_color("font_focus_color", "Button", TEXT_GOLD)
	t.set_color("font_pressed_color", "Button", TEXT_GOLD)
	t.set_color("font_disabled_color", "Button", TEXT_DIM)
	# 滚动条细一点
	var grab := StyleBoxFlat.new()
	grab.bg_color = BORDER
	grab.set_corner_radius_all(2)
	grab.content_margin_left = 3
	grab.content_margin_right = 3
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab)
	t.set_stylebox("scroll", "VScrollBar", StyleBoxEmpty.new())
	_theme = t
	return t
