
struct VertexOutput {
  @builtin(position) position: vec4f,
  @location(0) position3D: vec3f,
  @location(1) particleColor: vec4f,
  @location(2) uv: vec2f,
  @location(3) velocity: vec3f
};

struct Uniforms {
    modelViewMatrix: mat4x4<f32>,
    perspectiveMatrix: mat4x4<f32>,
    orientationMatrix: mat4x4<f32>,

    cameraPosition: vec3f,
    mirror:f32,

    screenSize: vec2f,
    particleSize: f32,
    scale:f32,
};

@group(0) @binding(0) var<storage, read>  positionData: array<vec4f>;
@group(0) @binding(1) var<uniform> uniforms: Uniforms;
@group(0) @binding(2) var<storage, read>  particleColor: array<vec4f>;
@group(0) @binding(3) var<storage, read>  velocityData: array<vec4f>;

@vertex fn vs( @builtin(vertex_index) vertexIndex: u32, @builtin(instance_index) instanceIndex: u32) -> VertexOutput {

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

  var position = positionData[instanceIndex].rgb;
  var projection = uniforms.modelViewMatrix * vec4f(position, 1.);
  projection = uniforms.perspectiveMatrix * projection;

  projection.x /= projection.w;
  projection.y /= projection.w;
  projection.z /= projection.w;

  var velocity = velocityData[instanceIndex].rgb;
  var pp = pos[vertexIndex];

  var xy = 0.25 * positionData[instanceIndex].a * uniforms.particleSize * pp * (0.001) * vec2f(uniforms.screenSize.y / uniforms.screenSize.x, 1.) + projection.xy;

  var output: VertexOutput;
  output.position = vec4(xy, projection.z, 1.);
  output.position3D = position;
  output.particleColor = particleColor[instanceIndex];
  output.velocity = velocityData[instanceIndex].rgb;
  output.uv = 0.5 * pos[vertexIndex] + 0.5;
  return output;
}


struct FragmentData {
  @location(0) color: vec4f,
  @location(1) velocity: vec4f
}

@fragment fn fs(input: VertexOutput) -> FragmentData {

    var st = input.uv;
    
    var mn = 2 * st - vec2(1.);
    var z = sqrt(1. - mn.x * mn.x - mn.y * mn.y);

    var position = input.position3D;
    
    if( length(mn) > 1 || length(input.particleColor.rgb) > 100) {
        discard;
    };

    var normal = vec3f(mn, z);
    normal = normalize(normal);
    normal = vec3f( (uniforms.orientationMatrix * vec4f(normal, 1.)).rgb );

    var shade = input.particleColor;

    var light = vec3f(0, 1, 0);
    var R = reflect(light, normal);
    var eye = normalize(uniforms.cameraPosition - position);
    var specular = pow(max(dot(eye, R), 0.), 2.);

    var color = input.particleColor * (0.3 * max(dot(normal,light), 0.) + 0.4 + 0.3 * specular) ;
    if(uniforms.mirror > 0.5) {
        color *= clamp(1. - 1.5 * input.position3D.y / 136., 0, 1);
    }

    color.a = 1. - 800000. * pow(abs(1 * input.position.z - 1.), 3.);

    var velocity = input.velocity;
    var vel = uniforms.orientationMatrix * vec4f(velocity.rgb, 1.);


    var fragmentData: FragmentData;
    fragmentData.color = color;
    fragmentData.velocity = vec4f( clamp(abs(vel.xy) / 60., vec2f(0.), vec2f(1.)), input.position3D.y / 136,  uniforms.mirror);
    return fragmentData;
}