class_name UI
# Petites fabriques d'éléments d'interface (tout est construit en code).

const BG := Color("14121c")
const PANEL := Color("221e2e")
const PANEL2 := Color("2c2740")
const ACCENT := Color("ffcc4d")
const TXT := Color("f1ecff")
const DIM := Color("a9a2c0")
const GOOD := Color("6ee06e")
const BAD := Color("ff6b6b")
const BLUE := Color("4fa8ff")

static var _tex_cache := {}

static func tex(path: String) -> Texture2D:
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex_cache[path]

static func sb(col: Color, radius := 14, border := 0, bcol := Color(0, 0, 0, 0), pad := 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border)
	s.border_color = bcol
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.7
	s.content_margin_bottom = pad * 0.7
	s.anti_aliasing = true
	return s

static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = load("res://assets/fonts/DejaVuSansCondensed-Bold.ttf")
	t.default_font_size = 24
	t.set_color("font_color", "Label", TXT)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.85))
	t.set_constant("outline_size", "Label", 0)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var col := Color("4a3f72")
		match st:
			"hover": col = Color("5a4d88")
			"pressed": col = Color("6b5ba3")
			"disabled": col = Color("332d47")
			"focus": col = Color(0, 0, 0, 0)
		var s := sb(col, 12, 2 if st != "focus" else 0, Color(1, 1, 1, 0.12), 10)
		t.set_stylebox(st, "Button", s)
	t.set_color("font_color", "Button", TXT)
	t.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.35))
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_font_size("font_size", "Button", 23)
	t.set_stylebox("panel", "PanelContainer", sb(PANEL, 16, 0, Color.TRANSPARENT, 14))
	t.set_stylebox("normal", "LineEdit", sb(Color("0f0d16"), 10, 2, Color("4a3f72"), 12))
	t.set_stylebox("focus", "LineEdit", sb(Color("0f0d16"), 10, 2, ACCENT, 12))
	t.set_font_size("font_size", "LineEdit", 28)
	t.set_color("font_color", "LineEdit", TXT)
	var grab := sb(Color("6b5ba3"), 8, 0, Color.TRANSPARENT, 0)
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab)
	t.set_stylebox("scroll", "VScrollBar", sb(Color(1, 1, 1, 0.04), 8, 0, Color.TRANSPARENT, 0))
	t.set_constant("separation", "VBoxContainer", 10)
	t.set_constant("separation", "HBoxContainer", 10)
	return t

static func lbl(text: String, size := 24, col := TXT, outline := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if outline: l.add_theme_constant_override("outline_size", 6)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func btn(text: String, cb: Callable, col := Color(), size := 23, min_w := 0) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(min_w, 64)
	if col != Color():
		b.add_theme_stylebox_override("normal", sb(col, 12, 2, Color(1, 1, 1, 0.15), 10))
		b.add_theme_stylebox_override("hover", sb(col.lightened(0.1), 12, 2, Color(1, 1, 1, 0.2), 10))
		b.add_theme_stylebox_override("pressed", sb(col.lightened(0.2), 12, 2, Color(1, 1, 1, 0.3), 10))
	b.pressed.connect(func():
		Sfx.play("click")
		cb.call())
	return b

static func panel(col := PANEL, radius := 16, pad := 14, border := 0, bcol := Color.TRANSPARENT) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb(col, radius, border, bcol, pad))
	return p

static func hb(sep := 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

static func vb(sep := 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

static func icon(path: String, size := 56) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex(path)
	r.custom_minimum_size = Vector2(size, size)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

static func bar(col: Color, h := 18) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, h)
	b.max_value = 1.0
	b.step = 0.0
	b.add_theme_stylebox_override("background", sb(Color(0, 0, 0, 0.55), int(h / 2), 0, Color.TRANSPARENT, 0))
	b.add_theme_stylebox_override("fill", sb(col, int(h / 2), 0, Color.TRANSPARENT, 0))
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b

static func expand(c: Control) -> Control:
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c

static func spacer(h := 8) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

static func title(text: String) -> Label:
	return lbl(text, 30, ACCENT, true)

static func item_icon_path(it: Dictionary) -> String:
	var lst: Array = D.SLOT_ICONS[it.slot]
	return "res://assets/items/%s.png" % lst[int(it.icon) % lst.size()]
