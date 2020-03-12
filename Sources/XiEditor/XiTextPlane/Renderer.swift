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

import Cocoa
import OpenGL

/// The renderer for text planes.

enum DrawState {
    case none
    case solid
    case text
}

class Renderer {
    var vertexArrayIds = [GLuint](repeating: 0, count: 2)
    var bufferIds = [GLuint](repeating: 0, count: 4)
    let vertexPositionBufId = 0
    let elementIndexBufId = 1
    let solidInstanceBufId = 2
    let textInstanceBufId = 3

    var solidProgram: ShaderProgram
    var solid_u_scale: GLuint = 0
    let maxSolidInstances = 4096
    let solidInstanceSize = 8 // in floats
    var solidInstances: [GLfloat]
    var solidInstanceIx = 0

    var atlas: Atlas
    var textProgram: ShaderProgram
    var text_u_scale: GLuint = 0
    let maxTextInstances = 65536
    let textInstanceSize = 13 // in floats
    var textInstances: [GLfloat]
    var textInstanceIx = 0

    var drawState: DrawState = .none
    var u_x_scale: GLfloat = 0
    var u_y_scale: GLfloat = 0
    var dpiScale: CGFloat = 0

    init() {
        // solid rectangle rendering
        solidProgram = ShaderProgram()
        solidProgram.attachShader(name: "solid.v", type: GL_VERTEX_SHADER)
        solidProgram.attachShader(name: "solid.f", type: GL_FRAGMENT_SHADER)
        solidProgram.link()

        solid_u_scale = solidProgram.getUniformLocation(name: "posScale")!

        glGenVertexArrays(GLsizei(vertexArrayIds.count), &vertexArrayIds)
        glBindVertexArray(vertexArrayIds[0])

        glGenBuffers(GLsizei(bufferIds.count), &bufferIds)
        // vertex position buffer
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), bufferIds[vertexPositionBufId])
        let vertices: [Float] = [1.0, 1.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0]
        glBufferData(GLenum(GL_ARRAY_BUFFER), MemoryLayout<Float>.size * 8, vertices, GLenum(GL_STATIC_DRAW))
        glVertexAttribPointer(0, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), 8, nil)
        glEnableVertexAttribArray(0)

        // element buffer
        glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), bufferIds[elementIndexBufId])
        let indices: [Int32] = [0, 1, 3, 1, 2, 3]
        glBufferData(GLenum(GL_ELEMENT_ARRAY_BUFFER), MemoryLayout<Int32>.size * 6, indices, GLenum(GL_STATIC_DRAW))

        // instance buffer
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), bufferIds[solidInstanceBufId])
        let solidInstanceBytes = GLsizei(MemoryLayout<Float>.size * solidInstanceSize)
        solidInstances = [GLfloat](repeating: 0.0, count: solidInstanceSize * maxSolidInstances)
        glBufferData(GLenum(GL_ARRAY_BUFFER), GLsizeiptr(MemoryLayout<Float>.size * solidInstances.count), solidInstances, GLenum(GL_STREAM_DRAW))
        // rectOrigin
        glEnableVertexAttribArray(1)
        glVertexAttribPointer(1, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), solidInstanceBytes, nil)
        glVertexAttribDivisor(1, 1)
        // rectSize
        glEnableVertexAttribArray(2)
        glVertexAttribPointer(2, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), solidInstanceBytes, UnsafeRawPointer(bitPattern: MemoryLayout<Float>.size * 2))
        glVertexAttribDivisor(2, 1)
        // rgba
        glEnableVertexAttribArray(3)
        glVertexAttribPointer(3, 4, GLenum(GL_FLOAT), GLboolean(GL_FALSE), solidInstanceBytes, UnsafeRawPointer(bitPattern: MemoryLayout<Float>.size * 4))
        glVertexAttribDivisor(3, 1)

        // text blending
        textProgram = ShaderProgram()
        textProgram.attachShader(name: "text.v", type: GL_VERTEX_SHADER)
        textProgram.attachShader(name: "text.f", type: GL_FRAGMENT_SHADER)
        textProgram.link()

        text_u_scale = solidProgram.getUniformLocation(name: "posScale")!

        glBindVertexArray(vertexArrayIds[1])
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), bufferIds[vertexPositionBufId])
        glVertexAttribPointer(0, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), 8, nil)
        glEnableVertexAttribArray(0)

        glBindBuffer(GLenum(GL_ARRAY_BUFFER), bufferIds[textInstanceBufId])
        let textInstanceBytes = GLsizei(MemoryLayout<Float>.size * textInstanceSize)
        textInstances = [GLfloat](repeating: 0.0, count: textInstanceSize * maxTextInstances)
        glBufferData(GLenum(GL_ARRAY_BUFFER), GLsizeiptr(MemoryLayout<Float>.size * textInstances.count), textInstances, GLenum(GL_STREAM_DRAW))
        // rectOrigin
        glEnableVertexAttribArray(1)
        glVertexAttribPointer(1, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), textInstanceBytes, nil)
        glVertexAttribDivisor(1, 1)
        // rectSize
        glEnableVertexAttribArray(2)
        glVertexAttribPointer(2, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), textInstanceBytes, UnsafeRawPointer(bitPattern: MemoryLayout<Float>.size * 2))
        glVertexAttribDivisor(2, 1)
        // rgba
        glEnableVertexAttribArray(3)
        glVertexAttribPointer(3, 4, GLenum(GL_FLOAT), GLboolean(GL_FALSE), textInstanceBytes, UnsafeRawPointer(bitPattern: MemoryLayout<Float>.size * 4))
        glVertexAttribDivisor(3, 1)
        // uvOrigin
        glEnableVertexAttribArray(4)
        glVertexAttribPointer(4, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), textInstanceBytes, UnsafeRawPointer(bitPattern: MemoryLayout<Float>.size * 8))
        glVertexAttribDivisor(4, 1)
        // uvSize
        glEnableVertexAttribArray(5)
        glVertexAttribPointer(5, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), textInstanceBytes, UnsafeRawPointer(bitPattern: MemoryLayout<Float>.size * 10))
        glVertexAttribDivisor(5, 1)
        // isEmoji
        glEnableVertexAttribArray(6)
        glVertexAttribPointer(6, 1, GLenum(GL_FLOAT), GLboolean(GL_FALSE), textInstanceBytes, UnsafeRawPointer(bitPattern: MemoryLayout<Float>.size * 12))
        glVertexAttribDivisor(6, 1)


        atlas = Atlas()
    }

    /// Prepare for drawing a surface of the given size.
    func beginDraw(size: CGSize, scale: CGFloat) {
        // Note: could move this computation so it only happens on size change
        u_x_scale = 2.0 / GLfloat(size.width)
        u_y_scale = -2.0 / GLfloat(size.height)
        dpiScale = scale
    }

    /// Finish drawing.
    func endDraw() {
        prepareForDraw(.none)
    }

    func clear(_ color: NSColor) {
        // Convert to CIColor because original might not be in RGB colorspace
        let ciColor = CIColor(color: color)!
        glClearColor(sRgbToLinear(ciColor.red), sRgbToLinear(ciColor.green), sRgbToLinear(ciColor.blue), 1.0)
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT))

    }

    func flushDraw() {
        switch drawState {
        case .solid:
            if solidInstanceIx != 0 {
                glBindBuffer(GLenum(GL_ARRAY_BUFFER), bufferIds[solidInstanceBufId])
                glBufferSubData(GLenum(GL_ARRAY_BUFFER), 0, GLsizeiptr(MemoryLayout<GLfloat>.size * solidInstanceIx), solidInstances)
                glDrawElementsInstanced(GLenum(GL_TRIANGLES), 6, GLenum(GL_UNSIGNED_INT), nil, GLsizei(solidInstanceIx / solidInstanceSize))
                solidInstanceIx = 0
            }
        case .text:
            if textInstanceIx != 0 {
                glBindBuffer(GLenum(GL_ARRAY_BUFFER), bufferIds[textInstanceBufId])
                glBufferSubData(GLenum(GL_ARRAY_BUFFER), 0, GLsizeiptr(MemoryLayout<GLfloat>.size * textInstanceIx), textInstances)
                glDrawElementsInstanced(GLenum(GL_TRIANGLES), 6, GLenum(GL_UNSIGNED_INT), nil, GLsizei(textInstanceIx / textInstanceSize))
                textInstanceIx = 0
            }
        case .none:
            ()
        }
    }

    func prepareForDraw(_ newState: DrawState) {
        if newState != drawState {
            flushDraw()
            drawState = newState
            switch drawState {
            case .solid:
                solidProgram.use()
                glBlendFuncSeparate(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE_MINUS_SRC_ALPHA), GLenum(GL_ZERO), GLenum(GL_ONE))
                glBindVertexArray(vertexArrayIds[0])
                glUniform2f(GLint(solid_u_scale), u_x_scale, u_y_scale)
                // array element element buffer really only needs to be bound once globally
                glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), bufferIds[elementIndexBufId])
            case .text:
                textProgram.use()
                glBlendFuncSeparate(GLenum(GL_SRC1_COLOR), GLenum(GL_ONE_MINUS_SRC1_COLOR), GLenum(GL_ZERO), GLenum(GL_ONE))
                glBindVertexArray(vertexArrayIds[1])
                glUniform2f(GLint(text_u_scale), u_x_scale, u_y_scale)
                glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), bufferIds[elementIndexBufId])
            case .none:
                glUseProgram(0)
            }
        }
    }

    /// Draw the main contents of the line. This method doesn't draw the background or
    /// underlines, to help with batching.
    func drawLine(line: TextLine, x0: GLfloat, y0: GLfloat) {
        prepareForDraw(.text)
        for glyph in line.glyphs {
            drawGlyphInstance(glyph: glyph, x0: x0, y0: y0)
        }
    }

    func drawGlyphInstance(glyph: GlyphInstance, x0: GLfloat, y0: GLfloat) {
        var cachedGlyph = atlas.getGlyph(fr: glyph.fontRef, glyph: glyph.glyph, flags: glyph.flags, scale: dpiScale)
        if cachedGlyph == nil {
            flushDraw()
            atlas.flushCache()
            cachedGlyph = atlas.getGlyph(fr: glyph.fontRef, glyph: glyph.glyph, flags: glyph.flags, scale: dpiScale)
            if cachedGlyph == nil {
                print("glyph \(glyph) is not renderable")
                return
            }
        }
        textInstances[textInstanceIx + 0] = x0 + glyph.x + cachedGlyph!.xoff
        textInstances[textInstanceIx + 1] = y0 + glyph.y + cachedGlyph!.yoff
        textInstances[textInstanceIx + 2] = cachedGlyph!.width
        textInstances[textInstanceIx + 3] = cachedGlyph!.height
        textInstances[textInstanceIx + 4] = glyph.fgColor.0
        textInstances[textInstanceIx + 5] = glyph.fgColor.1
        textInstances[textInstanceIx + 6] = glyph.fgColor.2
        textInstances[textInstanceIx + 7] = glyph.fgColor.3
        textInstances[textInstanceIx + 8] = cachedGlyph!.uvCoords[0]
        textInstances[textInstanceIx + 9] = cachedGlyph!.uvCoords[1]
        textInstances[textInstanceIx + 10] = cachedGlyph!.uvCoords[2]
        textInstances[textInstanceIx + 11] = cachedGlyph!.uvCoords[3]
        textInstances[textInstanceIx + 12] = glyph.isEmoji ? 1 : 0
        textInstanceIx += textInstanceSize
        if textInstanceIx == maxTextInstances * textInstanceSize {
            flushDraw()
        }
    }

    /// Draw line background.
    func drawLineBg(line: TextLine, x0: GLfloat, yRange: Range<GLfloat>) {
        for bgRange in line.bgRanges {
            drawSolidRect(x: x0 + bgRange.range.lowerBound, y: yRange.lowerBound,
                          width: bgRange.range.upperBound - bgRange.range.lowerBound,
                          height: yRange.upperBound - yRange.lowerBound,
                          argb: bgRange.argb)
        }
    }

    /// Draw decorations (currently underline, but could expand in future).
    func drawLineDecorations(line: TextLine, x0: GLfloat, y0: GLfloat) {
        for underlineRange in line.underlineRanges {
            drawSolidRect(x: x0 + underlineRange.range.lowerBound, y: y0 + underlineRange.y.lowerBound,
                          width: underlineRange.range.upperBound - underlineRange.range.lowerBound,
                          height: underlineRange.y.upperBound - underlineRange.y.lowerBound,
                          argb: underlineRange.argb)

        }
    }

    /// Draw a rectangle for the given y range and the range of text (utf-16) offsets
    func drawRectForRange(line: TextLine, x0: GLfloat, yRange: Range<GLfloat>, utf16Range: CountableRange<Int>, argb: UInt32) {
        let xRange = getCtLineRange(line.ctLine, utf16Range)
        drawSolidRect(x: x0 + xRange.lowerBound, y: yRange.lowerBound, width: xRange.upperBound - xRange.lowerBound, height: yRange.upperBound - yRange.lowerBound, argb: argb)
    }

    func drawSolidRect(x: GLfloat, y: GLfloat, width: GLfloat, height: GLfloat, argb: UInt32) {
        prepareForDraw(.solid)
        let fgColor = argbToFloats(argb: argb)
        // TODO: figure out dpi scale story
        solidInstances[solidInstanceIx + 0] = x
        solidInstances[solidInstanceIx + 1] = y
        solidInstances[solidInstanceIx + 2] = width
        solidInstances[solidInstanceIx + 3] = height
        solidInstances[solidInstanceIx + 4] = fgColor.0
        solidInstances[solidInstanceIx + 5] = fgColor.1
        solidInstances[solidInstanceIx + 6] = fgColor.2
        solidInstances[solidInstanceIx + 7] = fgColor.3
        solidInstanceIx += solidInstanceSize
        if solidInstanceIx == maxSolidInstances * solidInstanceSize {
            flushDraw()
        }
    }

    /// The renderer's font cache. Useful for building text lines.
    var fontCache: FontCache {
        return atlas.fontCache
    }
}

/// Convert 0..1 sRGB value to linear
func sRgbToLinear(_ csrgb: CGFloat) -> GLfloat {
    if csrgb < 0.04045 {
        return GLfloat(csrgb * (1.0 / 12.92))
    } else {
        return powf(Float((csrgb + 0.055) * (1.0 / (1.0 + 0.055))), 2.4)
    }
}
