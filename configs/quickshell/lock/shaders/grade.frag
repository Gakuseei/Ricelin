#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 accent;
    float intensity;
};
layout(binding = 1) uniform sampler2D source;

void main() {
    vec4 src = texture(source, qt_TexCoord0);
    float lum = dot(src.rgb, vec3(0.299, 0.587, 0.114));
    vec3 tinted = accent.rgb * (0.35 + 0.9 * lum);
    vec3 graded = mix(src.rgb, tinted, intensity);
    graded *= 0.5;

    vec2 d = qt_TexCoord0 - vec2(0.5);
    float vig = smoothstep(0.85, 0.35, length(d));
    graded *= mix(0.55, 1.0, vig);

    fragColor = vec4(graded, src.a) * qt_Opacity;
}
