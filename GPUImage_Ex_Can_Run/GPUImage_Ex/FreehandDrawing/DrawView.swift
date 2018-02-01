//
//  DrawView.swift
//  Doodling
//
//  Created by wow250250 on 2017/8/2.
//  Copyright © 2017年 ZZH. All rights reserved.
//

import UIKit

class DrawView: UIView, Canvas, DrawCommandReceiver {
    
    typealias DrawInContextHandler = (CGContext?) -> Void
    
    public var expandLayer: CALayer?
    
    public var executeCommandsCtx: CGContext?
    // MARK: Canvas protocol
    
    var context: CGContext? {
        get { return UIGraphicsGetCurrentContext() }
    }
    
    func reset() {
        buffer = nil
        layer.contents = nil
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
    }
    
    
    deinit {
        print("Release --- DrawView ----")
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        context?.clear(rect)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func expandContext(ctx: CGContext?, expandCtx handler: DrawInContextHandler) {
        guard let boundingBox = ctx?.boundingBoxOfPath else { return }
        
        let boundingBoxAspectRatio = boundingBox.width / boundingBox.height // 比例
        let viewAspectRatio: CGFloat = 1080/1920
        var scaleFactor: CGFloat = 1.0
        if boundingBoxAspectRatio > viewAspectRatio {
            scaleFactor = 1080 / boundingBox.width
        } else {
            scaleFactor = 1920 / boundingBox.height
        }
        var scaleTransform = CGAffineTransform.identity
        scaleTransform = CGAffineTransform(scaleX: scaleFactor, y: scaleFactor)
        scaleTransform = scaleTransform.translatedBy(x: -boundingBox.minX, y: -boundingBox.minY)
        
        let scaledSize = __CGSizeApplyAffineTransform(boundingBox.size, CGAffineTransform(scaleX: scaleFactor, y: scaleFactor))
        
        let centerOffset = CGSize(width: (1080 - scaledSize.width) / (scaleFactor * 2.0),
                                  height: (1920 - scaledSize.height) / (scaleFactor * 2.0))
        scaleTransform = scaleTransform.translatedBy(x: centerOffset.width, y: centerOffset.height)
        ctx?.scaleBy(x: centerOffset.width, y: centerOffset.height)
        handler(ctx)
    }
    
    // MARK: DrawCommandReceiver protocol
    
    func executeCommands(_ command: [DrawCommand]) {
        autoreleasepool {
            buffer = drawInContext { [weak self] (context) in
                guard let `self` = self else { return }
                let _ = command.map({$0.execute(self)})
                self.executeCommandsCtx = context
            }
            layer.contents = buffer?.cgImage
        }
    }
    
    var buffer: UIImage?
    
    private func drawInContext(handler: DrawInContextHandler) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(bounds.size, false, 0)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        context.clear(bounds)
        context.setFillColor(UIColor.clear.cgColor)
        context.fill(bounds)
        
        self.backgroundColor = .clear
        
        // 绘制缓冲区
        if let buffer = buffer {
            buffer.draw(in: bounds)
        }
        handler(context)
        // 更新缓冲区并返回image
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
}
