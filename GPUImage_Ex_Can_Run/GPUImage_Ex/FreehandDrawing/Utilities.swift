//
//  Utilities.swift
//  Doodling
//
//  Created by wow250250 on 2017/8/2.
//  Copyright © 2017年 ZZH. All rights reserved.
//

import UIKit

struct Segment {
    let a: CGPoint
    let b: CGPoint
    let width: CGFloat
    
    var midPotin: CGPoint {
        return CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }
}
