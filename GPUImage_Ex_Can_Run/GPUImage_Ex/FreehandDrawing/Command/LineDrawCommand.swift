//
//  LineDrawCommand.swift
//  Doodling
//
//  Created by wow250250 on 2017/8/2.
//  Copyright © 2017年 ZZH. All rights reserved.
//

import UIKit

/// 画线
struct LineDrawCommand: DrawCommand {
    let current: Segment
    let previous: Segment?
    
    let lineWidth: CGFloat
    
    let lineColor: UIColor
    
    var points = [CGPoint?]()

    // MARK: DrawCommand protocol
    func execute(_ canvas: Canvas) {
        configure(canvas)
        guard previous == nil else {
            drawQuadraticCurve(canvas)
            return
        }
        drawLine(canvas)
    }
    
    /// 配置
    ///
    /// - Parameter canvas: 绘制的画布
    private func configure(_ canvas: Canvas) {
        canvas.context?.setStrokeColor(lineColor.cgColor)
        canvas.context?.setLineWidth(lineWidth)
        canvas.context?.setLineCap(.round)
    }
    
    /// 画线
    ///
    /// - Parameter canvas: 绘制的画布
    private func drawLine(_ canvas: Canvas) {
        canvas.context?.move(to: points[0]!)
        canvas.context?.addCurve(to: points[3]!, control1: points[1]!, control2: points[2]!)
        canvas.context?.strokePath()
    }
    
    /// 绘制二次曲线
    ///
    /// - Parameter canvas: 绘制的画布
    private func drawQuadraticCurve(_ canvas: Canvas) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.setFillColor(UIColor.clear.cgColor)
        context.move(to: points[0]!)
        context.addCurve(to: points[3]!, control1: points[1]!, control2: points[2]!)
        canvas.context?.strokePath()
    }
}
