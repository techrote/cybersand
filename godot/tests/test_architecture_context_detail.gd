extends SceneTree
const Detail = preload("res://scripts/batch_lab/architecture_context_detail.gd")
var checks := 0
var failures := 0

func check(condition: bool, reason: String) -> void:
	checks+=1
	if not condition: failures+=1;printerr("FAIL: "+reason)

func _initialize() -> void:
	var source: Array = [{"shape":"rectangle","x0":2,"y0":8,"x1":61,"y1":9,"material":58}]
	var zones: Array = [[8,12,48,6]]
	var clearances: Array = [[24,0,12,24]]
	var result := Detail.build(source,[],Vector2i(64,24),zones,clearances,37901,64)
	check(result.ok,"actual support faces produce contextual detail")
	if result.ok:
		check(result.emitted_cells>0 and result.emitted_cells<=64 and result.emitted_cells%2==0,"exact bounded two-cell bars")
		check(result.zone_expansion_cells==8,"expanded zone contract is explicit")
		var seen := {}
		for point: Array in result.operations[0].points:
			check(int(point[1]) in [7,10],"each detail cell shares actual source face")
			check(int(point[0])<24 or int(point[0])>=36,"clearance excludes all new detail")
			check(not seen.has(str(point)),"detail points unique")
			seen[str(point)]=true
		check(JSON.stringify(result)==JSON.stringify(Detail.build(source,[],Vector2i(64,24),zones,clearances,37901,64)),"seed replay exact")
		check(JSON.stringify(result.operations)!=JSON.stringify(Detail.build(source,[],Vector2i(64,24),zones,clearances,37917,64).operations),"new seed changes bounded accents")
	var empty: Array = [{"shape":"rectangle","x0":2,"y0":8,"x1":61,"y1":9,"material":0}]
	check(not Detail.build(empty,[],Vector2i(64,24),zones,[],1).ok,"empty source cannot claim support")
	check(not Detail.build(source,[],Vector2i(64,24),zones,[[0,0,64,24]],1).ok,"complete clearance produces explicit no-candidate refusal")
	check(not Detail.build(source,[],Vector2i(64,24),[[-1,0,1,1]],[],1).ok,"out-of-bounds zones refuse")
	check(not Detail.build(source,[],Vector2i(64,24),zones,[],1,1).ok,"sub-pair budget refuses")
	var hot: Array = [{"shape":"rectangle","x0":2,"y0":8,"x1":61,"y1":9,"material":8}]
	check(not Detail.build(hot,[],Vector2i(64,24),zones,[],1).ok,"fluid material does not claim structural support")
	check(source[0].material==58 and zones==[[8,12,48,6]],"inputs remain immutable")
	print("ARCHITECTURE_CONTEXT_DETAIL: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
