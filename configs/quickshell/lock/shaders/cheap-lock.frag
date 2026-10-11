#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;

    vec2 resolution;

    float maskP;
    float darken;
    float blurRadius;

    float pillW;
    float pillH;
    float pillY;
};

layout(binding = 1) uniform sampler2D source;

float roundedRectSdf(vec2 p, vec2 halfSize, float radius)
{
    vec2 q = abs(p) - halfSize + vec2(radius);
    return length(max(q, vec2(0.0)))
        + min(max(q.x, q.y), 0.0)
        - radius;
}

vec4 cheapBlur(vec2 uv)
{
    vec2 t = blurRadius / resolution;

    vec4 c = vec4(0.0);

    // Center
    c += texture(source, uv) * 0.20;

    // Cardinal samples
    c += texture(source, uv + vec2( 1.0,  0.0) * t) * 0.14;
    c += texture(source, uv + vec2(-1.0,  0.0) * t) * 0.14;
    c += texture(source, uv + vec2( 0.0,  1.0) * t) * 0.14;
    c += texture(source, uv + vec2( 0.0, -1.0) * t) * 0.14;

    // Diagonal samples
    c += texture(source, uv + vec2( 1.0,  1.0) * t) * 0.06;
    c += texture(source, uv + vec2(-1.0,  1.0) * t) * 0.06;
    c += texture(source, uv + vec2( 1.0, -1.0) * t) * 0.06;
    c += texture(source, uv + vec2(-1.0, -1.0) * t) * 0.06;

    return c;
}

void main()
{
    vec2 uv = qt_TexCoord0;

    /*
     * One 9-sample blur replaces the whole downsample +
     * six-pass blur chain from the original lockscreen.
     */
    vec3 col = cheapBlur(uv).rgb;

    /*
     * Cheap replacement for grade.frag:
     * darken + subtle vignette.
     */
    col *= darken;

    vec2 d = uv - vec2(0.5);
    float dist = length(d);

    float vignette = smoothstep(0.95, 0.30, dist);
    col *= mix(0.86, 1.0, vignette);

    /*
     * Reconstruct the original pill growth:
     *
     * maskP = 0 -> small pill
     * maskP = 1 -> full-screen transparent region
     */
    float w = mix(pillW, 1.0, maskP);
    float h = mix(pillH, 1.0, maskP);

    vec2 center = vec2(
        0.5,
        0.5 * h + pillY * (1.0 - maskP)
    );

    vec2 halfSize = vec2(w, h) * 0.5;

    float radius = 0.5 * min(w, h) * (1.0 - maskP);

    float sdf = roundedRectSdf(
        uv - center,
        halfSize,
        radius
    );

    /*
     * A small edge width gives us the same smooth transition
     * that the old MultiEffect mask was providing.
     */
    float edge = fwidth(sdf) * 1.5;
    float hole = 1.0 - smoothstep(-edge, edge, sdf);

    /*
     * Outside the pill:
     *   show blurred/darkened desktop.
     *
     * Inside:
     *   transparent, exposing the actual lock UI underneath.
     */
    float alpha = 1.0 - hole;

    fragColor = vec4(col, alpha) * qt_Opacity;
}
