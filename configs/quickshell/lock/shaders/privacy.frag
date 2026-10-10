#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;

    vec2 srcSize;

    float darken;
    float maskP;

    float pillW;
    float pillH;
    float pillY;
};

layout(binding = 1) uniform sampler2D source;

vec4 cubicW(float t)
{
    float t2 = t * t;
    float t3 = t2 * t;

    return vec4(
        (-t3 + 3.0*t2 - 3.0*t + 1.0) / 6.0,
        ( 3.0*t3 - 6.0*t2 + 4.0) / 6.0,
        (-3.0*t3 + 3.0*t2 + 3.0*t + 1.0) / 6.0,
        t3 / 6.0
    );
}

vec3 bicubicSample(vec2 uv)
{
    vec2 pos = uv * srcSize - 0.5;
    vec2 base = floor(pos);
    vec2 f = pos - base;

    vec4 wx = cubicW(f.x);
    vec4 wy = cubicW(f.y);

    vec3 acc = vec3(0.0);

    for (int j = -1; j <= 2; ++j) {
        for (int i = -1; i <= 2; ++i) {
            vec2 tc =
                (
                    base +
                    vec2(float(i), float(j)) +
                    0.5
                ) / srcSize;

            tc = clamp(
                tc,
                vec2(0.0),
                vec2(1.0)
            );

            acc +=
                texture(source, tc).rgb *
                wx[i + 1] *
                wy[j + 1];
        }
    }

    return acc;
}

/*
 * Small final smoothing pass.
 *
 * The heavy privacy blur has already happened at 320x200.
 * This pass only removes residual interpolation/grid structure
 * from the reconstruction.
 */
vec3 smoothReconstruction(vec2 uv)
{
    vec2 texel = 1.0 / srcSize;

    vec3 c = vec3(0.0);

    c += bicubicSample(uv) * 0.36;

    c += bicubicSample(
        uv + vec2(texel.x, 0.0)
    ) * 0.10;

    c += bicubicSample(
        uv - vec2(texel.x, 0.0)
    ) * 0.10;

    c += bicubicSample(
        uv + vec2(0.0, texel.y)
    ) * 0.10;

    c += bicubicSample(
        uv - vec2(0.0, texel.y)
    ) * 0.10;

    c += bicubicSample(
        uv + vec2(texel.x, texel.y)
    ) * 0.06;

    c += bicubicSample(
        uv + vec2(-texel.x, texel.y)
    ) * 0.06;

    c += bicubicSample(
        uv + vec2(texel.x, -texel.y)
    ) * 0.06;

    c += bicubicSample(
        uv + vec2(-texel.x, -texel.y)
    ) * 0.06;

    return c;
}

float roundedRectSdf(
    vec2 p,
    vec2 halfSize,
    float radius
)
{
    vec2 q =
        abs(p) -
        halfSize +
        vec2(radius);

    return
        length(max(q, vec2(0.0))) +
        min(max(q.x, q.y), 0.0) -
        radius;
}

void main()
{
    vec2 uv = qt_TexCoord0;

    /*
     * Reconstruct from the already heavily blurred 320x200
     * privacy texture.
     */
    vec3 col =
        smoothReconstruction(uv);

    /*
     * Overall reduction.
     */
    col *= darken;

    /*
     * Strong desaturation.
     *
     * This prevents bright application colours from remaining
     * recognizable through the privacy layer.
     */
    float luminance =
        dot(
            col,
            vec3(
                0.2126,
                0.7152,
                0.0722
            )
        );

    col =
        mix(
            vec3(luminance),
            col,
            0.52
        );

    /*
     * Stronger highlight compression.
     *
     * In particular, large white browser/terminal areas should
     * become muted gray instead of glowing white.
     */
    col =
        col /
        (1.0 + col * 1.15);

    /*
     * Overall privacy-layer luminance.
     */
    col *= 0.70;

    /*
     * Keep shadows from becoming completely crushed.
     */
    col =
        pow(
            max(col, vec3(0.0)),
            vec3(1.08)
        );

    /*
     * Soft vignette.
     */
    vec2 d =
        uv -
        vec2(0.5);

    float vignette =
        smoothstep(
            0.95,
            0.40,
            length(d)
        );

    col *=
        mix(
            0.84,
            1.0,
            vignette
        );

    /*
     * Tiny dither.
     */
    float n =
        fract(
            sin(
                dot(
                    uv,
                    vec2(
                        12.9898,
                        78.233
                    )
                )
            ) *
            43758.5453
        );

    col +=
        (n - 0.5) *
        (2.0 / 255.0);

    /*
     * --------------------------------------------------------
     * PILL MASK
     * --------------------------------------------------------
     */

    float w =
        mix(
            pillW,
            1.0,
            maskP
        );

    float h =
        mix(
            pillH,
            1.0,
            maskP
        );

    vec2 center =
        vec2(
            0.5,
            h * 0.5 +
            pillY * (1.0 - maskP)
        );

    vec2 halfSize =
        vec2(w, h) * 0.5;

    float radius =
        min(
            halfSize.x,
            halfSize.y
        ) *
        (1.0 - maskP);

    float sdf =
        roundedRectSdf(
            uv - center,
            halfSize,
            radius
        );

    float edge =
        max(
            fwidth(sdf) * 1.5,
            0.0008
        );

    float hole =
        1.0 -
        smoothstep(
            -edge,
            edge,
            sdf
        );

    float alpha =
        1.0 - hole;

    fragColor =
        vec4(
            col,
            alpha
        ) *
        qt_Opacity;
}
