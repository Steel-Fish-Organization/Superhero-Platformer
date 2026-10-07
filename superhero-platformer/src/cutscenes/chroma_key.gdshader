shader_type canvas_item;
// Knocks out a sheet's solid background colour. "Standard sprites upd.png" has
// no alpha -- it sits on magenta -- so its frames need this to be drawn cleanly.
// Harmless on sheets that already have transparency.

uniform vec3 key_colour = vec3(0.992, 0.302, 0.827);
uniform float tolerance = 0.15;

void fragment() {
	if (distance(texture(TEXTURE, UV).rgb, key_colour) < tolerance) {
		discard;
	}
}
