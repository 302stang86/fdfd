shader_type spatial;
render_mode cull_disabled, diffuse_burley;

uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D rear_atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 rear_layout;
uniform float front_center;
uniform bool bunny_head = false;
varying vec3 model_normal;

void vertex() {
	model_normal = NORMAL;
}

void fragment() {
	vec3 n = normalize(model_normal);
	bool front = UV.x < 0.5;
	vec2 front_uv = vec2(front ? UV.x : UV.x - 0.5, UV.y);
	vec3 front_color = texture(atlas, front_uv).rgb;
	float rear_x = rear_layout.x - (front_uv.x * 708.0 - front_center) * rear_layout.w;
	float height = clamp((UV.y - 0.025) / 0.94, 0.0, 1.0);
	float rear_y = rear_layout.y + height * rear_layout.z;
	vec3 back_color = texture(rear_atlas, vec2(rear_x / 1536.0, rear_y / 1024.0)).rgb;
	float side = smoothstep(0.25, 0.92, abs(n.x));
	float blend = mix(front ? 0.0 : 1.0, 0.5, side);
	vec3 color = mix(front_color, back_color, blend);
	if (bunny_head) {
		// Keep the face projection on the front and use the rear artwork along the hairline.
		float hair_band = smoothstep(0.081, 0.098, UV.y) * (1.0 - smoothstep(0.224, 0.242, UV.y));
		color = mix(color, back_color, hair_band * smoothstep(0.38, 0.86, abs(n.x)));
	}
	ALBEDO = color;
	ROUGHNESS = 0.86;
}
