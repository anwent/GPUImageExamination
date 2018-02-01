//
//  CircleDrawCommand.swift
//  Doodling
//
//  Created by wow250250 on 2017/8/2.
//  Copyright © 2017年 ZZH. All rights reserved.
//

import UIKit

/// 点击屏幕画点
struct CircleDrawCommand: DrawCommand {

    let circelCenter: CGPoint
    let circelRadius: CGFloat
    let circelColor: UIColor
    
    // MARK: DrawCommand protocol
    func execute(_ canvas: Canvas) {
        canvas.context?.setFillColor(circelColor.cgColor)
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.addArc(center: circelCenter,
                       radius: circelRadius,
                       startAngle: 0,
                       endAngle: 2 * CGFloat.pi,
                       clockwise: true)
        canvas.context?.setFillColor(UIColor.clear.cgColor)
        canvas.context?.fillPath()
    }
}
