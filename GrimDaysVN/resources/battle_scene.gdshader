shader_type canvas_item;
uniform sampler2D screen: hint_screen_texture;
const float overallSpeed = 0.25;
const float gridSmoothWidth = 0.015;
const float axisWidth = 0.05;
const float majorLineWidth = 0.025;
const float minorLineWidth = 0.0125;
const float majorLineFrequency = 5.0;
const float minorLineFrequency = 1.0;
const vec4 gridColor = vec4(0.5);
const float scale = 5.;
const vec4 lineColor = vec4(0.25, 0.5, 1.0, 1.0);
const float minLineWidth = 0.02;
const float maxLineWidth = 1.5;
const float lineSpeed = 1.0 * overallSpeed;
const float lineAmplitude = 0.5;
const float lineFrequency = 0.31;
const float warpSpeed = 0.2 * overallSpeed;
const float warpFrequency = 0.5;
const float warpAmplitude = 0.05;
const float offsetFrequency = 0.2;
const float offsetSpeed = 1.33 * overallSpeed;
const float minOffsetSpread = 0.33;
const float maxOffsetSpread = 2.5;
uniform int linesPerGroup:hint_range(4, 100, 1);

vec3 pallete(float time){
	vec3 a = vec3(0.0, 1.0, 0.810);
	vec3 b = vec3(0.399, 0.228, 0.451);
	vec3 c = vec3(0.684, 0.051, 0.760);
	vec3 d = vec3(2.478, 5.281, 0.718);
	
	return a + b * cos(6.28318*(c*time+d));
}

const vec4[] bgColors = {
    vec4(lineColor * 0.25),
    vec4(lineColor - vec4(0.1, 0.5, 0.83, 1))
};

#define drawCircle(P, r, U)     smoothstep(r + gridSmoothWidth, r, length(U - (P)))
#define drawSmoothLine(P, w, t) smoothstep((w) / 2.0, 0.0, abs(P - (t)))
#define drawCrispLine(P, w, t)  smoothstep(gridSmoothWidth, 0.0, abs(P - (w) / 2.0 - (t)))
#define drawPeriodicLine(f, w, t)  drawCrispLine(f / 2.0, w, abs(mod(t, f) - f / 2.0))

float drawGridLines(float axis)
{
    return drawCrispLine(0.0, axisWidth, axis)
        + drawPeriodicLine(majorLineFrequency, majorLineWidth, axis)
        + drawPeriodicLine(minorLineFrequency, minorLineWidth, axis);
}

float drawGrid(vec2 space)
{
    return min(1.0, drawGridLines(space.x)
                  + drawGridLines(space.y));
}

// Probably can optimize w/ noise, but currently using Fourier transform
float random(float t)
{
    return (cos(t) + cos(t * 1.3 + 1.3) + cos(t * 1.4 + 1.4)) / 3.0;
}

float getPlasmaY(float x, float horizontalFade, float offset)
{
    return random(x * lineFrequency + TIME * lineSpeed) * horizontalFade * lineAmplitude + offset;
}

//shader_type canvas_item;

uniform sampler2D offset_image : hint_default_white;
uniform float strength = 1.0;

void fragment() {
	vec4 output = texture(screen, SCREEN_UV);
	
	float shift =sin(TIME) * (strength * texture(offset_image, SCREEN_UV).r / 100.0);
	output.r = texture(screen, vec2(SCREEN_UV.x + shift, SCREEN_UV.y)).r;
	output.g = texture(screen, SCREEN_UV).g;
	output.b = texture(screen, vec2(SCREEN_UV.x - shift, SCREEN_UV.y)).b;
	
	COLOR = output;
}
//
//void fragment() {
//
    //vec2 uv = FRAGCOORD.xy.xy / (1.0/SCREEN_PIXEL_SIZE).xy;
    //vec2 space = (FRAGCOORD.xy - (1.0/SCREEN_PIXEL_SIZE).xy / 2.0) / (1.0/SCREEN_PIXEL_SIZE).x * 2.0 * scale;
//
    //float horizontalFade = 1.0 - (cos(uv.x * 6.28) * 0.5 + 0.5);
    //float verticalFade = 1.0 - (cos(uv.y * 6.28) * 0.5 + 0.5);
//
    //// Fun with nonlinear transformations! (wind / turbulence)
    //space.y += random(space.x * warpFrequency + TIME * warpSpeed) * warpAmplitude * (0.5 + horizontalFade);
    //space.x += random(space.y * warpFrequency + TIME * warpSpeed + 2.0) * warpAmplitude * horizontalFade;
//
    //vec4 lines = vec4(0);
//
    //for (int l = 0; l < linesPerGroup; l++)
    //{
        //float normalizedLineIndex = float(l) / float(linesPerGroup);
        //float offsetTime = TIME * offsetSpeed;
        //float offsetPosition = float(l) + space.x * offsetFrequency;
        //float rand = random(offsetPosition + offsetTime) * 0.5 + 0.75;
        //float halfWidth = mix(minLineWidth, maxLineWidth, rand * horizontalFade) / 2.0;
        //float offset = random(offsetPosition + offsetTime * (1.0 + normalizedLineIndex)) * mix(minOffsetSpread, maxOffsetSpread, horizontalFade);
        //float linePosition = getPlasmaY(space.x, horizontalFade, offset);
        //float line = drawSmoothLine(linePosition, halfWidth, space.y) / 2.0 + drawCrispLine(linePosition, halfWidth * 0.15, space.y);
//
        //float circleX = mod(float(l) + TIME * lineSpeed, 25.0) - 12.0;
        //vec2 circlePosition = vec2(circleX, getPlasmaY(circleX, horizontalFade, offset));
        //float circle = drawCircle(circlePosition, 0.01, space) * 8.0;
//
		//vec4 new_line_color = vec4(pallete(TIME / 8.), 1.0);
//
        ////line = line + circle;
        //lines += line * new_line_color * rand;
    //}
//
    ////COLOR = mix(bgColors[0], bgColors[1], uv.x);
    ////COLOR *= verticalFade;
    ////COLOR.a = 1.0;
    //// Debug grid:
    ////COLOR = mix(COLOR, gridColor, drawGrid(space));
    ////COLOR += lines;
	//vec4 current_screen = texture(screen, UV);
	//COLOR = mix(current_screen, lines, 1.0);
//}
////void vertex() {
	////// Called for every vertex the material is visible on.
////}
//
////void fragment() {
	////vec4 current_screen = texture(screen, UV);
	////COLOR = mix(current_screen, vec4(0.4, 0.5, 0.5, 1.0), 0.5);
	////
////}
//
////void light() {
	//// Called for every pixel for every light affecting the CanvasItem.
	//// Uncomment to replace the default light processing function with this one.
////}
