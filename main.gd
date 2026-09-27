extends Control

const mod_Folder_Name : String = "/TestMod"
const GodotExec : String = "D:/Godot/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64.exe"

func _ready() -> void:
	#check for godot exec
	if not FileAccess.file_exists(GodotExec):
		push_error("Godot Editor binary missing from tool directory!")
		return
		
	var execPath = OS.get_executable_path()
	execPath = execPath.replace(execPath.get_file(), "")
	
	#save ignores in file for user to adjust
	if not FileAccess.file_exists(execPath + "Packer_Ignores.tres"):
		ResourceSaver.save(load("res://Ignores.tres"), execPath + "Packer_Ignores.tres")
	
	var ignores : Ignores = ResourceLoader.load(execPath + "Packer_Ignores.tres")
	
	#start creating pack
	var packer = PCKPacker.new()
	packer.pck_start("Mod.pck")
	
	#generate import files
	generate_Import_Files(execPath + mod_Folder_Name)
	
	#recursevely check the mod folder and find directories and files and place them in pack
	var DirsToExplore : PackedStringArray = [execPath + mod_Folder_Name]
	for g in DirsToExplore:
		var dir = DirAccess.open(g)
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				#if its a directory
				if dir.current_is_dir():
					var localDir = (g + "/" + file_name).replace(execPath + mod_Folder_Name + "/", "")
					print("Found directory: " + localDir)
					
					#check if dir should be ignored
					if (ignores.CheckDir(localDir)):
						DirsToExplore.append(g + "/" + file_name)
					else:
						printerr("Dir ignored: " + localDir)
				#if its a file
				else:
					#check if file should be ingored
					if (ignores.CheckFile(file_name)):
						var fileDir = g + "/" + file_name
						var targetDir = fileDir.replace(execPath + mod_Folder_Name, "res:/")
						packer.add_file(targetDir ,fileDir)
						print("Placed file {0} to {1}".format([fileDir, targetDir]))
					
				file_name = dir.get_next()
				
	packer.flush(true)
	
##Launch godot on the background to import all the resources and generate the import files
func generate_Import_Files(mod_folder_path: String):
	#arguments for executing godot
	#1 headless and editor to open editor hidden
	var import_args = [ "--headless",  "--editor","--path", mod_folder_path, "--quit"]
	
	#create a basic project file for godot to use
	ensure_project_godot_exists(mod_folder_path)
	
	#import assets to generate import files
	var output = []
	print("Importing assets...")
	var exit_code = OS.execute(GodotExec, import_args, output, true)
	
	if exit_code != 0:
		push_error("Failed to import mod assets. Error logs: " + str(output))
		return


func ensure_project_godot_exists(mod_path: String):
	var config_file_path = mod_path.path_join("project.godot")
	if not FileAccess.file_exists(config_file_path):
		var file = FileAccess.open(config_file_path, FileAccess.WRITE)
		file.store_string("[config_version=5]\n\n[application]\nconfig/name=\"ModTemplate\"")
		file.close()
