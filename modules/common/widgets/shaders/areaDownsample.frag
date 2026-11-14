#version 440
// Downscale with a Catmull-Rom cubic kernel stretched over each output pixel's
// footprint in the source texture. Plain bilinear skips texels when shrinking a
// large capture, so small text aliases. This kernel covers every texel, and the
// negative lobes keep it sharper than a box average.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 texelStep; // 1 / source texture size
    vec2 footprint; // source texels per output pixel
};

layout(binding = 1) uniform sampler2D source;

// Taps per side, per axis. Covers a footprint up to 4 texels without skipping.
// SmoothScreencopyView pre-shrinks the capture so the footprint stays near 2-3.
const int MAX_TAPS = 8;

float catmullRom(float x) {
    x = abs(x);
    if (x < 1.0) return (1.5 * x - 2.5) * x * x + 1.0;
    if (x < 2.0) return ((-0.5 * x + 2.5) * x - 4.0) * x + 2.0;
    return 0.0;
}

void main() {
    vec2 scale = max(footprint, vec2(1.0));
    vec2 radius = 2.0 * scale; // kernel support in texels
    // Widen the stride only when the kernel needs more taps than MAX_TAPS.
    vec2 stride = max(vec2(1.0), ceil(radius / float(MAX_TAPS)));
    vec2 pos = qt_TexCoord0 / texelStep; // in texels
    vec2 base = floor(pos - 0.5) + 0.5;  // nearest texel centre at or below

    // Separable weights: compute each axis once, not once per tap.
    float wx[2 * MAX_TAPS + 1];
    float wy[2 * MAX_TAPS + 1];
    for (int i = 0; i <= 2 * MAX_TAPS; i++) {
        float o = float(i - MAX_TAPS);
        wx[i] = catmullRom((base.x + o * stride.x - pos.x) / scale.x);
        wy[i] = catmullRom((base.y + o * stride.y - pos.y) / scale.y);
    }

    vec4 acc = vec4(0.0);
    float weightSum = 0.0;
    for (int j = 0; j <= 2 * MAX_TAPS; j++) {
        if (wy[j] == 0.0) continue;
        float ty = base.y + float(j - MAX_TAPS) * stride.y;
        for (int i = 0; i <= 2 * MAX_TAPS; i++) {
            if (wx[i] == 0.0) continue;
            float tx = base.x + float(i - MAX_TAPS) * stride.x;
            float w = wx[i] * wy[j];
            acc += w * texture(source, vec2(tx, ty) * texelStep);
            weightSum += w;
        }
    }
    fragColor = clamp(acc / weightSum, 0.0, 1.0) * qt_Opacity;
}
