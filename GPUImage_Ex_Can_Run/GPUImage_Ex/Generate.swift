//
//  Generate.swift
//  GPUImage_Ex
//
//  Created by wow250250 on 2018/2/1.
//  Copyright © 2018年 wow250250. All rights reserved.
//

import UIKit
import GPUImage

public let NORMAL_SIZE_VERTICAL: CGSize = CGSize(width: 480, height: 640)
public let NORMAL_SIZE_HORIZONTAL: CGSize = CGSize(width: 640, height: 480)

//public struct Audio {
//    var audio
//}

public class GPUImageGenerateMovie {
    
//    (GPUImageOutput *, CMTime)
    public typealias BasicFilterframeProcessingCompletionHandler = (GPUImageOutput?, CMTime, Float?) -> Swift.Void
    public typealias MovieWriterCompleteHandler = (String) -> Swift.Void

    public var moviePath: URL
    public var bgm: URL?
    public var filter: GPUImageFilter?
    public var watermarks: UIView?
    
    private var movieSize: CGSize? {
        let asset = AVAsset(url: moviePath)
        var naturalSize: CGSize?
        for track in asset.tracks {
            if track.mediaType == .video {
                naturalSize = track.naturalSize
            }
        }
        return naturalSize
    }
    private var movieFile: THImageMovie?
    private var basicFilter: GPUImageFilter?
    private var outputURL: URL = URL(fileURLWithPath: NSTemporaryDirectory() + "\(UUID().uuidString).mp4")
    private var movieWriter: THImageMovieWriter?
    private var filterGroup: GPUImageFilterGroup?

    public init(_ moviePath: URL) {
        self.moviePath = moviePath
        
        movieFile = THImageMovie(url: moviePath)
        movieFile?.playAtActualSpeed = true
        movieFile?.runBenchmark = true
        
        basicFilter = GPUImageFilter()
        movieFile?.addTarget(basicFilter)
        
        let outputSize: CGSize = (movieSize?.width ?? 0)/(movieSize?.height ?? 0) < 1 ? NORMAL_SIZE_VERTICAL : NORMAL_SIZE_HORIZONTAL
        movieWriter = THImageMovieWriter(movieURL: moviePath, size: outputSize, movies: [movieFile as Any], bgm: bgm)
        
    }
    
    public func start(
        addFilter: (GPUImageOutput & GPUImageInput)?,
        basicFilterBlock: @escaping BasicFilterframeProcessingCompletionHandler,
        complete: @escaping MovieWriterCompleteHandler
        ) {
        
        // 有水印 有滤镜
        if let `watermarks` = watermarks, let newFilter = addFilter {
            filterGroup = GPUImageFilterGroup()
            let watermark_element: GPUImageUIElement = GPUImageUIElement(view: watermarks)
            filterGroup?.addFilter(newFilter)
            let blendFilter: GPUImageNormalBlendFilter = GPUImageNormalBlendFilter()
            filterGroup?.addFilter(blendFilter)
            newFilter.addTarget(blendFilter)
            filterGroup?.initialFilters = [newFilter]
            filterGroup?.terminalFilter = blendFilter
            
            filterGroup?.addTarget(movieWriter)
            watermark_element.addTarget(filterGroup?.terminalFilter)
            basicFilter?.addTarget(filterGroup)
            movieFile?.startProcessing()
            movieWriter?.startRecording()

            basicFilter?.frameProcessingCompletionBlock = { [weak self] (output, time) in
                watermark_element.update()
                basicFilterBlock(output, time, self?.movieFile?.progress)
            }
            
            movieWriter?.completionBlock = { [unowned self] in
                complete(self.outputURL.path)
            }
            
        }
    }
    
}

