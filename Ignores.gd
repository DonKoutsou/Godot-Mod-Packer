extends Resource

class_name Ignores

@export var ignored_Types : PackedStringArray
@export var ignored_Dirs : PackedStringArray
@export var ignored_Files : PackedStringArray

func CheckFile(fileName : String) -> bool:
	return !ignored_Types.has(fileName.get_extension()) and !ignored_Files.has(fileName)

func CheckDir(dir : String) -> bool:
	return !ignored_Dirs.has(dir)
