shader_type spatial;
render_mode cull_disabled, diffuse_burley;

uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D rear_atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform vec2 front_cell;
uniform vec2 rear_cell;
uniform bool has_back = false;
varying vec3 local_normal;

void vertex() {
	local_normal = NORMAL;
}

void fragment() {
	vec3 n = normalize(local_normal);
	vec3 fabric = texture(atlas, UV).rgb;
	if (has_back) {
		vec3 back = texture(atlas, vec2(1.0 - UV.x, UV.y)).rgb;
		ALBEDO = mix(fabric, back, smoothstep(-0.18, 0.34, -n.z));
	} else {
		vec2 local_uv = UV * vec2(3.0, 2.0) - front_cell;
		local_uv.x = 0.5 - (local_uv.x - 0.5) * 0.96;
		vec2 back_uv = (rear_cell + local_uv) / vec2(3.0, 2.0);
		vec3 back = texture(rear_atlas, back_uv).rgb;
		ALBEDO = mix(fabric, back, smoothstep(-0.18, 0.34, -n.z));
	}
	ROUGHNESS = 0.86;
}
