shader_type canvas_item;
uniform float speed:hint_range(0.5, 5.0, 0.5) = 1.0;

void fragment() {
	vec2 new_uv = vec2(UV.x - TIME * speed, UV.y);
	COLOR = texture(TEXTURE, new_uv);
	vec4 color = vec4(0.0, 1.0 * COLOR.g, 1.0, COLOR.a);
	vec4 color2 = vec4(1.0 * COLOR.r, 0.25, 0.0, COLOR.a);
	COLOR = color;
	// Called for every pixel the material is visible on.
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
