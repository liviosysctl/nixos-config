// Balatro-Style-Hintergrund für Ghostty (Shadertoy-kompatibler Custom-Shader)
//
// Algorithmus portiert nach den öffentlichen Ports des Balatro-Hintergrunds:
//   Shadertoy: https://www.shadertoy.com/view/XXtBRr
//   Godot:     https://godotshaders.com/shader/balatro-background-shader/
// Die Vorlagen stehen unter CC BY-NC-SA 3.0.
//
// Stellschrauben für die Lesbarkeit (von oben nach unten in der Wirkung):
//   BG_DIM       - 0.0 = komplett DIM_COLOUR, 1.0 = Originalhelligkeit
//   SATURATION   - 0.0 = graustufen, 1.0 = volle Farbe
//   LIGHTING     - Glanzlichter
//   CONTRAST     - höher = härtere Farbtrennung

const float SPIN_ROTATION = -2.0;
const float SPIN_SPEED    = 7.0;
const vec2  OFFSET        = vec2(0.0, 0.0);
const vec4  COLOUR_1      = vec4(0.871, 0.267, 0.231, 1.0);
const vec4  COLOUR_2      = vec4(0.000, 0.420, 0.706, 1.0);
const vec4  COLOUR_3      = vec4(0.086, 0.137, 0.145, 1.0);
const float CONTRAST      = 3.5;
const float LIGHTING      = 0.10;
const float SPIN_AMOUNT   = 0.25;
const float PIXEL_FILTER  = 745.0;
const float SPIN_EASE     = 1.0;

// Nachbearbeitung für die Lesbarkeit
const float BG_DIM     = 0.25;
const float SATURATION = 0.70;
const vec3  DIM_COLOUR = vec3(0.114, 0.125, 0.129);

vec4 balatro(vec2 size, vec2 coord, float time) {
    // Pixelraster: erzeugt den groben "gemalten" Look
    float pixelSize = length(size) / PIXEL_FILTER;
    vec2  uv        = (floor(coord * (1.0 / pixelSize)) * pixelSize - 0.5 * size)
                      / length(size) - OFFSET;
    float uvLen     = length(uv);

    // Statische Verdrehung um das Bildzentrum
    float spin     = SPIN_ROTATION * SPIN_EASE * 0.2 + 302.2;
    float newAngle = atan(uv.y, uv.x) + spin
                   - SPIN_EASE * 20.0 * (SPIN_AMOUNT * uvLen + (1.0 - SPIN_AMOUNT));

    // Entspricht dem Original; der dortige mid-Term hebt sich rechnerisch auf
    uv = vec2(uvLen * cos(newAngle), uvLen * sin(newAngle));

    uv *= 30.0;
    float speed = time * SPIN_SPEED;
    vec2  uv2   = vec2(uv.x + uv.y);

    for (int i = 0; i < 5; i++) {
        uv2 += sin(max(uv.x, uv.y)) + uv;
        uv  += 0.5 * vec2(cos(5.1123314 + 0.353 * uv2.y + speed * 0.131121),
                          sin(uv2.x - 0.113 * speed));
        uv  -= cos(uv.x + uv.y) - sin(uv.x * 0.711 - uv.y);
    }

    float contrastMod = 0.25 * CONTRAST + 0.5 * SPIN_AMOUNT + 1.2;
    float paintRes    = min(2.0, max(0.0, length(uv) * 0.035 * contrastMod));
    float c1p         = max(0.0, 1.0 - contrastMod * abs(1.0 - paintRes));
    float c2p         = max(0.0, 1.0 - contrastMod * abs(paintRes));
    float c3p         = 1.0 - min(1.0, c1p + c2p);

    float light = (LIGHTING - 0.2) * max(c1p * 5.0 - 4.0, 0.0)
                + LIGHTING * max(c2p * 5.0 - 4.0, 0.0);

    return (0.3 / CONTRAST) * COLOUR_1
         + (1.0 - 0.3 / CONTRAST) * (COLOUR_1 * c1p
                                   + COLOUR_2 * c2p
                                   + vec4(c3p * COLOUR_3.rgb, c3p * COLOUR_1.a))
         + light;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec3 background = balatro(iResolution.xy, fragCoord, iTime).rgb;

    // Entsättigen: nimmt dem Rot die Konkurrenz zu roter Vordergrundschrift
    float luma = dot(background, vec3(0.2126, 0.7152, 0.0722));
    background = mix(vec3(luma), background, SATURATION);

    // Abdunkeln gegen die Terminal-Hintergrundfarbe
    background = mix(DIM_COLOUR, background, BG_DIM);

    vec4 terminal = texture(iChannel0, fragCoord / iResolution.xy);
    fragColor = vec4(mix(background, terminal.rgb, terminal.a), 1.0);
}
