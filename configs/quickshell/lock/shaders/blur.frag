#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 resolution;
    vec2 blurDir;
};
layout(binding = 1) uniform sampler2D source;

const float w0 = 0.227027;
const float w1 = 0.1945946;
const float w2 = 0.1216216;
const float w3 = 0.054054;
const float w4 = 0.016216;

void main() {
    vec2 texel = (blurDir * 6.0) / resolution;
    vec4 col = texture(source, qt_TexCoord0) * w0;
    col += texture(source, qt_TexCoord0 + texel * 1.0) * w1;
    col += texture(source, qt_TexCoord0 - texel * 1.0) * w1;
    col += texture(source, qt_TexCoord0 + texel * 2.0) * w2;
    col += texture(source, qt_TexCoord0 - texel * 2.0) * w2;
    col += texture(source, qt_TexCoord0 + texel * 3.0) * w3;
    col += texture(source, qt_TexCoord0 - texel * 3.0) * w3;
    col += texture(source, qt_TexCoord0 + texel * 4.0) * w4;
    col += texture(source, qt_TexCoord0 - texel * 4.0) * w4;
    fragColor = col * qt_Opacity;
}
