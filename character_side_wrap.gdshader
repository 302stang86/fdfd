shader_type spatial;
render_mode cull_disabled, diffuse_burley;

uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
varying vec3 model_normal;

void vertex() {
	model_normal = NORMAL;
}

void fragment() {
	vec3 n = normalize(model_normal);
	bool front = UV.x < 0.5;
	vec2 front_uv = vec2(front ? UV.x : UV.x - 0.5, UV.y);
	vec3 front_color = texture(atlas, front_uv).rgb;
	vec3 back_color = texture(atlas, front_uv + vec2(0.5, 0.0)).rgb;
	float side = smoothstep(0.25, 0.92, abs(n.x));
	float blend = mix(front ? 0.0 : 1.0, 0.5, side);
	ALBEDO = mix(front_color, back_color, blend);
	ROUGHNESS = 0.86;
}
