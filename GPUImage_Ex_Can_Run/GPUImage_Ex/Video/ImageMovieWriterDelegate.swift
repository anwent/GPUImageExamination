//
//  ImageMovieWriterDelegate.swift
//  GPUImage_Ex
//
//  Created by wow250250 on 2018/1/19.
//  Copyright © 2018年 wow250250. All rights reserved.
//

import UIKit

@objc public protocol ImageMovieWriterDelegate {
    @objc optional func movieRecordingCompleted()
    @objc optional func movieRecordingFailedWithError(_ error: NSError)
}
