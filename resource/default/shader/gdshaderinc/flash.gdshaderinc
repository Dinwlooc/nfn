#ifndef FLASH_INC
#define FLASH_INC

instance uniform vec4 flash_color : source_color = vec4(1.0);
instance uniform float flash_intensity : hint_range(0, 1) = 0.0;
instance uniform float alpha : hint_range(0, 1) = 1.0;

vec4 apply_flash(vec4 color) {
    color.rgb = mix(color.rgb, flash_color.rgb, flash_intensity);
    color.a *= alpha;
    return color;
}
#endif