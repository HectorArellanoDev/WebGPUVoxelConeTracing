struct Uniforms {
  direction: vec2f,
  deltaTime: f32,
  motionBlur: f32
}

struct VertexOutput {
    @builtin(position) position: vec4f,
    @location(0) uv: vec2f
}

@group(0) @binding(0) var texture: texture_2d<f32>;
@group(0) @binding(1) var textureVel: texture_2d<f32>;
@group(0) @binding(2) var textureSampler: sampler;
@group(0) @binding(3) var<uniform> uniforms: Uniforms;
// @group(0) @binding(4) var textureDepth: texture_2d<f32>;


@vertex fn vs( @builtin(vertex_index) vertexIndex: u32) -> VertexOutput {

  let pos = array(
    // 1st triangle
    vec2f( -1,  1),  // center
    vec2f( 1,  -1),  // right, center
    vec2f( -1,  -1),  // center, top
 
    // 2st triangle
    vec2f( 1, -1),  // center, top
    vec2f( 1,  1),  // right, center
    vec2f( -1,  1),  // right, top
  );

  var output: VertexOutput;
  var position = pos[vertexIndex];
  output.position = vec4f(position, 0., 1.);
  output.uv = position * 0.5 + 0.5;
  output.uv.y = 1 - output.uv.y;
  return output;
}

@fragment fn fs(input: VertexOutput) -> @location(0) vec4f {


    var uv = input.uv;
    var data = textureSample(textureVel, textureSampler, uv);
    var color = vec4(0.);

    var dimensions = textureDimensions(texture).xy;
    var tSize = vec2f(f32(dimensions.x), f32(dimensions.y));
    var blend = vec4f(0);
    var mirror = step(1, data.a);
    var motion = step(1, uniforms.motionBlur);
    var sum = mirror;
    var m = 1.;
    var n = 30. * data.z * mirror + 10000 * uniforms.deltaTime * motion * pow(dot(data.xy, uniforms.direction), 2.) * (1. - mirror);
    var steps = i32(n);
    

    for(var i = 0; i <= steps; i ++) {
        var k = f32(i);
        var j = k - 0.5 * n;
        color += m * textureSampleLevel(texture, textureSampler, uv + uniforms.direction * j / tSize, 0);
        m *= mirror * (n - k) / (k + 1.) + (1. - mirror);
        sum += m;
    } 

    color /= sum;


    return color;
}