//
//  Watermark.swift
//  GPUImage_Ex
//
//  Created by wow250250 on 2018/1/17.
//  Copyright © 2018年 wow250250. All rights reserved.
//

import UIKit

struct Watermark {
    var draw: [Watermark_Draw]?
    var emoji: [Watermark_Emoji]?
    var text: [Watermark_Text]?
}

struct Watermark_Draw {
    var buffer: UIImage?
}

struct Watermark_Emoji {
    var buffer: UILabel?
}

struct Watermark_Text {
    var buffer: String?
}
