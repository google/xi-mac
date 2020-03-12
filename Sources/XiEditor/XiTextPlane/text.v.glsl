// Copyright 2017 The xi-editor Authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#version 330 core
// corners of the quad, ranges from (0, 0) to (1, 1)
layout (location = 0) in vec2 position;

// rect coords are in pixels (to be scaled by posScale)
layout (location = 1) in vec2 rectOrigin;

layout (location = 2) in vec2 rectSize;

// in 0..255 units
layout (location = 3) in vec4 rgba;

layout (location = 4) in vec2 uvOrigin;

layout (location = 5) in vec2 uvSize;

// 0 == false
layout (location = 6) in float isEmoji;

uniform vec2 posScale;

flat out vec4 passColor;
out vec2 uv;
out float emoji;

vec3 to_linear(vec3 srgb) {
    // 0 if srgb < 0.04045
    vec3 selection = step(0.04045, srgb);
    vec3 a = srgb / 12.92;
    vec3 b = pow((srgb + 0.055) / 1.055, vec3(2.4));
    // a for components where linear < 0.04045, b for others
    return mix(a, b, selection);
}

void main() {
    vec2 pixelPos = rectOrigin + position * rectSize;
    vec2 pos = pixelPos * posScale + vec2(-1.0, 1.0);
    gl_Position = vec4(pos, 0.0, 1.0);
    passColor = rgba * vec4(1.0 / 255.0);
    passColor.rgb = to_linear(passColor.rgb);
    uv = uvOrigin + position * uvSize;
    emoji = isEmoji;
}
