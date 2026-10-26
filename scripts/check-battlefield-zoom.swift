// Run from the repository root: swift scripts/check-battlefield-zoom.swift
// Exercise the actual Metal fragment shader at every supported zoom step.
import Foundation
import Metal
let device = MTLCreateSystemDefaultDevice()!
let text = try String(contentsOfFile: "common/ipados_palette_renderer.mm", encoding: .utf8)
let shader = String(text.components(separatedBy: "R\"METAL(")[1].components(separatedBy: ")METAL\"")[0])
let library = try device.makeLibrary(source: shader, options: nil)
let pipeline = MTLRenderPipelineDescriptor()
pipeline.vertexFunction = library.makeFunction(name: "TiberianDawnPaletteVertex")
pipeline.fragmentFunction = library.makeFunction(name: "TiberianDawnPaletteFragment")
pipeline.colorAttachments[0].pixelFormat = .rgba8Unorm
let state = try device.makeRenderPipelineState(descriptor: pipeline)
let queue = device.makeCommandQueue()!
func texture(_ format: MTLPixelFormat, _ w: Int, _ h: Int) -> MTLTexture {
    let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: format, width: w, height: h, mipmapped: false)
    desc.storageMode = .shared; desc.usage = [.shaderRead, .renderTarget]
    return device.makeTexture(descriptor: desc)!
}
let palette = texture(.rgba8Unorm,256,1)
var colors = [UInt8](repeating: 255, count: 1024)
for i in 0..<256 { colors[i*4]=UInt8(i); colors[i*4+1]=UInt8(255-i); colors[i*4+2]=0 }
palette.replace(region: MTLRegionMake2D(0,0,256,1),mipmapLevel:0,withBytes:colors,bytesPerRow:1024)
struct Params { var w:Float;var h:Float;var outw:Float;var outh:Float;var mode:UInt32=1;var art:UInt32=0 }
var checks=0
for (vw,vh) in [(640,900),(1200,400)] {
    let right=vw-160, top=16
    for quarters in 2...12 {
        let zoom=Float(quarters)/4
        let sw=max(vw,Int(ceil(Float(right)/zoom))+160)
        let sh=max(vh,top+Int(ceil(Float(vh-top)/zoom)))
        var pixels=[UInt8](repeating:0,count:sw*sh)
        for y in 0..<sh { for x in 0..<sw { pixels[y*sw+x]=UInt8((x/8+(y/8)*7)%240) } }
        let input=texture(.r8Uint,sw,sh)
        input.replace(region:MTLRegionMake2D(0,0,sw,sh),mipmapLevel:0,withBytes:pixels,bytesPerRow:sw)
        let output=texture(.rgba8Unorm,vw,vh)
        let pass=MTLRenderPassDescriptor(); pass.colorAttachments[0].texture=output
        pass.colorAttachments[0].loadAction = .clear; pass.colorAttachments[0].storeAction = .store
        let command=queue.makeCommandBuffer()!, encoder=command.makeRenderCommandEncoder(descriptor:pass)!
        encoder.setRenderPipelineState(state)
        var params=Params(w:Float(sw),h:Float(sh),outw:Float(vw),outh:Float(vh))
        var scene=SIMD4<Float>(zoom,Float(right),Float(top),0), size=SIMD2<Float>(Float(vw),Float(vh))
        encoder.setFragmentBytes(&params,length:MemoryLayout<Params>.size,index:0)
        encoder.setFragmentBytes(&scene,length:MemoryLayout<SIMD4<Float>>.size,index:1)
        encoder.setFragmentBytes(&size,length:MemoryLayout<SIMD2<Float>>.size,index:2)
        encoder.setFragmentTexture(input,index:0); encoder.setFragmentTexture(palette,index:1)
        encoder.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:6);encoder.endEncoding()
        command.commit();command.waitUntilCompleted()
        precondition(command.status == .completed,"GPU command failed")
        var rgba=[UInt8](repeating:0,count:vw*vh*4)
        output.getBytes(&rgba,bytesPerRow:vw*4,from:MTLRegionMake2D(0,0,vw,vh),mipmapLevel:0)
        for y in stride(from:3,to:vh,by:17) { for x in stride(from:3,to:vw,by:19) {
            var px=Float(x)+0.5,py=Float(y)+0.5
            if x<right && y>=top { px/=zoom;py=Float(top)+(py-Float(top))/zoom }
            else if (y>=top && x>=right)||(y<top && x>=vw-320) { px+=Float(sw-vw) }
            let expected=pixels[min(sh-1,Int(py))*sw+min(sw-1,Int(px))]
            precondition(abs(Int(rgba[(y*vw+x)*4])-Int(expected))<=1,"Mismatch at zoom \(zoom), pixel \(x),\(y)")
            checks+=1
        } }
    }
}
print("Metal zoom checks passed: \(checks) pixel samples, all 11 steps, portrait and landscape")
