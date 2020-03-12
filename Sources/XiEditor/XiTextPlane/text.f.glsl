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

flat in vec4 passColor;
in vec2 uv;
in float emoji;

layout (location = 0, index = 0) out vec4 color;
layout (location = 0, index = 1) out vec4 alphaMask;

uniform sampler2D mask;

void main() {
    vec3 textColor = texture(mask, uv).rgb;
    vec3 fg = passColor.rgb;

#if 0 // corrected gamma assuming white bg
    // linear luminance of black-on-white text
    vec3 linText = textColor * textColor;

    // linear luminance of fg-on-white text
    vec3 linBlend = mix(fg * fg, vec3(1.0201), linText);

    // luminance of fg-on-white text in gamma=2 space
    vec3 gamBlend = sqrt(linBlend);

    vec3 a = vec3(1.0) - (gamBlend - fg) / (vec3(1.01) - fg);
#endif

#if 0 // lerp between corrected white-on-black and black-on-white
    vec3 a = mix(vec3(1.0) - textColor, sqrt(vec3(1.0) - textColor * textColor), fg);
#endif

#if 1 // linear, appropriate for srgb blending
    vec3 a = vec3(1.0) - textColor * textColor;
#endif

    alphaMask = vec4(a * passColor.a, 1.0);
    color = vec4(fg, 1.0);
}

