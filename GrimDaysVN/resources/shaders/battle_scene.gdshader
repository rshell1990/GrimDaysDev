shader_type canvas_item;
uniform sampler2D noise_texture;
uniform sampler2D burn_texture;
uniform float integrity: hint_range(0.0, 1.33) = 1.33;

uniform float burn_size: hint_range(1.0, 3.0) = 1.25;
float inverse_lerp(float destination, float beginning, float percent){
	return smoothstep((percent - destination) / (beginning - destination),destination,0);
}

void fragment() {
	// Called for every pixel the material is visible on.
	float noise = 1.0 - (texture(noise_texture, UV).r * UV.x);
	vec4 base = vec4(0.0, 0.0, 0.0, 1.0) * step(noise, integrity);
	vec2 burn_uv = vec2(inverse_lerp(integrity, integrity * burn_size, noise), 0.0);
	vec4 burn_color = texture(burn_texture, burn_uv) * step(noise, integrity * burn_size);
	COLOR = mix(burn_color, base, base.a);
}
