shader_type canvas_item;
uniform sampler2D SCREEN_TEXTURE:hint_screen_texture,filter_linear;
uniform float red: hint_range(0.0, 1) = 1;
uniform float blue: hint_range(0.0, 1) = 1;
uniform float green:hint_range(0.0, 1) = 1;
uniform float alpha:hint_range(0.0, 1) = 1;
uniform vec2 amplitutde = vec2(1.0, 0.0);
uniform vec2 speed = vec2(1.0, 0.0);
void fragment(){
	vec2 pos = mod((UV - amplitutde * sin(TIME + vec2(UV.y, UV.x) * speed)) / TEXTURE_PIXEL_SIZE,
			1.0 / TEXTURE_PIXEL_SIZE) * TEXTURE_PIXEL_SIZE;
	vec3 color = texture(TEXTURE, pos).rgb;
	COLOR = vec4(color.r, color.g, color.b,alpha);
}