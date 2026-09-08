#version 320 es
precision highp float;

in  vec2 v_texcoord;
out vec4 fragColor;

uniform sampler2D tex;
uniform float time;
uniform float is_active;
uniform vec2  surface_size;

// ---- tuning -------------------------------------------------
const vec3  TINT           = vec3(0.918, 0.647, 0.722); // #eaa5b8
const float TINT_AMOUNT    = 0.075;

const float BURST_PERIOD   = 2.0;
const float BURST_LENGTH   = 0.12;

const float SCALE_AMOUNT   = 0.060;  // zoom pulse during burst
const float DISPLACE_X     = 0.060;
const float DISPLACE_Y     = 0.024;
const float BLOCK_PX       = 26.0;
const float TEAR_AMOUNT    = 0.110;
const float CA_IDLE        = 0.0010;
const float CA_BURST       = 0.0120;

const float SCANLINE_IDLE  = 0.022;
const float SCANLINE_BURST = 0.060;
const float SCANLINE_FREQ  = 2.1;

const float GRAIN_IDLE     = 0.060;
const float GRAIN_SIZE     = 0.5;    // lower = coarser specks
const float NOISE          = 0.140;
// -------------------------------------------------------------

float hash(float n) {
    return fract(sin(n) * 43758.5453123);
}

float hash2(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453123);
}

void main() {
    vec2  uv  = v_texcoord;
    float amt = is_active;

    float cycle = floor(time / BURST_PERIOD);
    float phase = fract(time / BURST_PERIOD) * BURST_PERIOD;
    float burst = step(phase, BURST_LENGTH) * amt;

    float stepIdx = floor(phase / (BURST_LENGTH / 3.0));
    float seed    = cycle * 17.0 + stepIdx * 5.0;

    // scale pulse
    float scaleAmt = 1.0 + (hash(seed * 6.1) - 0.5) * SCALE_AMOUNT * burst;
    uv = (uv - 0.5) / scaleAmt + 0.5;

    // whole-window displacement
    float dx = (hash(seed * 1.7) - 0.5) * 2.0 * DISPLACE_X * burst;
    float dy = (hash(seed * 4.3) - 0.5) * 2.0 * DISPLACE_Y * burst;
    uv += vec2(dx, dy);

    // horizontal block tearing
    float band     = floor(uv.y * surface_size.y / BLOCK_PX);
    float bandRand = hash(band * 37.0 + seed);
    float tear     = (bandRand - 0.5) * TEAR_AMOUNT * burst;
    tear          *= step(0.55, bandRand);
    uv.x += tear;

    // chromatic aberration
    float edge = length(v_texcoord - 0.5) * 1.4;
    float ca   = (CA_IDLE * amt + CA_BURST * burst) * (0.4 + edge);

    float r = texture(tex, uv + vec2(ca, 0.0)).r;
    float g = texture(tex, uv).g;
    float b = texture(tex, uv - vec2(ca, 0.0)).b;
    float a = texture(tex, uv).a;

    vec3 col = vec3(r, g, b);

    // scanlines, following the displaced content
    float lines = sin(uv.y * surface_size.y * SCANLINE_FREQ);
    col -= lines * (SCANLINE_IDLE * amt + SCANLINE_BURST * burst);

    // permanent film grain
    float grain = hash2(v_texcoord * surface_size * GRAIN_SIZE + floor(time * 24.0)) - 0.5;
    col += grain * GRAIN_IDLE * amt;

    // burst static
    col += (hash2(uv * 640.0 + time) - 0.5) * NOISE * burst;

    col = mix(col, TINT, TINT_AMOUNT * amt);

    fragColor = vec4(col, a);
}
