#version 440

// Rim-only variant of frostedLens.frag for live blur: no backdrop of its own.
// The compositor blurs the real windows behind the layer; this draws only the
// tint wash, the lit rim and the top sheen over it, translucent.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    vec4 radii;
    vec4 wash;
    float qt_Opacity;
    vec2 size;
    float rimWidth;
    float sheen;
};

float roundedDist(vec2 p, vec2 half_, vec4 radii) {
    float r = p.x > 0.0 ? (p.y > 0.0 ? radii.z : radii.y) : (p.y > 0.0 ? radii.w : radii.x);
    r = min(r, min(half_.x, half_.y));
    vec2 q = abs(p) - half_ + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

void main() {
    vec2 p = qt_TexCoord0 * size - size * 0.5;
    float d = roundedDist(p, size * 0.5, radii);
    float cover = clamp(0.5 - d, 0.0, 1.0);
    if (cover <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }

    float depth = max(-d, 0.0);
    vec2 e = vec2(0.8, 0.0);
    vec2 n = vec2(
        roundedDist(p + e.xy, size * 0.5, radii) - roundedDist(p - e.xy, size * 0.5, radii),
        roundedDist(p + e.yx, size * 0.5, radii) - roundedDist(p - e.yx, size * 0.5, radii));
    n = length(n) > 1e-4 ? normalize(n) : vec2(0.0, -1.0);

    vec2 L = normalize(vec2(-0.6, -0.8));
    float facing = dot(n, L);
    float lit = pow(max(facing, 0.0), 2.0);
    float back = pow(max(-facing, 0.0), 2.5);

    float hairline = exp(-depth / 0.9);
    float soft = exp(-depth / (rimWidth * 0.55));
    float glint = (hairline * (0.22 + 0.7 * lit) + soft * 0.16 * lit + hairline * 0.12 * back) * sheen;

    float top = 1.0 - smoothstep(0.0, size.y * 0.55, p.y + size.y * 0.5);
    float light = clamp(glint + 0.035 * top * sheen, 0.0, 1.0);

    // Premultiplied: tint wash, then white light added on top of it.
    vec3 col = wash.rgb * wash.a * (1.0 - light) + vec3(light);
    float a = wash.a + light * (1.0 - wash.a);
    fragColor = vec4(col, a) * cover * qt_Opacity;
}
