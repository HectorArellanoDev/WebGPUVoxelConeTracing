
struct VertexOutput {
    @builtin(position) position: vec4f,
    @location(0) uv: vec2f
}

@group(0) @binding(0) var texture: texture_2d<f32>;
@group(0) @binding(1) var textureSampler: sampler;

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

    return textureSample(texture, textureSampler, input.uv);
}