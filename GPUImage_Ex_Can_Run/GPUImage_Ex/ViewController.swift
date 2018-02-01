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
public let NORMAL_SIZE_HORIZONTAL: CGSize = CGSize(width: 568, height: 320)
public let NORMAL_SIZE_TEST: CGSize = CGSize(width: 1920, height: 1080)

// https://stackoverflow.com/questions/23679688/ios-save-gpuimage-video
// 音频 http://tuohuang.info/gpuimage-movie-writer-merging-all-audio-tracks-from-multiple-movies#.WmBrX5P1VTY
class ViewController: UIViewController {
    
    // 水印信息
    public var watermark: Watermark?

    public var moviePath: URL {
        return Bundle.main.url(forResource: "abc", withExtension: "mp4")!
    }
    
    // 视频
    private var movieFile: THImageMovie?
    
    // basic filter
    private var filter: GPUImageFilter?
    
    // 导出
    private var movieWriter: THImageMovieWriter?
//    private var zmovieWriter: ZGPUImageMovieWriter?
    
    // 混合滤镜
    var group: GPUImageFilterGroup?
    
//    let gpuimageWriterGroup: DispatchGroup = DispatchGroup()
    
    var music: AVAudioPlayer?
    var videoMusic: AVAudioPlayer?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let contentView = createWatermarks() {
            
            

            let asset = AVAsset(url: moviePath)
            var naturalSize: CGSize = .zero
            for track in asset.tracks {
                if track.mediaType == .video {
                    naturalSize = track.naturalSize
                }
            }
            print("视频大小:", naturalSize)

            /*
             public var kGPUImageFillModeStretch：GPUImageFillModeType {get} //拉伸以填满整个视图，这可能会使图像在正常高宽比之外变形
             public var kGPUImageFillModePreserveAspectRatio：GPUImageFillModeType {get} //保持源图像的宽高比，添加指定背景颜色的条
             public var kGPUImageFillModePreserveAspectRatioAndFill：GPUImageFillModeType {get} //保持源图像的宽高比，放大其中心以填充视图
             */
            // 旋转
//            let a = THImageMovieWriter.degressFromVideoFile(with: moviePath)
//            let rotate = CGAffineTransform(rotationAngle: CGFloat(a)/180.0*CGFloat.pi)
            

//            gpuimageWriterGroup.enter()
            let movieHeight = UIScreen.main.bounds.width * 9 / 16
            let frame = CGRect(x: 0, y: (UIScreen.main.bounds.height - movieHeight) / 2, width: UIScreen.main.bounds.width, height: movieHeight)
            
            print(frame)
//            let filterView: GPUImageView = GPUImageView(frame: frame)
            

//            filterView.fillMode = kGPUImageFillModePreserveAspectRatio
////            filterView.transform = rotate
//            view = filterView
            
            movieFile = THImageMovie(url: moviePath)
//            movieFile = THImageMovie.init(url: moviePath)
            movieFile?.playAtActualSpeed = true
            movieFile?.runBenchmark = true


            filter = GPUImageFilter()

            movieFile?.addTarget(filter)

            // 导出路径
            let pathToMovie: String = NSTemporaryDirectory() + "\(UUID().uuidString).mov"
            let movieURL: URL = URL(fileURLWithPath: pathToMovie)
            print("导出路径:", pathToMovie)
            movieWriter = THImageMovieWriter(movieURL: movieURL, size: NORMAL_SIZE_TEST, movies: [movieFile as Any])
//            movieWriter?.transform = rotate

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
//            group?.addTarget(filterView)
            img_element.addTarget(group?.terminalFilter)
            filter?.addTarget(group)
            
//            filter?.setInputRotation(kGPUImageRotateRight, at: 0)
            
            
            
            
//            movieWriter?.transform = rotate
            

            
            
            
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

    private func createWatermarks() -> UIView? {
        var contentView: UIView?
//        let k: CGFloat = 320/568
        if watermark != nil {
            contentView = UIView(frame: CGRect(origin: .zero, size: NORMAL_SIZE_TEST))
//            contentView = UIView(frame: UIScreen.main.bounds)
            contentView?.backgroundColor = .clear
        }
        if let draws = watermark?.draw {
            for draw in draws {
                let iv = UIImageView(frame: CGRect(origin: .zero, size: NORMAL_SIZE_TEST))
//                let iv: UIImageView = UIImageView(frame: UIScreen.main.bounds)
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
        

//        CGSize s = _tempView.bounds.size;
//        // 下面方法，第一个参数表示区域大小。第二个参数表示是否是非透明的。如果需要显示半透明效果，需要传NO，否则传YES。第三个参数就是屏幕密度了
//        UIGraphicsBeginImageContextWithOptions(s, NO, [UIScreen mainScreen].scale);
//        [_tempView.layer renderInContext:UIGraphicsGetCurrentContext()];
//        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
//        UIGraphicsEndImageContext();
//        return image;
//        UIGraphicsBeginImageContextWithOptions(contentView?.frame.size ?? .zero, true, UIScreen.main.scale)
//        contentView?.layer.render(in: UIGraphicsGetCurrentContext()!)
//        let img = UIGraphicsGetImageFromCurrentImageContext()!
//        UIGraphicsEndImageContext()
//
//        UIImageWriteToSavedPhotosAlbum(img, self, #selector(self.savedVideoToAblum(video:savedWithError:ci:)), nil)

        
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

