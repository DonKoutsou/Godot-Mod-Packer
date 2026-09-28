extends RichTextLabel

class_name Log

var savedLog : PackedStringArray

func printLog() -> void:
	var t : String = ""
	for g in savedLog:
		t += "\n" + g
	text = t
	
func Log(t : String) -> void:
	savedLog.append(t)
	printLog()

func ClearLog() -> void:
	savedLog.clear()
	printLog()
