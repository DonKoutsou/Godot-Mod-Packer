extends Control

class_name Main

@export var mod_Location_Label : Label
@export var executable_Path_Label : Label
@export var log_Label : RichTextLabel


var basePackPath : String
var mod_Dir : String
var GodotExec : String = "D:/Godot/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64.exe"

var filesToAdd : PackedStringArray
var currentPack : PCKPacker

var execPath

var savedLog : PackedStringArray
var ignores : Ignores

func _ready() -> void:
	execPath = OS.get_executable_path()
	execPath = execPath.replace(execPath.get_file(), "")
	executable_Path_Label.text = GodotExec
	mod_Location_Label.text = mod_Dir
	
	#save ignores in file for user to adjust
	if not FileAccess.file_exists(execPath + "Packer_Ignores.tres"):
		ResourceSaver.save(load("res://Ignores.tres"), execPath + "Packer_Ignores.tres")
	
	Log("Ignore table loaded.\nIgnoring :")
	ignores = ResourceLoader.load(execPath + "Packer_Ignores.tres")
	Log("Files:")
	for g in ignores.ignored_Files:
		Log("    " + g)
	Log("Types:")
	for g in ignores.ignored_Types:
		Log("    ." + g)
	Log("Directories:")
	for g in ignores.ignored_Dirs:
		Log("    " + g)
	
	

func _process(_delta: float) -> void:
	if (filesToAdd.size() > 0):
		var next = filesToAdd[0]
		filesToAdd.remove_at(0)
		addFile(next)
		printLog()
	else: if (currentPack != null):
		currentPack.flush(true)
		currentPack = null
		Log("Pack Generated in location {0}".format([execPath]))

func printLog() -> void:
	var t : String = ""
	for g in savedLog:
		t += "\n" + g
	log_Label.text = t
	
func Log(t : String) -> void:
	savedLog.append(t)
	printLog()

func ClearLog() -> void:
	savedLog.clear()
	printLog()

func addFile(file : String) -> void:
	var targetDir = file.replace(mod_Dir, "res:/")
	currentPack.add_file(targetDir ,file)
	Log("Placed file {0} to {1}".format([file, targetDir]))
	

func GeneratePack() -> void:
	if (mod_Dir == ""):
		Log("Missing Mod Directory")
		return
	#start creating pack
	currentPack = PCKPacker.new()
	currentPack.pck_start("Mod.pck")
	
	#recursevely check the mod folder and find directories and files and place them in pack
	var DirsToExplore : PackedStringArray = [mod_Dir]
	for g in DirsToExplore:
		var dir = DirAccess.open(g)
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				#if its a directory
				if dir.current_is_dir():
					var localDir = (g + "/" + file_name).replace(mod_Dir + "/", "")
					Log("Found directory: " + localDir)
					
					#check if dir should be ignored
					if (ignores.CheckDir(localDir)):
						DirsToExplore.append(g + "/" + file_name)
					else:
						Log("Dir ignored: " + localDir)
				#if its a file
				else:
					#check if file should be ingored
					if (ignores.CheckFile(file_name)):
						var fileDir = g + "/" + file_name
						#var targetDir = fileDir.replace(execPath + mod_Folder_Name, "res:/")
						#currentPack.add_file(targetDir ,fileDir)
						#Log("Placed file {0} to {1}".format([fileDir, targetDir]))
						filesToAdd.append(fileDir)
					
				file_name = dir.get_next()

func GeneratePackInt() -> void:
	if (mod_Dir == ""):
		Log("Missing Mod Directory")
		return

	ensure_project_godot_exists(mod_Dir)
	
	var output = []

	var pack_args = []
	if (basePackPath != ""):
		pack_args = [
			"--headless", 
			"--path", mod_Dir, 
			"--export-patch", "PackerDefault", execPath + "/Mod.pck" # Changed from --export-pack
		]
	else:
		pack_args = [
			"--headless", 
			"--path", mod_Dir, 
			"--export-pack", "PackerDefault", execPath + "/Mod.pck"
		]
	
	print("Packing into PCK...")
	var exit_code = OS.execute(GodotExec, pack_args, output, true)
	
	if exit_code == 0:
		print("Mod pack successfully created at: ", execPath)
	else:
		push_error("Packing failed. Error logs: " + str(output))

##Launch godot on the background to import all the resources and generate the import files
func generate_Import_Files():
	#check for godot exec
	if not FileAccess.file_exists(GodotExec):
		Log("Godot Editor binary missing from tool directory!")
		return
	if (mod_Dir == ""):
		Log("Missing Mod Directory")
		return
	#arguments for executing godot
	#1 headless and editor to open editor hidden
	var import_args = [ "--headless",  "--editor","--path", mod_Dir, "--quit"]
	
	Log("Importing assets...")
	
	#create a basic project file for godot to use
	ensure_project_godot_exists(mod_Dir)
	
	#import assets to generate import files
	var output = []
	
	var exit_code = OS.execute(GodotExec, import_args, output, true)
	
	if exit_code != 0:
		push_error("Failed to import mod assets. Error logs: " + str(output))
		return
	else:
		Log("Import Files Generated")


func ensure_project_godot_exists(mod_path: String):
	# 1. Ensure project.godot exists
	var config_file_path = mod_path.path_join("project.godot")
	if not FileAccess.file_exists(config_file_path):
		var file = FileAccess.open(config_file_path, FileAccess.WRITE)
		file.store_string("[config_version=5]\n\n[application]\nconfig/name=\"ModTemplate\"")
		file.close()

	# 2. Ensure export_presets.cfg exists with a default layout
	var preset_file_path = mod_path.path_join("export_presets.cfg")
	if not FileAccess.file_exists(preset_file_path):
		var file = FileAccess.open(preset_file_path, FileAccess.WRITE)
		
		var preset_template : String
		#Check if base pack is provided
		if (basePackPath != ""):
			var patch_list_str = 'PackedStringArray("%s")' % basePackPath
		
			preset_template = """[preset.0]
			name="PackerDefault"
			platform="Windows Desktop"
			runnable=false
			dedicated_server=false
			custom_features=""
			export_filter="all_resources"
			include_filter=""
			exclude_filter=""
			patch_list={PATCH_LIST}
			export_path="mod_compile.pck"

			[preset.0.options]
			""".replace("{PATCH_LIST}", patch_list_str)
		else:
			# We define a dummy preset named "PackerDefault" matching your CLI argument
			preset_template = """
			[preset.0]
			name="PackerDefault"
			platform="Windows Desktop"
			runnable=false
			dedicated_server=false
			custom_features=""
			export_filter="all_resources"
			include_filter=""
			exclude_filter=""
			export_path="mod_output.pck"

			[preset.0.options]
			"""
		file.store_string(preset_template.strip_edges())
		file.close()


func _on_godot_exec_change_pressed() -> void:
	var fileDiag : FileDialog = FileDialog.new()
	fileDiag.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fileDiag.filters = ["*.exe"]
	fileDiag.use_native_dialog = true
	fileDiag.access = FileDialog.ACCESS_FILESYSTEM
	add_child(fileDiag)
	fileDiag.popup_centered()
	var f = await fileDiag.file_selected
	if (FileAccess.file_exists(f)):
		GodotExec = f
		executable_Path_Label.text = GodotExec
		Log("Godot Executable Path changed to {0}".format([f]))	


func _on_generate_import_pressed() -> void:
	generate_Import_Files()


func _on_generate_pack_pressed() -> void:
	if (currentPack != null):
		return
	GeneratePackInt()


func _on_pack_path_pressed() -> void:
	var fileDiag : FileDialog = FileDialog.new()
	fileDiag.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	fileDiag.use_native_dialog = true
	fileDiag.access = FileDialog.ACCESS_FILESYSTEM
	add_child(fileDiag)
	fileDiag.popup_centered()
	var f = await fileDiag.dir_selected
	if (DirAccess.dir_exists_absolute(f)):
		mod_Dir = f
		mod_Location_Label.text = f
		Log("Mod Directory changed to {0}".format([f]))	
