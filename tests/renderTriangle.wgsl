struct UniformGroup {
    color: vec4f,
    scale: vec2f,
    offset: vec2f
}

@group(0) @binding(0) var<uniform> uniformData: UniformGroup;

@vertex fn vs( @builtin(vertex_index) vertexIndex: u32) -> @builtin(position) vec4f {
    
    let pos = array(
        vec2f(0.0, 0.5),
        vec2f(-0.5, -0.5),
        vec2f(0.5, -0.5)
    );


    return vec4f(pos[vertexIndex] * uniformData.scale + uniformData.offset, 0, 1);

}

@fragment fn fs() -> @location(0) vec4f {
    return uniformData.color;
}