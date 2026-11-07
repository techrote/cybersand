extends SceneTree
# Source-matched finite workbench fixture exporter for isolated PF research.
# Calls the shipped Setup.builtin()/Setup.rectangles() implementation directly.
const Setup = preload("res://scripts/workbench_setup.gd")

func _initialize() -> void:
    var root: String = OS.get_environment("PF_CAPACITY_FIXTURE_DIR")
    if root.is_empty():
        printerr("PF_CAPACITY_FIXTURE_DIR is required")
        quit(2)
        return
    if DirAccess.make_dir_recursive_absolute(root) != OK:
        printerr("Cannot create PF fixture directory")
        quit(2)
        return
    for label: String in Setup.BUILTIN_LABELS:
        var built: Dictionary = Setup.builtin(label, PackedInt32Array([0]))
        if built.is_empty():
            printerr("Missing authored builtin: ", label)
            quit(3)
            return
        var rectangles: Dictionary = Setup.rectangles(built)
        if rectangles.has("error"):
            printerr("Authored fixture consolidation refused: ", rectangles.error)
            quit(3)
            return
        var source: Array = rectangles.runs
        if source.size() % 5 != 0:
            printerr("Malformed merged run array")
            quit(3)
            return
        var path: String = root.path_join(label + ".csv")
        var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
        if file == null:
            printerr("Cannot write fixture: ", path)
            quit(3)
            return
        file.store_line("%d,%d" % [int(built.extent[0]), int(built.extent[1])])
        for i: int in range(0, source.size(), 5):
            file.store_line("%d,%d,%d,%d,%d" % [
                int(source[i]), int(source[i+1]), int(source[i+2]), int(source[i+3]), int(source[i+4])])
        file.flush()
        file.close()
        print("PF_FIXTURE ", label, " ", source.size()/5, " rectangles ", path)
    quit(0)
