shader_type canvas_item;

uniform float pixel_size : hint_range(1.0, 10.0) = 4.0;
uniform float scanline_count : hint_range(0.0, 1080.0) = 240.0;
uniform float scanline_opacity : hint_range(0.0, 1.0) = 0.15;
uniform float noise_opacity : hint_range(0.0, 1.0) = 0.12;
uniform float crt_curve : hint_range(0.0, 0.1) = 0.02;
uniform float color_depth : hint_range(2.0, 256.0) = 16.0;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;

float rand(vec2 co) {
	return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	
	// 1. CRT Screen Curvature
	vec2 centered_uv = uv - 0.5;
	float dist = dot(centered_uv, centered_uv);
	uv += centered_uv * dist * crt_curve;
	
	// Khắc phục lỗi return trong fragment shader bằng cách dùng cấu trúc điều kiện sạch
	if (uv.x >= 0.0 && uv.y >= 0.0 && uv.x <= 1.0 && uv.y <= 1.0) {
		// 2. Pixelation
		vec2 size = vec2(textureSize(screen_texture, 0));
		vec2 pixelated_uv = floor(uv * size / pixel_size) / (size / pixel_size);
		
		// Lấy màu gốc từ camera
		vec4 color = texture(screen_texture, pixelated_uv);
		
		// 3. Color Depth Reduction
		color.rgb = floor(color.rgb * color_depth) / color_depth;
		
		// 4. VHS Scanlines
		float scanline = sin(uv.y * scanline_count * 3.14159 * 2.0);
		scanline = (scanline + 1.0) / 2.0;
		scanline = mix(1.0, scanline, scanline_opacity);
		color.rgb *= scanline;
		
		// 5. Retro Noise
		float noise = rand(pixelated_uv + vec2(TIME * 0.1, TIME * 0.2));
		color.rgb = mix(color.rgb, vec3(noise), noise_opacity);
		
		COLOR = color;
	} else {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	}
}
