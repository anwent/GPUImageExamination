//
//  ComposedCommand.swift
//  Doodling
//
//  Created by wow250250 on 2017/8/2.
//  Copyright © 2017年 ZZH. All rights reserved.
//

import UIKit

struct ComposedCommand: DrawCommand {
    
    private var commands: [DrawCommand]
    
    init(commadns: [DrawCommand]) {
        self.commands = commadns
    }
    
    // MARK: DrawCommand protocol
    func execute(_ canvas: Canvas) {
        let _ = commands.map({$0.execute(canvas)})
    }
    
    mutating func addCommand(_ command: DrawCommand) {
        commands.append(command)
    }
    
}
