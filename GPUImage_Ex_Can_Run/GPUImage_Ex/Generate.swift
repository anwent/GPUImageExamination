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

public class GPUImageGenerateMovie {
    
    public typealias BasicFilterframeProcessingCompletionHandler = (GPUImageOutput?, CMTime, Float?) -> Swift.Void
    public typealias MovieWriterCompleteHandler = (String) -> Swift.Void
    
    public var moviePath: URL
    public var bgm: URL?
    public var filter: GPUImageFilter?
    public var watermarks: UIView?
    public var addFilter: (GPUImageInput & GPUImageOutput)?
    
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
//        addFilter: (GPUImageOutput & GPUImageInput)?,
        basicFilterBlock: @escaping BasicFilterframeProcessingCompletionHandler,
        complete: @escaping MovieWriterCompleteHandler
        ) {
        
        // 有水印 有滤镜
        if watermarks != nil && addFilter != nil {
            filterGroup = GPUImageFilterGroup()
            let watermark_element: GPUImageUIElement = GPUImageUIElement(view: watermarks)
            filterGroup?.addFilter(addFilter)
            let blendFilter: GPUImageNormalBlendFilter = GPUImageNormalBlendFilter()
            filterGroup?.addFilter(blendFilter)
            addFilter?.addTarget(blendFilter)
            filterGroup?.initialFilters = [addFilter as Any]
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
        
        // 只有水印
        if watermarks != nil && addFilter == nil {
            let watermark_element: GPUImageUIElement = GPUImageUIElement(view: watermarks)
            let blendFilter: GPUImageNormalBlendFilter = GPUImageNormalBlendFilter()
            movieFile?.addTarget(basicFilter)
            basicFilter?.addTarget(blendFilter)
            watermark_element.addTarget(blendFilter)
            blendFilter.addTarget(movieWriter)
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
        
        // 只有滤镜
        if watermarks == nil && addFilter != nil {
            movieFile?.addTarget(basicFilter)
            basicFilter?.addTarget(addFilter)
            addFilter?.addTarget(movieWriter)
            movieFile?.startProcessing()
            movieWriter?.startRecording()
            basicFilter?.frameProcessingCompletionBlock = { [weak self] (output, time) in
                basicFilterBlock(output, time, self?.movieFile?.progress)
            }
            movieWriter?.completionBlock = { [unowned self] in
                complete(self.outputURL.path)
            }
        }
    }
    
}

