//
//  ViewController.swift
//  GPUImage_Ex
//
//  Created by wow250250 on 2018/1/15.
//  Copyright © 2018年 wow250250. All rights reserved.
//

import UIKit
import GPUImage
import AVFoundation

public let NORMAL_SIZE_VERTICAL: CGSize = CGSize(width: 480, height: 640)
public let NORMAL_SIZE_HORIZONTAL: CGSize = CGSize(width: 640, height: 480)

// https://stackoverflow.com/questions/23679688/ios-save-gpuimage-video
// audio http://tuohuang.info/gpuimage-movie-writer-merging-all-audio-tracks-from-multiple-movies#.WmBrX5P1VTY
class ViewController: UIViewController {
    
    // 水印信息
    public var watermark: Watermark?

    public var moviePath: URL {
        return Bundle.main.url(forResource: "x", withExtension: "mov")!
    }
    
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
    
    // 视频
    private var movieFile: THImageMovie?
    
    // basic filter
    private var filter: GPUImageFilter?
    
    // 导出
    private var movieWriter: THImageMovieWriter?

    // 混合滤镜
    var group: GPUImageFilterGroup?
    
    var music: AVAudioPlayer?
    var videoMusic: AVAudioPlayer?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let contentView = createWatermarks(naturalSize: movieSize) {

            // 旋转
//            let a = THImageMovieWriter.degressFromVideoFile(with: moviePath)
//            let rotate = CGAffineTransform(rotationAngle: CGFloat(a)/180.0*CGFloat.pi)
            
            movieFile = THImageMovie(url: moviePath)
            movieFile?.playAtActualSpeed = true
            movieFile?.runBenchmark = true
            
            filter = GPUImageFilter()
            movieFile?.addTarget(filter)

            // 导出路径
            let pathToMovie: String = NSTemporaryDirectory() + "\(UUID().uuidString).mov"
            let movieURL: URL = URL(fileURLWithPath: pathToMovie)
            print("导出路径:", pathToMovie)
            let outputSize: CGSize = (movieSize?.width ?? 0)/(movieSize?.height ?? 0) < 1 ? NORMAL_SIZE_VERTICAL : NORMAL_SIZE_HORIZONTAL
            
            let bgm = Bundle.main.url(forResource: "Apart", withExtension: "mp3")!
            
            movieWriter = THImageMovieWriter(movieURL: movieURL, size: outputSize, movies: [movieFile as Any], bgm: bgm)

            // 初始化 group
            group = GPUImageFilterGroup()


            // 添加水印
            let img_element: GPUImageUIElement = GPUImageUIElement(view: contentView)

            // 反色滤镜
            let colorInvert: GPUImageColorInvertFilter = GPUImageColorInvertFilter()
            group?.addFilter(colorInvert)

            let blendFilter: GPUImageNormalBlendFilter = GPUImageNormalBlendFilter()
            group?.addFilter(blendFilter)

            // 混合的滤镜--
            
            // 全部加到group后创建链
            colorInvert.addTarget(blendFilter)
            group?.initialFilters = [colorInvert]
            group?.terminalFilter = blendFilter
            

            
            group?.addTarget(movieWriter)
            img_element.addTarget(group?.terminalFilter)
            filter?.addTarget(group)
            
//            filter?.setInputRotation(kGPUImageRotateRight, at: 0)

            movieFile?.startProcessing()
            movieWriter?.startRecording()
            

            filter?.frameProcessingCompletionBlock = { [unowned self] (_, time) in
                img_element.update()
                print("-----", self.movieFile?.progress)
            }
            
            
            movieWriter?.completionBlock = {
                print("Finish！！！！！！！:", pathToMovie)
//                UISaveVideoAtPathToSavedPhotosAlbum(
//                    pathToMovie,
//                    self,
//                    #selector(self.savedVideoToAblum(video:savedWithError:ci:)),
//                    nil
//                )
            }
            
        }
        

    }
    @objc func savedVideoToAblum(video: String, savedWithError error: NSError!, ci: UnsafeMutableRawPointer) {
        print("已保存到相冊")
    }
    // 获取视频音轨

    var assetAudioReader: AVAssetReader?
    var assetAudioReaderTrackOutput: AVAssetReaderAudioMixOutput?
    
    func setupAudioTrack(_ track: AVAssetTrack) {
        let mixComposition = AVMutableComposition()
        
        let compositionCommentaryTrack = mixComposition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )
        
        do {
            try compositionCommentaryTrack?.insertTimeRange(
                CMTimeRange(start: kCMTimeZero, end: track.asset!.duration),
                of: track,
                at: kCMTimeZero)
        } catch let error {
            assert(true, error.localizedDescription)
        }
        
        do {
            assetAudioReader = try AVAssetReader(asset: mixComposition)
        } catch let error {
            assert(true, error.localizedDescription)
        }
        
        assetAudioReaderTrackOutput = AVAssetReaderAudioMixOutput(audioTracks: mixComposition.tracks(withMediaType: .audio), audioSettings: nil)
        assetAudioReader?.add(assetAudioReaderTrackOutput!)
    }

    private func createWatermarks(naturalSize: CGSize?) -> UIView? {
        guard let `naturalSize` = naturalSize else {
            return nil
        }
        let ratio: CGFloat = naturalSize.width/naturalSize.height
        let watermarkSize: CGSize = ratio < 1 ? NORMAL_SIZE_VERTICAL : NORMAL_SIZE_HORIZONTAL
        var contentView: UIView?
        if watermark != nil {
            contentView = UIView(frame: CGRect(origin: .zero, size: watermarkSize))
            contentView?.backgroundColor = .clear
        }
        if let draws = watermark?.draw {
            for draw in draws {
                let iv = UIImageView(frame: CGRect(origin: .zero, size: watermarkSize))
                iv.image = draw.buffer
                iv.backgroundColor = .clear
                contentView?.addSubview(iv)
            }
        }
        if let emojis = watermark?.emoji {
            for emoji in emojis {
                let lb: UILabel? = emoji.buffer
                contentView?.addSubview(view: lb)
            }
        }
        return contentView
    }
    
    deinit {
        print("Deinit -- ViewController")
        GPUImageContext.setActiveShaderProgram(nil)
        GPUImageContext.sharedImageProcessing().framebufferCache.purgeAllUnassignedFramebuffers()
    }
    
}

extension GPUImageMovieWriter {
    public func finishVideoRecordingWithCompletionHandler(_ handler: @escaping ()->Swift.Void) {
        runSynchronouslyOnContextQueue(movieWriterContext) { [unowned self] in
            runAsynchronouslyOnContextQueue(self.movieWriterContext, handler)
        }
    }
}

