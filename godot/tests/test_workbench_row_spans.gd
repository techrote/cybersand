extends SceneTree

const Setup=preload("res://scripts/workbench_setup.gd")
var checks: int=0
var failures: int=0

func check(ok: bool, why: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error("ROW_SPANS "+why)

# Independent dense bitmap: no interval update or candidate decision code.
func oracle(setup: Dictionary) -> Dictionary:
	var size:=Vector2i(setup.extent[0],setup.extent[1])
	var grid:=PackedByteArray();grid.resize(size.x*size.y)
	for edit: Array in setup.edits:
		if edit.size()==5:
			for y: int in range(int(edit[1]),int(edit[1])+int(edit[3])):
				for x: int in range(int(edit[0]),int(edit[0])+int(edit[2])): grid[y*size.x+x]=int(edit[4])
		else:
			var radius: int=int(edit[2]);var cx: int=int(edit[0]);var cy: int=int(edit[1])
			for y: int in range(maxi(0,cy-radius),mini(size.y,cy+radius+1)):
				for x: int in range(maxi(0,cx-radius),mini(size.x,cx+radius+1)):
					if (x-cx)*(x-cx)+(y-cy)*(y-cy)<=radius*radius: grid[y*size.x+x]=int(edit[3])
	var runs: Array=[]
	for y: int in range(size.y):
		var x: int=0
		while x<size.x:
			var start: int=x;var material: int=grid[y*size.x+x]
			while x<size.x and grid[y*size.x+x]==material: x+=1
			if material==0: continue
			if runs.size()>=4096*5: return {"error":"Starting terrain exceeds 4096 horizontal runs."}
			runs.append_array([start,y,x-start,1,material])
	return {"runs":runs}

func compare(setup: Dictionary, why: String) -> void:
	check(Setup.validate(setup).is_empty(),why+" valid setup")
	check(Setup.rectangles(setup)==oracle(setup),why+" exact ordered output")

func _initialize() -> void:
	var recipe: Dictionary=Setup.fresh(PackedInt32Array([0]),Vector2i(512,512));recipe.version=4
	var rng:=RandomNumberGenerator.new();rng.seed=0x1735acf
	for trial: int in range(64):
		recipe.edits=[]
		for stamp: int in range(48):
			var x: int=rng.randi_range(0,511 if trial%2==0 else 48);var y: int=rng.randi_range(0,511 if trial%2==0 else 48)
			var material: int=Setup.MATERIALS[rng.randi_range(0,Setup.MATERIALS.size()-1)]
			if stamp%2==0: recipe.edits.append([float(x),float(y),rng.randi_range(1,mini(70,512-x)),rng.randi_range(1,mini(70,512-y)),material])
			else: recipe.edits.append([x,y,rng.randi_range(2,24),material])
		compare(recipe,"random %d" % trial)
	recipe.edits=[[0,0,20,1,43],[5,0,10,1,2],[7,0,3,1,0],[7,0,3,1,2],[0,0,5,1,2],[15,0,5,1,2],[511,511,1,1,43]]
	compare(recipe,"overlap/split/erase/bridge and last cell")
	for x: int in [0,511]:
		for y: int in [0,511]:
			for radius: int in [2,24]:
				recipe.edits=[[x,y,radius,43]];compare(recipe,"corner disc")
	recipe.edits=[]
	for x: int in range(0,16,2): recipe.edits.append([x,0,1,512,2])
	compare(recipe,"exact4096 runs")
	recipe.edits.append([20,0,1,1,43]);compare(recipe,"4097 refuses")
	recipe.edits.append([20,0,1,1,0]);compare(recipe,"intermediate excess erased")
	recipe.extent=[2048,2048];recipe.edits=[[2047,2047,1,1,43],[2047,0,24,2],[0,2047,24,29],[2040,2040,8,8,0]]
	compare(recipe,"2048 edges and clipped discs")
	print("ROW_SPANS ",checks," checks / ",failures," failures")
	quit(int(failures>0))
