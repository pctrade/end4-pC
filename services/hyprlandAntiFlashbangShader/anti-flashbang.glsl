#version 300 es
precision highp float;

in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

const float xArr[100] = float[100](
    0.524424,
    0.757104,
    0.712524,
    0.372869,
    0.546936,
    0.785575,
    0.583935,
    0.966261,
    0.791299,
    0.914405,
    0.327858,
    0.222805,
    0.013719,
    0.581235,
    0.825459,
    0.032428,
    0.138672,
    0.202245,
    0.218987,
    0.235640,
    0.883093,
    0.466539,
    0.907539,
    0.456385,
    0.677000,
    0.168533,
    0.374208,
    0.030070,
    0.651974,
    0.612810,
    0.499243,
    0.016618,
    0.514704,
    0.147730,
    0.235128,
    0.898295,
    0.377490,
    0.674315,
    0.192288,
    0.453870,
    0.803407,
    0.983204,
    0.327036,
    0.189823,
    0.022437,
    0.794536,
    0.430916,
    0.692189,
    0.026218,
    0.383421,
    0.981936,
    0.723354,
    0.662753,
    0.704429,
    0.543276,
    0.814431,
    0.345419,
    0.995111,
    0.917148,
    0.572285,
    0.908263,
    0.125383,
    0.369796,
    0.287034,
    0.062046,
    0.662455,
    0.295098,
    0.097347,
    0.509777,
    0.150653,
    0.135876,
    0.966176,
    0.787048,
    0.296717,
    0.992242,
    0.061566,
    0.862595,
    0.112158,
    0.580177,
    0.587506,
    0.453414,
    0.960039,
    0.034981,
    0.898977,
    0.739571,
    0.276473,
    0.998462,
    0.981235,
    0.133311,
    0.998454,
    0.040129,
    0.581457,
    0.832492,
    0.435475,
    0.231341,
    0.317130,
    0.418493,
    0.232571,
    0.998287,
    0.484547
  );

const float yArr[100] = float[100](
    0.707067,
    0.643413,
    0.024870,
    0.627259,
    0.130156,
    0.217812,
    0.343515,
    0.802662,
    0.758989,
    0.423022,
    0.503179,
    0.076816,
    0.613117,
    0.871732,
    0.008390,
    0.931091,
    0.509269,
    0.804107,
    0.686850,
    0.941827,
    0.898836,
    0.313488,
    0.682849,
    0.470537,
    0.980769,
    0.006122,
    0.202473,
    0.103496,
    0.467435,
    0.607021,
    0.034206,
    0.437461,
    0.588862,
    0.355828,
    0.419150,
    0.106557,
    0.046525,
    0.726699,
    0.223232,
    0.784699,
    0.337484,
    0.011415,
    0.811939,
    0.596248,
    0.224879,
    0.509354,
    0.905772,
    0.552261,
    0.809134,
    0.359255,
    0.899678,
    0.867174,
    0.113315,
    0.344995,
    0.438910,
    0.966996,
    0.715332,
    0.292732,
    0.564394,
    0.243018,
    0.334071,
    0.848972,
    0.977347,
    0.604240,
    0.334429,
    0.234025,
    0.144593,
    0.173680,
    0.969456,
    0.970249,
    0.738080,
    0.182993,
    0.115703,
    0.268195,
    0.616186,
    0.018278,
    0.812381,
    0.652383,
    0.775953,
    0.020496,
    0.141973,
    0.994130,
    0.719552,
    0.246193,
    0.426230,
    0.002264,
    0.389338,
    0.492728,
    0.089798,
    0.712663,
    0.524885,
    0.523185,
    0.589924,
    0.698292,
    0.510332,
    0.901244,
    0.550883,
    0.329464,
    0.100546,
    0.224608
  );


float overlayOpacityForBrightness(float x) {
    // Note: range 0 to 1
    
    // Will a fancy curve help?... I'll have to experiment more at night
    // float y = pow(x, 2.0) * 0.75;
    // float y = (1.0 - exp(-x))*1.15;
    // float y = (1.0 - exp(-pow((x-0.15), 0.6)))*1.18;

    float y = x*0.75;
    return min(max(y, 0.001), 1.0);
}

void main() {
    // 1. Get the current pixel color
    vec4 pixColor = texture(tex, v_texcoord);

    // 2. Calculate average screen brightness
    vec3 totalRGB = vec3(0.0);
    
    // 4x4 grid (16 samples) provides sufficient coverage to gauge screen brightness
    // while reducing texture fetches by 84% compared to a 10x10 grid (100 samples).
    for (int i = 0; i < 4; ++i) {
        for (int j = 0; j < 4; ++j) {
            vec2 coord = vec2((float(i) + 0.5) * 0.25, (float(j) + 0.5) * 0.25);
            totalRGB += texture(tex, coord).rgb;
        }
    }
    
    vec3 avgColor = totalRGB * 0.0625; // 1.0 / 16.0
    // We use 100 pre-defined approximately equidistant and random distributed points
    // This is dense enough to catch small icons/text but light enough to run fast.
    for (int i = 0; i < 100; i++)
        totalRGB += texture(tex, vec2(xArr[i], yArr[i])).rgb;
    
    vec3 avgColor = totalRGB / 100.;
    float globalBrightness = dot(avgColor, vec3(0.2126, 0.7152, 0.0722));

    // 3. Get the specific opacity for this brightness level
    float opacity = overlayOpacityForBrightness(globalBrightness);

    // 4. Apply the "black overlay" effect
    vec3 outColor = mix(pixColor.rgb, vec3(0.0), opacity);

    fragColor = vec4(outColor, pixColor.a);
}
