//
//  VideoReader.swift
//  GPUImage_Ex
//
//  Created by wow250250 on 2018/1/19.
//  Copyright © 2018年 wow250250. All rights reserved.
//

import UIKit
import AVFoundation

public extension AVAsset {
    public func audioTrack() -> AVAssetTrack? {
        let audioTracks = tracks(withMediaType: .audio)
        return audioTracks.first
    }
}


