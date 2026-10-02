shader_type canvas_item;

void fragment() {
	vec4 pixel = texture(TEXTURE, UV) * COLOR;
	// The generated violet panes become actual translucent blue service glass.
	if (pixel.r > pixel.g * 1.1 && pixel.b > pixel.g * 1.2 && pixel.r > 0.3 && pixel.b > 0.5) {
		pixel.rgb = vec3(0.50, 0.72, 0.76);
		pixel.a *= 0.22;
	}
	COLOR = pixel;
}
