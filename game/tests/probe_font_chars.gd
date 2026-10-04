extends SceneTree
## 字体子集字符覆盖探针（临时）：3D 版新增 UI 字符串逐字检查

const FONT: FontFile = preload("res://fonts/NotoSansSC.ttf")

func _init() -> void:
	var s := "横移复盘侧风峡谷纠偏舵边界蓄力投掷跟随视角终旗图标贴getchar"
	var missing := ""
	for ch in s:
		if not FONT.has_char(ch.unicode_at(0)):
			missing += ch
	print("MISSING=", missing if missing != "" else "无")
	quit(0)
