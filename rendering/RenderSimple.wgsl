struct VertexOutput {
  @builtin(position) position: vec4f,
  @location(0) uv: vec2f,
  @location(1) normal: vec3f,
  @location(2) position3D: vec3f
};

struct Uniforms {
    modelViewMatrix: mat4x4<f32>,
    perspectiveMatrix: mat4x4<f32>,
    worldMatrix: mat4x4<f32>,
    cameraPosition: vec3f,
    coneAngle: f32,
    coneRotation: f32,
    resolution: f32,
    IOR: f32,
    raytrace: f32
};


@group(0) @binding(0) var<uniform> uniforms: Uniforms;
@group(0) @binding(1) var texture3D: texture_3d<f32>;
@group(0) @binding(2) var textureSampler: sampler;

//For the raytracer
@group(0) @binding(3) var<storage, read>  particlesIndicesBuffer:   array<i32>;
@group(0) @binding(4) var<storage, read>  particlesPositionBuffer:   array<vec4f>;
@group(0) @binding(5) var<storage, read>  particlesColorBuffer:   array<vec4f>;
@group(0) @binding(6) var<storage, read>  velocityBuffer:   array<vec4f>;
@group(0) @binding(7) var<storage, read>  gridBuffer:   array<i32>;
@group(0) @binding(8) var bgTexture: texture_2d<f32>;


@vertex fn vs( @builtin(vertex_index) vertexIndex: u32) -> VertexOutput {
    
  let pos = array(
    // 1st triangle
    vec3f( -1, 0, 1),  // center
    vec3f( 1, 0, -1),  // right, center
    vec3f( -1, 0, -1),  // center, top
 
    // 2st triangle
    vec3f( -1, 0, 1),  // center, top
    vec3f( 1, 0, 1),  // right, center
    vec3f( 1, 0, -1),  // right, top
  );

    var position = pos[vertexIndex];
    var projection = uniforms.modelViewMatrix * vec4f(position * 2, 1.);
    var position3D = uniforms.worldMatrix * vec4f(position * 2, 1.);
    projection = uniforms.perspectiveMatrix * projection;
    
    var output: VertexOutput;
    output.position = projection;
    output.normal = vec3f(0, 1, 0);
    output.position3D = position3D.rgb;
    output.uv = position.xz * 0.5 + 0.5;;
    return output;
}


struct FragmentData {
  @location(0) color: vec4f,
  @location(1) velocity: vec4f
}

const MAX_DISTANCE = 800.0;
const MAX_ALPHA = 0.95;
const OUTER_RADIUS = 0.4255;
const INNER_RADIUS = 0.385;
const LIGHT_POS = 0.035;
const MAX_ITERATIONS = 400;
const GRID_RATIO = 8;
const RADIUS = .19; //0.5 * 0.5 it's squared to avoid the square root in checkHit. *1


const EPSILON = 1.e-10 ;
const acne = .05;
var<private> hitPosition: vec4f = vec4f(0.);
var<private> hitColor: vec4f = vec4f(0.);
var<private> hitVelocity: vec4f = vec4f(0.);

fn sampleVoxels(pos: vec3<f32>, lod: f32) -> vec4<f32> {
    return textureSampleLevel(texture3D, textureSampler, pos, lod);
}

fn voxelConeTracing(startPos: vec3f, direction: vec3f, tanHalfAngle: f32) -> vec4<f32> {
    var lod = 0.;
    var color = vec3f(0.);
    var alpha = 0.;
    var occlusion = 0.;

    var voxelWorldSize = .01;
    var dist = voxelWorldSize;

    while(dist < MAX_DISTANCE && alpha < MAX_ALPHA) {
        let diameter = max(voxelWorldSize, 2. * tanHalfAngle * dist);
        let lodLevel = log2( diameter / voxelWorldSize);
        var voxelColor = sampleVoxels(startPos + dist * direction, lodLevel);
        var sub = 1. - alpha;
        var aa = voxelColor.a;
        alpha += sub * aa;
        occlusion += sub * aa / (1. + 0.03 * diameter);
        color +=  voxelColor.rgb * alpha;
        dist += diameter;
    }

    return vec4f(color, clamp(1. - occlusion, 0., 1.) );
}

fn shadePoint(pp: vec3f, direction: vec3f) -> vec4f {

    var ang = radians(uniforms.coneRotation);
    let s = sin(ang);
    let c = cos(ang);

    var dir1 = vec3f(0, 0, 1);
    var dir2 = vec3f(c, 0, s);
    var dir3 = vec3f(-c, 0, s);
    var dir4 = vec3f(0, c, s);
    var dir5 = vec3f(0, -c, s);

    var zAxis = normalize(direction);
    var xAxis = vec3f(1, 0, 0);
    var yAxis = vec3f(0, 1, 0);
    var UP = vec3f(0, 1, 0);
    var rot = mat3x3f(0, 0, 0, 0, 0, 0, 0, 0, 0);

    xAxis = normalize(cross(UP, zAxis));
    yAxis = normalize(cross(zAxis, xAxis));
    rot = mat3x3f(xAxis, yAxis, zAxis);

    dir1 = rot * dir1;
    dir2 = rot * dir2;
    dir3 = rot * dir3;
    dir4 = rot * dir4;
    dir5 = rot * dir5;

    var cone = voxelConeTracing(pp, dir1, uniforms.coneAngle);
    var color =  cone.rgba;

    cone = voxelConeTracing(pp, dir2, uniforms.coneAngle);
    color += cone.rgba;

    cone = voxelConeTracing(pp, dir3, uniforms.coneAngle);
    color += cone.rgba;

    cone = voxelConeTracing(pp, dir4, uniforms.coneAngle);
    color += cone.rgba;

    cone = voxelConeTracing(pp, dir5, uniforms.coneAngle);
    color += cone.rgba;

    color /= 5.;

    return color;

}

fn capCylinder(p: vec3f, h: f32, r: f32) -> f32{
    var d = abs(vec2f(length(p.yz), p.x)) - vec2(r, h);
    return min(max(d.x, d.y), 0.) + length(max(d, vec2f(0.) ));
} 

fn map(p: vec3f) -> f32 {

   var d2 = capCylinder(p - vec3f(0.22, 0.5, 0.5), 0.171, OUTER_RADIUS);
   var d1 = capCylinder(p - vec3f(LIGHT_POS + 0.22, 0.5, 0.5), 0.171, INNER_RADIUS);

   return max(-d1, d2);

}

fn calcNormal(p: vec3f) -> vec3f {
    let h = 0.001;
    let k = vec2f(1, -1);
    return normalize( 
        k.xyy * map( p + k.xyy * h ) + 
        k.yyx * map( p + k.yyx * h ) + 
        k.yxy * map( p + k.yxy * h ) + 
        k.xxx * map( p + k.xxx * h )
    );
}

fn Fresnel(incom: vec3f, normal: vec3f, index_internal: f32, index_external: f32) -> f32 {
    var eta = index_internal / index_external;
 	var cos_theta1 = dot(incom, normal);
 	var cos_theta2 = 1.0 - (eta * eta) * (1.0 - cos_theta1 * cos_theta1);

 	if (cos_theta2 < 0.0) {
        return 1.0;
    } else {
 		cos_theta2 = sqrt(cos_theta2);
 		var fresnel_rs = (index_internal * cos_theta1 - index_external * cos_theta2) / (index_internal * cos_theta1 + index_external * cos_theta2);
 		var fresnel_rp = (index_internal * cos_theta2 - index_external * cos_theta1) / (index_internal * cos_theta2 + index_external * cos_theta1);
 		return (fresnel_rs * fresnel_rs + fresnel_rp * fresnel_rp) * 0.5;
 	}
}

fn checkHit(startPos: vec3f, center: vec3f, rayDirection: vec3f) -> bool {
    var L = center - startPos;
    var l = length(L);
    var tCA = dot(L, rayDirection);
    //var d = sqrt(l * l - tCA * tCA); *1
    var d = l * l - tCA * tCA;
    return d >= 0. && d <= RADIUS && tCA >= 0.;
}

fn raytrace(startPos: vec3f, rayDirection: vec3f, refractionMode: bool) -> bool {

    var index = -1000;
    var deltaDist = abs(1. / max(abs(rayDirection), vec3(EPSILON)));
    var rayStep = sign(rayDirection);
    var stepForward = vec3f(0);
    
    var initPos = uniforms.resolution * (startPos + acne * rayDirection);
    var pos = initPos;
    var mapPos = floor(pos);
    var sideDist = (rayStep * (mapPos - pos + 0.5) + 0.5) * deltaDist;
    var res = i32(uniforms.resolution);
    var limits = vec3f(uniforms.resolution);
    var dist = 0.;
    var nPos = vec3f(0.);
    var inside = false;

    var highResolution = true;
    var resolution = true;
    var mapPos_h = mapPos;
    var mapPos_l = floor(pos / GRID_RATIO);
    var pos0_l = pos / GRID_RATIO;
    var pos0_h = pos;
    var t = 0.;
    var lowRes = res / GRID_RATIO;
    var lowCounter = 0;

    //Traverse the particles
    for(var i = 0; i < MAX_ITERATIONS; i ++) {
                
        stepForward = step(sideDist.xyz, sideDist.yxy) * step(sideDist.xyz, sideDist.zzx);
        sideDist += stepForward * deltaDist;
        pos += stepForward * rayStep;
        mapPos = floor(pos);

        t = min(sideDist.x, min(sideDist.y, sideDist.z));

        //Check borders
        var borders = length(pos.yz / uniforms.resolution - vec2f(0.5)) > INNER_RADIUS;
        borders = borders && mapPos_h.x < 0.1 * uniforms.resolution;
        borders = borders && mapPos_h.x > 0.4 * uniforms.resolution;
        // borders = borders && mapPos_l.x < 0.1 * uniforms.resolution / GRID_RATIO;
        // borders = borders && mapPos_l.x > 0.4 * uniforms.resolution / GRID_RATIO;
        
        if(borders) {
            //return false;
        }

        var lowGrid = mapPos;
        
        if(highResolution) {
            lowGrid = lowGrid / GRID_RATIO;
        }
        
        let indexGrid = (i32(lowGrid.x)) + lowRes * (i32(lowGrid.y)) + lowRes * lowRes * (i32(lowGrid.z));
        resolution = gridBuffer[indexGrid] == 1 || true;

        if(highResolution) {

            mapPos_h = mapPos;

            if(!resolution) {
            
                highResolution = false;
                pos0_l = (pos0_h + t * rayDirection) / GRID_RATIO;
                pos = pos0_l;
                mapPos = floor(pos);
                sideDist =  (rayStep * (mapPos - pos + 0.5) + 0.5) * deltaDist;
            
            } else {

                var d = 100000.;
                var center = vec3f(0.);
                var l = 0.;

                let index1D = (i32(mapPos.x)) + res * (i32(mapPos.y)) + res * res * (i32(mapPos.z));

                for(var z = 0; z < 8; z ++) {
                    var particleId = 8 * index1D + z;
                    var voxelData = particlesIndicesBuffer[particleId];
                    
                    if(voxelData == 0) {
                        break;
                    }

                    center = particlesPositionBuffer[voxelData].rgb;
                    if(center.x > 0.1 * uniforms.resolution && checkHit(initPos, center, rayDirection) && l < d) {
                        index = voxelData;
                        d = l;
                    }
                }

                if(index > -1000) {
                    hitColor = particlesColorBuffer[index];
                    hitPosition = particlesPositionBuffer[index];
                    hitVelocity = velocityBuffer[index];
                    return true;
                }
            }

        } else {

            mapPos_l = mapPos;
            lowCounter = lowCounter + 1;

            if(resolution) {

                highResolution = true;
                pos0_h = GRID_RATIO * (pos0_l + 0.9999 * t * rayDirection);
                pos = pos0_h;
                mapPos = floor(pos);
                sideDist = (rayStep * (mapPos - pos + 0.5) + 0.5) * deltaDist;

            }

        }

        highResolution = resolution;
        
    }

    return false;
}

fn sampleSphericalMap(v: vec3f) -> vec2f {

    var uv = vec2f(atan2(v.z, -v.x), asin(v.y));
    uv *= vec2(0.1591, 0.3183);
    uv += vec2f(0.5, 0.5);

    return uv;
}


@fragment fn fs(input: VertexOutput) -> FragmentData {


    var colorReflect = vec4f(0);
    var pp = input.position3D;
    var pInit = pp;
    var eye = normalize(pp - uniforms.cameraPosition);
    var rayReflect = normalize(reflect(eye, input.normal));
    var reflectVelocity = vec4f(0.);

    //////////////////////////////////////////////
    //Geometry reflections
    //////////////////////////////////////////////

    var d = map(pp);
    var counter = 0;
    var t = abs(d);

    while(counter < 30 && d > 0.001) {
        d = map(pp + t * rayReflect);
        t += abs(d);
        counter++;
    }

    if(d <= 0.01) {
        pp += t * rayReflect;
        let normal = calcNormal(pp);

        if(uniforms.raytrace == 0.) {
          
          var shade = shadePoint(pp, normal);
          shade = vec4f((shade.rgb * 0.5 + vec3f(1)), pow(clamp(shade.a, 0, 1), 1.) );
          colorReflect = vec4f(shade.rgb * shade.a, 1.);
          
        } else {



          //////////////////////////////////////////////
          //Geometry reflections
          //////////////////////////////////////////////
          var reflectColor = vec4f(1, 0, 0, 1);
          var refractColor = vec4f(0, 0, 1, 1);
          var reflectVelocity = vec4f(0.);
          var refractVelocity = vec4f(0.);
          eye = rayReflect;
          var refractRay = normalize(refract(eye, normal, 1. / uniforms.IOR));
          var reflectRay = normalize(reflect(eye, normal));

          var kR = Fresnel(-eye, normal, 1, uniforms.IOR);
          var kT = 1. - kR;

          if(raytrace(pp, reflectRay, false) ) {
              reflectColor = hitColor;
              reflectVelocity = hitVelocity;
          } else {
              reflectColor = textureSampleLevel(bgTexture, textureSampler, sampleSphericalMap(reflectRay), 0);
          }


          //////////////////////////////////////////////
          //Refractions
          //////////////////////////////////////////////

          d = map(pp + 0.01 * refractRay);
          counter = 0;
          var t2 = abs(d);

          while(counter < 30 && d < 0.) {
              d = map(pp + t2 * refractRay);
              t2 += abs(d);
              counter++;
          }

          if(d > 0.) {
              pp += t2 * refractRay;
              let normal = calcNormal(pp);
              refractRay = normalize(refract(refractRay, -normal, uniforms.IOR));;
          }

          if(raytrace(pp, refractRay, true) ) {
              refractColor = hitColor;
              refractVelocity = hitVelocity;
          } else {
              refractColor = textureSampleLevel(bgTexture, textureSampler, sampleSphericalMap(refractRay), 0);
          }

          colorReflect = kR * reflectColor + kT * refractColor;

        }

    }

    //////////////////////////////////////////////
    //Particles reflections
    //////////////////////////////////////////////
    if(raytrace(pInit, rayReflect, false) ) {

        pInit = hitPosition.rgb / uniforms.resolution;
        if(length(pInit - input.position3D) < t ) {
          colorReflect = hitColor;
          reflectVelocity = hitVelocity;
        }

    } 

    var fragmentData: FragmentData;
    fragmentData.color = colorReflect;
    fragmentData.velocity = vec4f(0.);
    return fragmentData;
}