shader_type canvas_item;
// Recolours the hero's suit when a weapon is equipped, the way Mega Man's
// armour changes colour per weapon. Only the three suit tones are matched, so
// the gold trim, visor and skin stay untouched.

uniform vec4 key_dark   : source_color = vec4(0.102, 0.180, 0.478, 1.0);
uniform vec4 key_mid    : source_color = vec4(0.188, 0.376, 0.847, 1.0);
uniform vec4 key_light  : source_color = vec4(0.431, 0.627, 1.000, 1.0);

uniform vec4 replace_dark  : source_color = vec4(0.102, 0.180, 0.478, 1.0);
uniform vec4 replace_mid   : source_color = vec4(0.188, 0.376, 0.847, 1.0);
uniform vec4 replace_light : source_color = vec4(0.431, 0.627, 1.000, 1.0);

uniform float tolerance : hint_range(0.0, 0.5) = 0.06;
// Flashes the whole sprite one colour -- used for hit feedback.
uniform vec4 flash_color : source_color = vec4(1.0);
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;

bool matches(vec3 a, vec3 b, float tol) {
	vec3 d = a - b;
	return dot(d, d) < tol * tol;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 rgb = tex.rgb;

	if (matches(rgb, key_mid.rgb, tolerance)) {
		rgb = replace_mid.rgb;
	} else if (matches(rgb, key_light.rgb, tolerance)) {
		rgb = replace_light.rgb;
	} else if (matches(rgb, key_dark.rgb, tolerance)) {
		rgb = replace_dark.rgb;
	}

	rgb = mix(rgb, flash_color.rgb, flash_amount * tex.a);
	COLOR = vec4(rgb, tex.a) * COLOR;
}
