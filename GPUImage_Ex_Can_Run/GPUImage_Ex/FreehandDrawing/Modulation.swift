//
//  WidthModulation.swift
//  Doodling
//
//  Created by wow250250 on 2017/8/2.
//  Copyright © 2017年 ZZH. All rights reserved.
//

import UIKit

class Modulation {
    
    public class func modulationWidth(width: CGFloat, velocity: CGPoint, previousVelocity: CGPoint, previousWidth: CGFloat) -> CGFloat {
        let velocityAdjustement: CGFloat = 600.0
        let speed = velocity.length / velocityAdjustement
        let previousSpeed = previousVelocity.length / velocityAdjustement
        let modulated = width / (0.6 * speed + 0.4 * previousSpeed)
        let limited = clamp(value: modulated, min: 0.90 * previousWidth, max: 1.10 * previousWidth)
        let final = clamp(value: limited, min: 0.2*width, max: width)
        return final
    }
    
    private class func clamp<T: Comparable>(value: T, min: T, max: T) -> T {
        if (value < min) { return min }
        if (value > max) { return max }
        return value
    }
    
}

extension CGPoint {
    var length: CGFloat {
        return sqrt((x*x) + (y*y))
    }
}
