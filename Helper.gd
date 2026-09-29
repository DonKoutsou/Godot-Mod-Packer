extends RefCounted

class_name Helper

static func get_target_path_from_remap(remap_file_path: String) -> String:
	var config = ConfigFile.new()
	var err = config.load(remap_file_path)
	
	if err == OK:
		# Check if the [remap] section has the "path" property
		if config.has_section_key("remap", "path"):
			var internal_binary_path = config.get_value("remap", "path")
			return internal_binary_path # Returns something like "res://.godot/exported/..."
	
	print("Failed to parse remap file: ", remap_file_path)
	return ""

static func reconstruct_all_uid_files(local_unpacked_root_dir: String) -> void:
	# 1. Point to the unpacked .godot cache folder
	var virtual_cache_path = "res://.godot/uid_cache.bin"
	
	if not FileAccess.file_exists(virtual_cache_path):
		print("Warning: uid_cache.bin not found inside the mounted PCK layout.")
		return
		
	print("Parsing binary uid_cache.bin to reconstitute individual .uid files...")
	
	var file = FileAccess.open(virtual_cache_path, FileAccess.READ)
	if not file:
		print("Failed to open binary cache file.")
		return
		
	# 2. Parse the Godot 4 central UID binary format
	# Format Layout: [Int32: Magic/Entry Count] followed by pairs of [Int64: ID] and [String: Path]
	var entry_count = file.get_32()
	
	for i in range(entry_count):
		if file.get_position() >= file.get_length():
			break
			
		var uid_int64 = file.get_64()    # The unique numeric integer ID
		var virtual_path = file.get_pascal_string() # Pascal layout pulls length then characters
		
		if virtual_path.is_empty() or not virtual_path.begins_with("res://"):
			continue
			
		# 3. Convert the 64-bit int back into Godot's standard string text syntax
		var uid_text_string = ResourceUID.id_to_text(uid_int64)
		
		# 4. Locate the path destination inside your local extraction directory
		var relative_path = virtual_path.trim_prefix("res://")
		var local_file_path = local_unpacked_root_dir.path_join(relative_path)
		
		# 5. Append the .uid extension suffix (e.g., music_manager.gd.uid)
		var target_uid_file_path = local_file_path + ".uid"
		
		# Guard: Ensure the nested directory structures exist on the hard drive
		var parent_dir = target_uid_file_path.get_base_dir()
		if not DirAccess.dir_exists_absolute(parent_dir):
			DirAccess.make_dir_recursive_absolute(parent_dir)
			
		# 6. Save the text line to disk
		var file_write = FileAccess.open(target_uid_file_path, FileAccess.WRITE)
		if file_write:
			file_write.store_string(uid_text_string)
			file_write.close()
			
	file.close()
	print("Successfully reconstituted all project UID files!")

static func get_target_path_from_import(import_file_path: String) -> String:
	var config = ConfigFile.new()
	var err = config.load(import_file_path)
	
	if err == OK:
		# Check the [remap] section for the compiled binary path
		if config.has_section_key("remap", "path"):
			var compiled_path = config.get_value("remap", "path")
			return compiled_path # Returns e.g. "res://.godot/imported/player.png-4b2a3f...ctex"
			
		if config.has_section_key("remap", "path.bptc"):
			var compiled_path = config.get_value("remap", "path.bptc")
			return compiled_path 
			
		# Fallback: Some files use 'dest_files' array for multiple variants
		if config.has_section_key("remap", "dest_files"):
			var dest_files = config.get_value("remap", "dest_files")
			if dest_files is Array and dest_files.size() > 0:
				return dest_files[0]
				
	print("Failed to read import layout: ", import_file_path)
	return ""

static func run_opengds_decompiler(gdc_physical_path: String) -> void:
	print("Trying to decompile {0}".format([gdc_physical_path]))
	
	# 1. OS.get_executable_path().get_base_dir() finds the folder where your game is running on disk
	var base_dir = OS.get_executable_path().get_base_dir()
	var opengds_path = base_dir.path_join("OpenGDS.py")
	
	# 2. Formulate the CLI arguments for OpenGDS (e.g., "python OpenGDS.py dcmp <file>")
	var arguments = [opengds_path, "dcmp", gdc_physical_path]
	
	# 3. Call the system Python shell
	var output = []
	
	var local_python_path = OS.get_executable_path().get_base_dir().path_join("python_embed/python.exe")
	var exit_code = OS.execute(local_python_path, arguments, output, true)
	
	if exit_code == 0:
		# 3. Concatenate the output array lines back into one giant code block string
		var full_source_code : String = ""
		for line in output:
			full_source_code += line + "\n"
		
		# 4. Generate the new clean target filename (CardModule.gdc -> CardModule.gd)
		var target_gd_path = gdc_physical_path.left(-4) + ".gd"
		
		# 5. Save the captured code block natively to your unpacked workspace directory
		var file_write = FileAccess.open(target_gd_path, FileAccess.WRITE)
		if file_write:
			file_write.store_string(full_source_code.strip_edges()) # Strip extra leading/trailing whitespace
			file_write.close()
			print("Successfully saved decompiled file to: ", target_gd_path)
			
			# Optional: Erase the compiled binary now that you have the clean source code
			DirAccess.remove_absolute(gdc_physical_path)
		else:
			print("Failed to save final script file to disk: ", target_gd_path)
	else:
		print("OpenGDS failed with exit code: ", exit_code)

func is_python_installed() -> bool:
	var output: Array[String] = []
	
	# Execute a lightweight version query flag
	# On Windows, using cmd.exe ensures we don't throw an uncatchable native crash 
	# if the 'python' keyword doesn't exist at all.
	var arguments: Array[String] = ["/c", "python --version"]
	var exit_code = OS.execute("cmd.exe", arguments, output, true)
	
	if exit_code == 0 and output.size() > 0:
		print("Python detected on system: ", output[0].strip_edges())
		return true
	else:
		print("Python was not found or is not configured in the system PATH.")
		return false
