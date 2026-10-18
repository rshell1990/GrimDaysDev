class_name FileFinder
extends RefCounted
## FileFinder
##
## Finds files matching the criteria within the project dir.


## directory = the absolute or relative to res:// dir to scan.
## extensions = extensions to include. ex ["tres", "tscn", "txt"]
## return value is an array of file paths, directory + filename, ["res://folder/file.ext"]
## This search is recursive. Be careful calling it on a deep folder structure.
## Directories starting with . are ignored.
static func find(directory: String, extensions: Array[String]) -> PackedStringArray: 
	var dirs: PackedStringArray = (
		DirAccess.get_directories_at(directory)
		if OS.is_debug_build()
		else PackedStringArray()
	)
	var files: PackedStringArray = (
		DirAccess.get_files_at(directory)
		if OS.is_debug_build()
		else ResourceLoader.list_directory(directory)
	)
	
	var matching_files: PackedStringArray = PackedStringArray()
	for file: String in files:
		if file.get_extension() in extensions:
			var file_path: String = directory.path_join(file)
			matching_files.append(file_path)
	
	for dir: String in dirs:
		# Skip navigation and "hidden" dirs.
		
		if dir[0] == ".":
			continue
		
		var dir_path: String = directory.path_join(dir)
		matching_files += find(dir_path, extensions)
	#assert(not matching_files.is_empty())
	return matching_files
