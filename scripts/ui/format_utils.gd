class_name FormatUtils
extends Object

# 数値表示まわりのユーティリティ。
# 大きい数値はクリッカー慣例の K / M / B / T 表記に縮約する。
# 桁あふれによるレイアウト崩れを避けつつ、桁感を一目で掴めるようにするのが目的。
# 1万未満は省略せず生の整数のまま（序盤のクリック報酬を正確に見せたい）。

const _SUFFIXES := ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp"]
const _SHORT_THRESHOLD := 10000


static func short(n: int) -> String:
	if n > -_SHORT_THRESHOLD and n < _SHORT_THRESHOLD:
		return str(n)
	var negative := n < 0
	var v := absf(float(n))
	var idx := 0
	while v >= 1000.0 and idx < _SUFFIXES.size() - 1:
		v /= 1000.0
		idx += 1
	var s: String
	if v >= 100.0:
		s = "%d%s" % [int(v), _SUFFIXES[idx]]
	elif v >= 10.0:
		s = "%.1f%s" % [v, _SUFFIXES[idx]]
	else:
		s = "%.2f%s" % [v, _SUFFIXES[idx]]
	return "-" + s if negative else s
