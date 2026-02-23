shader_type canvas_item;
uniform float distortion_intensity : hint_range(0, 3) = 0.0;

void fragment() {
    float r = texture(TEXTURE, UV + distortion_intensity*TEXTURE_PIXEL_SIZE).r;
    float g = texture(TEXTURE, UV + vec2(0.0, 0.0)).g;
    float b = texture(TEXTURE, UV - distortion_intensity*TEXTURE_PIXEL_SIZE).b;
    float a = texture(TEXTURE, UV).a;
    COLOR = vec4(r, g, b, a);
}