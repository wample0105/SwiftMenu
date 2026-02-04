import AppKit
import CoreGraphics

// 配置路径
let projectPath = "/Users/wample/coding/me/ApoRightMenu/ApoRightMenu"
let inputPath = "\(projectPath)/Assets.xcassets/AppIcon.appiconset/icon_512x512.png"
let outputDir = "\(projectPath)/Assets.xcassets/StatusBarIcon.imageset"
let outputPath1x = "\(outputDir)/statusbar_icon.png"
let outputPath2x = "\(outputDir)/statusbar_icon@2x.png"

func processIcon() {
    guard let inputImage = NSImage(contentsOfFile: inputPath) else {
        print("❌ 错误：找不到输入图片 \(inputPath)")
        exit(1)
    }

    guard let bitmap = NSBitmapImageRep(data: inputImage.tiffRepresentation!) else {
        print("❌ 错误：无法读取位图数据")
        exit(1)
    }

    let width = bitmap.pixelsWide
    let height = bitmap.pixelsHigh
    
    // 创建新的位图上下文
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    
    // 获取原始像素数据
    // 注意：这里我们通过一种更简单的方式：扫描像素，把"白色"保留并转黑，其他转透明
    // 由于 Swift 直接操作内存指针比较繁琐，我们用 CoreGraphics 绘制遮罩的方式
    
    // 1. 创建一个遮罩：基于原图的亮度/颜色
    // 既然前景是纯白 (255,255,255)，背景是有颜色的
    // 我们可以简单地定义：亮度极高的像素是前景
    
    // 手动处理像素数据
    guard let data = context.data else { exit(1) }
    
    // 绘制原图到 context 方便读取
    context.draw(bitmap.cgImage!, in: CGRect(x: 0, y: 0, width: width, height: height))
    
    let buffer = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
    
    var minX = width, maxX = 0, minY = height, maxY = 0
    var hasContent = false
    
    for y in 0..<height {
        for x in 0..<width {
            let offset = (y * width + x) * 4
            let r = buffer[offset]
            let g = buffer[offset + 1]
            let b = buffer[offset + 2]
            // let a = buffer[offset + 3]
            
            // 判断是否为白色前景（容差设为 240）
            // 注意：因为已预乘 alpha，如果 alpha 不为 255，rgb 值会小。这里假设 alpha 是 255
            let isWhite = r > 220 && g > 220 && b > 220
            
            if isWhite {
                // 是前景：设为黑色 (0, 0, 0, 255)
                buffer[offset] = 0     // R
                buffer[offset + 1] = 0 // G
                buffer[offset + 2] = 0 // B
                buffer[offset + 3] = 255 // A
                
                // 记录边界
                if x < minX { minX = x }
                if x > maxX { maxX = x }
                if y < minY { minY = y } // 坐标系原点在左下还是左上取决于 context，CoreGraphics 通常原点在左下，内存顺序通常是行优先
                if y > maxY { maxY = y }
                hasContent = true
            } else {
                // 是背景：设为全透明
                buffer[offset] = 0
                buffer[offset + 1] = 0
                buffer[offset + 2] = 0
                buffer[offset + 3] = 0
            }
        }
    }
    
    if !hasContent {
        print("❌ 错误：未检测到白色前景内容")
        exit(1)
    }
    
    // 2. 根据边界裁剪（Crop）
    // 内存中的 y 是从上到下的（通常）
    // 增加一点 padding
    let padding = 0
    let cropRect = CGRect(x: max(0, minX - padding), 
                          y: max(0, minY - padding), 
                          width: min(width - minX, maxX - minX + 1 + padding * 2), 
                          height: min(height - minY, maxY - minY + 1 + padding * 2))
    
    guard let fullImage = context.makeImage(),
          let croppedImage = fullImage.cropping(to: cropRect) else {
        print("❌ 错误：每法创建裁剪图像")
        exit(1)
    }
    
    // 3. 缩放到目标尺寸 (1x: 18px, 2x: 36px)
    // 保持纵横比缩放
    func saveResized(to path: String, targetSize: Int) {
        let maxDim = max(cropRect.width, cropRect.height)
        let scale = CGFloat(targetSize) / CGFloat(maxDim)
        let newWidth = Int(CGFloat(cropRect.width) * scale)
        let newHeight = Int(CGFloat(cropRect.height) * scale)
        
        let newColorSpace = CGColorSpaceCreateDeviceRGB()
        let newContext = CGContext(data: nil, width: targetSize, height: targetSize, bitsPerComponent: 8, bytesPerRow: 0, space: newColorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        
        // 居中绘制
        let offsetX = (targetSize - newWidth) / 2
        let offsetY = (targetSize - newHeight) / 2
        
        // 确保高质量缩放
        newContext.interpolationQuality = .high
        newContext.draw(croppedImage, in: CGRect(x: offsetX, y: offsetY, width: newWidth, height: newHeight))
        
        if let resultImage = newContext.makeImage() {
            let destURL = URL(fileURLWithPath: path)
            let destDest = CGImageDestinationCreateWithURL(destURL as CFURL, kUTTypePNG, 1, nil)!
            CGImageDestinationAddImage(destDest, resultImage, nil)
            CGImageDestinationFinalize(destDest)
            print("✅ 已保存: \(path)")
        }
    }
    
    saveResized(to: outputPath1x, targetSize: 18)  // 之前是 18，稍微大一点点利用空间
    saveResized(to: outputPath2x, targetSize: 36)
}

processIcon()
