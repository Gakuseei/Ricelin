#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 resolution;
};

layout(binding = 1) uniform sampler2D source;

void main()
{
    vec2 px = 1.0 / resolution;
    vec2 uv = qt_TexCoord0;

    /*
     * Broad, isotropic averaging at 240x150.
     *
     * The weighting favours the centre while spreading luminance
     * in both axes and diagonals. The goal is specifically to break
     * the coherence of horizontal text rows.
     */
    vec3 c =
          texture(source, uv).rgb * 0.24

        + texture(source, uv + px * vec2( 1.0,  0.0)).rgb * 0.095
        + texture(source, uv + px * vec2(-1.0,  0.0)).rgb * 0.095

        + texture(source, uv + px * vec2( 0.0,  1.0)).rgb * 0.095
        + texture(source, uv + px * vec2( 0.0, -1.0)).rgb * 0.095

        + texture(source, uv + px * vec2( 1.0,  1.0)).rgb * 0.0675
        + texture(source, uv + px * vec2(-1.0,  1.0)).rgb * 0.0675

        + texture(source, uv + px * vec2( 1.0, -1.0)).rgb * 0.0675
        + texture(source, uv + px * vec2(-1.0, -1.0)).rgb * 0.0675;

    fragColor = vec4(c, 1.0) * qt_Opacity;
}
