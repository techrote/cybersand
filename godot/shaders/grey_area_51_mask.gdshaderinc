// Match the moving-material transition policy in material_palette.gdshader.
// A static construction material is erased immediately; it must never be
// resurrected by the scene's opaque Concrete finish or Empty-space backdrop.
bool grey_temporally_smoothed(float id) {
	return id == 2.0 || id == 3.0 || id == 4.0 || id == 6.0
		|| (id >= 20.0 && id <= 27.0) || id == 29.0 || id == 30.0
		|| id == 32.0 || id == 33.0 || id == 34.0 || id == 36.0 || id == 37.0;
}
