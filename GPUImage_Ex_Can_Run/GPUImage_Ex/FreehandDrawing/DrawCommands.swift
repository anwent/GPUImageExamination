//
//  DrawCommands.swift
//  Doodling
//
//  Created by wow250250 on 2017/8/2.
//  Copyright © 2017年 ZZH. All rights reserved.
//

import UIKit

/// 画布
protocol Canvas {
    var context: CGContext? { get }
    func reset()
}

/// 绘制
protocol DrawCommand {
    func execute(_ canvas: Canvas)
}

/// 绘制的命令
protocol DrawCommandReceiver {
    func executeCommands(_ command: [DrawCommand])
}
