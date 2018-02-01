//
//  MovieWriter.swift
//  GPUImage_Ex
//
//  Created by wow250250 on 2018/1/19.
//  Copyright © 2018年 wow250250. All rights reserved.
//

import UIKit
import GPUImage
import OpenGLES

public class ImageMovieWriter {
    
    private var alreadyFinishedRecording: Bool?
    
    private var movieURL: URL?
    
    private var fileType: String = ""
    
    private var assetWriter: AVAssetWriter?
    
    private var assetWriterAudioInput: AVAssetWriterInput?
    
    private var assetWirterVideoInput: AVAssetWriterInput?
    
    private var movieWriterContext: GPUImageContext?
    
    private var renderTarget: CVPixelBuffer?
    
    private var renderTexture: CVOpenGLESTexture?
    
    private var videoSize: CGSize?
    
    private var inputRotation: GPUImageRotationMode?
    
    public var hasAudioTrack: Bool?
    
    public var shouldPassthroughAudio: Bool?
    
    public var shouldInvalidateAudioSampleWhenDone: Bool?
    
    public weak var delegate: ImageMovieWriterDelegate?
    
    public var encodingLiveVideo: Bool?
    
    public var enabled: Bool?
    
    public var transform: CGAffineTransform?

    public func initWithMovieURL() {
        
    }
    
    
}
public typealias ExportHandler = (AVAssetExportSession) -> Swift.Void
public func setupAudioAssetReader(asset: AVAsset, background musicURL: URL, outputURL: URL, complete: ExportHandler?) {
    var audioTracks: [AVAssetTrack] = []
    // 原视频音乐
    if let movieTrack = asset.audioTrack() {
        audioTracks.append(movieTrack)
    }
    // 背景音乐
    if let bgmTrack = AVAsset(url: musicURL).audioTrack() {
        audioTracks.append(bgmTrack)
    }
    let mixComposition = AVMutableComposition()
    // ======
    
    let assetAudioReader: AVAssetReader?
    
    let assetAudioReaderTrackOutput: AVAssetReaderAudioMixOutput?
    
    
    for track in audioTracks {
        let compositionCommentaryTrack = mixComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        do {
            try compositionCommentaryTrack?.insertTimeRange(CMTimeRange.init(start: kCMTimeZero, duration: track.asset!.duration), of: track, at: kCMTimeZero)
        } catch let error {
            assert(true, error.localizedDescription)
        }
    }
    
    do {
        assetAudioReader = try AVAssetReader(asset: mixComposition)
        assetAudioReaderTrackOutput = AVAssetReaderAudioMixOutput.init(audioTracks: audioTracks, audioSettings: nil)
        
        assetAudioReader?.add(assetAudioReaderTrackOutput!)
    } catch let error {
        assert(true, error.localizedDescription)
    }
    
//    assetAudioReader = AVAssetReader.init(asset: <#T##AVAsset#>)

    // ======
    
    // 将两段合并好的音频加入视频Track中
    let videoTrack = asset.tracks(withMediaType: .video)[0]
    let v_compositionCommentaryTrack = mixComposition.addMutableTrack(
        withMediaType: .video,
        preferredTrackID: kCMPersistentTrackID_Invalid
    )
    do {
        try v_compositionCommentaryTrack?.insertTimeRange(
            CMTimeRange(start: kCMTimeZero, end: asset.duration),
            of: videoTrack,
            at: kCMTimeZero
        )
    } catch let error {
        assert(true, error.localizedDescription)
    }
    
    
    for track in audioTracks {
        print("---音轨： ", track)
        let compositionCommentaryTrack = mixComposition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )
        
        do {
            try compositionCommentaryTrack?.insertTimeRange(
                CMTimeRange(start: kCMTimeZero, duration: track.asset?.duration ?? kCMTimeZero),
                of: track,
                at: kCMTimeZero
            )
        } catch let error {
            assert(true, error.localizedDescription)
        }
    }
    
    
    
    // 导出 export
    let mainInstruction = AVMutableVideoCompositionInstruction()
    mainInstruction.timeRange = CMTimeRangeMake(kCMTimeZero, asset.duration)
//    let videolayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
//    var isVideoAssetPortrait = false
//    let videoTransform = asset.preferredTransform
//    if (videoTransform.a == 0 && videoTransform.b == 1.0 && videoTransform.c == -1.0 && videoTransform.d == 0) {
//        isVideoAssetPortrait = true
//    }
//    if (videoTransform.a == 0 && videoTransform.b == -1.0 && videoTransform.c == 1.0 && videoTransform.d == 0) {
//        isVideoAssetPortrait = true
//    }
//    videolayerInstruction.setTransform(videoTrack.preferredTransform, at: kCMTimeZero)
//    videolayerInstruction.setOpacity(0.0, at: asset.duration)
//    // 3.3 - Add instructions
//    mainInstruction.layerInstructions = [videolayerInstruction]
    let mainCompositionInst = AVMutableVideoComposition()
//    var naturalSize = CGSize()
//    if isVideoAssetPortrait {
//        naturalSize = CGSize(width: videoTrack.naturalSize.height, height: videoTrack.naturalSize.width)
//    } else {
//        naturalSize = videoTrack.naturalSize
//    }
//    var renderWidth = CGFloat(), renderHeight = CGFloat()
//    renderWidth = naturalSize.width
//    renderHeight = naturalSize.height
    mainCompositionInst.renderSize = NORMAL_SIZE_VERTICAL
    mainCompositionInst.instructions = [mainInstruction]
    mainCompositionInst.frameDuration = CMTimeMake(1, 30)
    guard let exporter = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality) else { return }
    exporter.outputURL = outputURL
    exporter.outputFileType = .mov
    exporter.shouldOptimizeForNetworkUse = true
    exporter.videoComposition = mainCompositionInst
    exporter.exportAsynchronously {
        DispatchQueue.main.async {
            if exporter.status == .completed {
                complete?(exporter)
            } else {
                print("Exporter Error State Code = \(exporter.status.rawValue), ", exporter.error.debugDescription)
            }
        }
    }
    
}


