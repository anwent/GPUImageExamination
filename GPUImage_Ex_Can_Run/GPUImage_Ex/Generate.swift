//
//  Generate.swift
//  GPUImage_Ex
//
//  Created by wow250250 on 2018/2/1.
//  Copyright © 2018年 wow250250. All rights reserved.
//

import UIKit
import GPUImage

public class GenerateMovie {
    
    public var moviePath: URL
    public var bgm: URL?
    public var filter: GPUImageFilter?
    public var watermarks: UIView?

    public init(_ moviePath: URL) {
        self.moviePath = moviePath
    }

    public static func usingGPUImage() {
        
    }

}

