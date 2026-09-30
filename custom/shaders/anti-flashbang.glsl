#version 300 es
precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

// Anti-flashbang: soft-compress the top of the luminance range so
// full-white frames (page loads, modals, game flashes) can't hit peak
// panel brightness. Below CEIL everything is untouched.
//
//   CEIL : compression starts above this level (0.55)
//   PEAK : pure white (1.0) is remapped down to this (0.85)
//   KNEE : higher = harder knee at the start of the curve (2.0)
//
// Tweak and run: hyprctl reload
//
// GLSL VERSION — empirically pinned 2026-09-19 (see .swarm/LOG.md):
// this hyprland-git build links its vertex stage as GLSL ES 3.00.
//   #version 310 es  → "all shaders must use same shading language
//                       version" link failure (deterministic, journaled)
//   no #version      → links clean (Hyprland manages the version), but
//                      legacy varying/texture2D/gl_FragColor syntax does
//                      NOT compile — use in/texture()/explicit out
//   #version 300 es  → links clean (chosen: explicit + self-documenting)
// Verified via hyprctl eval + journalctl at 2026-09-19 06:39.

const float CEIL = 0.55;
const float PEAK = 0.85;
const float KNEE = 2.0;

void main() {
    vec4 c = texture(tex, v_texcoord);
    for (int i = 0; i < 3; i++) {
        float x = c[i];
        if (x > CEIL) {
            float t = (x - CEIL) / (1.0 - CEIL);            // 0..1
            t = t * (1.0 + KNEE) / (1.0 + KNEE * t);        // soft knee, t(1) = 1
            c[i] = CEIL + t * (PEAK - CEIL);
        }
    }
    fragColor = c;
}
