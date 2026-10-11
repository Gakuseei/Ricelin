#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
};

layout(binding = 1) uniform sampler2D source;

float hash12(vec2 p)
{
    vec3 p3 =
        fract(
            vec3(p.xyx) *
            0.1031
        );

    p3 +=
        dot(
            p3,
            p3.yzx + 33.33
        );

    return fract(
        (p3.x + p3.y) * p3.z
    );
}

void main()
{
    vec2 uv = qt_TexCoord0;
    vec4 tex = texture(source, uv);

    vec3 c = tex.rgb;

    /*
     * Very subtle vignette.
     */
    vec2 d = uv - vec2(0.5);

    float dist =
        length(d) * 1.4142;

    float vignette =
        smoothstep(
            0.18,
            0.95,
            dist
        );

    c *=
        mix(
            1.0,
            0.88,
            vignette
        );

    /*
     * Extremely faint static grain.
     */
    float noise =
        hash12(
            floor(
                uv *
                vec2(
                    1920.0,
                    1200.0
                )
            )
        ) - 0.5;

    c += noise * 0.012;

    fragColor =
        vec4(
            clamp(c, 0.0, 1.0),
            tex.a
        ) *
        qt_Opacity;
}
