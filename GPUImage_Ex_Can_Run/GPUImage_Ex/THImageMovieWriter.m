#import "THImageMovieWriter.h"
#import "GPUImageContext.h"
#import "GLProgram.h"
#import "GPUImageFilter.h"
#import "THImageMovie.h"
#import "THImageMovieManager.h"

NSString *const kTHImageColorSwizzlingFragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 
 void main()
 {
     gl_FragColor = texture2D(inputImageTexture, textureCoordinate).bgra;
 }
 );


@interface THImageMovieWriter ()
{
    GLuint movieFramebuffer, movieRenderbuffer;
    
    GLProgram *colorSwizzlingProgram;
    GLint colorSwizzlingPositionAttribute, colorSwizzlingTextureCoordinateAttribute;
    GLint colorSwizzlingInputTextureUniform;
    
    GPUImageFramebuffer *firstInputFramebuffer;
    
    CMTime startTime, previousFrameTime, previousAudioTime;
    
    dispatch_queue_t audioQueue, videoQueue;
    BOOL audioEncodingIsFinished, videoEncodingIsFinished;
    
    BOOL isRecording;
}


@property(nonatomic, strong) NSArray *movies;
@property(nonatomic, strong) THImageMovie *th_movie;
@property(nonatomic, strong) NSURL *basicMovieURL;
@property(nonatomic, strong) NSURL *bgmURL;
@property(nonatomic, strong) AVAssetReader *assetAudioReader;
@property(nonatomic, strong) AVAssetReaderAudioMixOutput *assetAudioReaderTrackOutput;

@property(nonatomic, strong) dispatch_group_t recordingDispatchGroup;
@property(nonatomic, assign) BOOL audioFinished, videoFinished, isFrameRecieved;
@property(nonatomic, copy)  void (^onFramePixelBufferReceived)(CMTime, CVPixelBufferRef);


// Movie recording
- (void)initializeMovieWithOutputSettings:(NSMutableDictionary *)outputSettings;

// Frame rendering
- (void)createDataFBO;
- (void)destroyDataFBO;
- (void)setFilterFBO;

- (void)renderAtInternalSizeUsingFramebuffer:(GPUImageFramebuffer *)inputFramebufferToUse;

@end

@implementation THImageMovieWriter

@synthesize hasAudioTrack = _hasAudioTrack;
@synthesize encodingLiveVideo = _encodingLiveVideo;
@synthesize shouldPassthroughAudio = _shouldPassthroughAudio;
@synthesize completionBlock;
@synthesize failureBlock;
@synthesize videoInputReadyCallback;
@synthesize audioInputReadyCallback;
@synthesize enabled;
@synthesize shouldInvalidateAudioSampleWhenDone = _shouldInvalidateAudioSampleWhenDone;
@synthesize paused = _paused;
@synthesize movieWriterContext = _movieWriterContext;

@synthesize delegate = _delegate;

#pragma mark -
#pragma mark Initialization and teardown

- (id)initWithMovieURL:(NSURL *)newMovieURL size:(CGSize)newSize basicURL:(NSURL *)url bgmURL:(NSURL *)bgmUrl
{
//    return [self initWithMovieURL:newMovieURL size:newSize basicURL:url];
    return [self initWithMovieURL:newMovieURL size:newSize fileType:AVFileTypeQuickTimeMovie outputSettings:nil basicURL:url bgmURL:bgmUrl];
}

- (id)initWithMovieURL:(NSURL *)newMovieURL size:(CGSize)newSize fileType:(NSString *)newFileType outputSettings:(NSMutableDictionary *)outputSettings basicURL:(NSURL *)url bgmURL:(NSURL *)bgmUrl;
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    THImageMovie *m = [[THImageMovie alloc] initWithURL:_basicMovieURL];
    self.movies = @[m];
    
    _bgmURL = bgmUrl;
    _basicMovieURL = url;
    _shouldInvalidateAudioSampleWhenDone = NO;
    
    self.enabled = YES;
    alreadyFinishedRecording = NO;
    videoEncodingIsFinished = NO;
    audioEncodingIsFinished = NO;
    
    videoSize = newSize;
    movieURL = newMovieURL;
    fileType = newFileType;
    startTime = kCMTimeInvalid;
    _encodingLiveVideo = [[outputSettings objectForKey:@"EncodingLiveVideo"] isKindOfClass:[NSNumber class]] ? [[outputSettings objectForKey:@"EncodingLiveVideo"] boolValue] : YES;
    previousFrameTime = kCMTimeNegativeInfinity;
    previousAudioTime = kCMTimeNegativeInfinity;
    inputRotation = kGPUImageNoRotation;
    
    _movieWriterContext = [[GPUImageContext alloc] init];
    [_movieWriterContext useSharegroup:[[[GPUImageContext sharedImageProcessingContext] context] sharegroup]];
    
    runSynchronouslyOnContextQueue(_movieWriterContext, ^{
        [_movieWriterContext useAsCurrentContext];
        
        if ([GPUImageContext supportsFastTextureUpload])
        {
            colorSwizzlingProgram = [_movieWriterContext programForVertexShaderString:kGPUImageVertexShaderString fragmentShaderString:kGPUImagePassthroughFragmentShaderString];
        }
        else
        {
            colorSwizzlingProgram = [_movieWriterContext programForVertexShaderString:kGPUImageVertexShaderString fragmentShaderString:kTHImageColorSwizzlingFragmentShaderString];
        }
        
        if (!colorSwizzlingProgram.initialized)
        {
            [colorSwizzlingProgram addAttribute:@"position"];
            [colorSwizzlingProgram addAttribute:@"inputTextureCoordinate"];
            
            if (![colorSwizzlingProgram link])
            {
                NSString *progLog = [colorSwizzlingProgram programLog];
                NSLog(@"Program link log: %@", progLog);
                NSString *fragLog = [colorSwizzlingProgram fragmentShaderLog];
                NSLog(@"Fragment shader compile log: %@", fragLog);
                NSString *vertLog = [colorSwizzlingProgram vertexShaderLog];
                NSLog(@"Vertex shader compile log: %@", vertLog);
                colorSwizzlingProgram = nil;
                NSAssert(NO, @"Filter shader link failed");
            }
        }
        
        colorSwizzlingPositionAttribute = [colorSwizzlingProgram attributeIndex:@"position"];
        colorSwizzlingTextureCoordinateAttribute = [colorSwizzlingProgram attributeIndex:@"inputTextureCoordinate"];
        colorSwizzlingInputTextureUniform = [colorSwizzlingProgram uniformIndex:@"inputImageTexture"];
        
        [_movieWriterContext setContextShaderProgram:colorSwizzlingProgram];
        
        glEnableVertexAttribArray(colorSwizzlingPositionAttribute);
        glEnableVertexAttribArray(colorSwizzlingTextureCoordinateAttribute);
    });
    
    [self initializeMovieWithOutputSettings:outputSettings];
    
    return self;
}


- (id)initWithMovieURL:(NSURL *)newMovieURL size:(CGSize)newSize movies:(NSArray *)movies;
{
    return [self initWithMovieURL:newMovieURL size:newSize fileType:AVFileTypeQuickTimeMovie outputSettings:nil movies:movies];
}

- (id)initWithMovieURL:(NSURL *)newMovieURL size:(CGSize)newSize fileType:(NSString *)newFileType outputSettings:(NSMutableDictionary *)outputSettings movies:(NSArray *)pMovies;
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    self.movies = pMovies;
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"abc" withExtension:@"mp4"];
    self.th_movie = [[THImageMovie alloc] initWithURL:url];
    _shouldInvalidateAudioSampleWhenDone = NO;
    
    self.enabled = YES;
    alreadyFinishedRecording = NO;
    videoEncodingIsFinished = NO;
    audioEncodingIsFinished = NO;
    
    videoSize = newSize;
    movieURL = newMovieURL;
    fileType = newFileType;
    startTime = kCMTimeInvalid;
    _encodingLiveVideo = [[outputSettings objectForKey:@"EncodingLiveVideo"] isKindOfClass:[NSNumber class]] ? [[outputSettings objectForKey:@"EncodingLiveVideo"] boolValue] : YES;
    previousFrameTime = kCMTimeNegativeInfinity;
    previousAudioTime = kCMTimeNegativeInfinity;
    inputRotation = kGPUImageNoRotation;
    
    _movieWriterContext = [[GPUImageContext alloc] init];
    [_movieWriterContext useSharegroup:[[[GPUImageContext sharedImageProcessingContext] context] sharegroup]];
    
    runSynchronouslyOnContextQueue(_movieWriterContext, ^{
        [_movieWriterContext useAsCurrentContext];
        
        if ([GPUImageContext supportsFastTextureUpload])
        {
            colorSwizzlingProgram = [_movieWriterContext programForVertexShaderString:kGPUImageVertexShaderString fragmentShaderString:kGPUImagePassthroughFragmentShaderString];
        }
        else
        {
            colorSwizzlingProgram = [_movieWriterContext programForVertexShaderString:kGPUImageVertexShaderString fragmentShaderString:kTHImageColorSwizzlingFragmentShaderString];
        }
        
        if (!colorSwizzlingProgram.initialized)
        {
            [colorSwizzlingProgram addAttribute:@"position"];
            [colorSwizzlingProgram addAttribute:@"inputTextureCoordinate"];
            
            if (![colorSwizzlingProgram link])
            {
                NSString *progLog = [colorSwizzlingProgram programLog];
                NSLog(@"Program link log: %@", progLog);
                NSString *fragLog = [colorSwizzlingProgram fragmentShaderLog];
                NSLog(@"Fragment shader compile log: %@", fragLog);
                NSString *vertLog = [colorSwizzlingProgram vertexShaderLog];
                NSLog(@"Vertex shader compile log: %@", vertLog);
                colorSwizzlingProgram = nil;
                NSAssert(NO, @"Filter shader link failed");
            }
        }
        
        colorSwizzlingPositionAttribute = [colorSwizzlingProgram attributeIndex:@"position"];
        colorSwizzlingTextureCoordinateAttribute = [colorSwizzlingProgram attributeIndex:@"inputTextureCoordinate"];
        colorSwizzlingInputTextureUniform = [colorSwizzlingProgram uniformIndex:@"inputImageTexture"];
        
        [_movieWriterContext setContextShaderProgram:colorSwizzlingProgram];
        
        glEnableVertexAttribArray(colorSwizzlingPositionAttribute);
        glEnableVertexAttribArray(colorSwizzlingTextureCoordinateAttribute);
    });
    
    [self initializeMovieWithOutputSettings:outputSettings];
    
    return self;
}

- (void)dealloc;
{
    [self destroyDataFBO];
    
#if !OS_OBJECT_USE_OBJC
    if( audioQueue != NULL )
    {
        dispatch_release(audioQueue);
    }
    if( videoQueue != NULL )
    {
        dispatch_release(videoQueue);
    }
#endif
}

#pragma mark -
#pragma mark Movie recording

- (void)initializeMovieWithOutputSettings:(NSDictionary *)outputSettings;
{
    isRecording = NO;
    
    self.enabled = YES;
    NSError *error = nil;
    assetWriter = [[AVAssetWriter alloc] initWithURL:movieURL fileType:fileType error:&error];
    if (error != nil)
    {
        NSLog(@"Error: %@", error);
        if (failureBlock)
        {
            failureBlock(error);
        }
        else
        {
            if(self.delegate && [self.delegate respondsToSelector:@selector(movieRecordingFailedWithError:)])
            {
                [self.delegate movieRecordingFailedWithError:error];
            }
        }
    }
    
    // Set this to make sure that a functional movie is produced, even if the recording is cut off mid-stream. Only the last second should be lost in that case.
    assetWriter.movieFragmentInterval = CMTimeMakeWithSeconds(1.0, 1000);
    
    // use default output settings if none specified
    if (outputSettings == nil)
    {
        NSMutableDictionary *settings = [[NSMutableDictionary alloc] init];
        [settings setObject:AVVideoCodecH264 forKey:AVVideoCodecKey];
        [settings setObject:[NSNumber numberWithInt:videoSize.width] forKey:AVVideoWidthKey];
        [settings setObject:[NSNumber numberWithInt:videoSize.height] forKey:AVVideoHeightKey];
        outputSettings = settings;
    }
    // custom output settings specified
    else
    {
        NSString *videoCodec = [outputSettings objectForKey:AVVideoCodecKey];
        NSNumber *width = [outputSettings objectForKey:AVVideoWidthKey];
        NSNumber *height = [outputSettings objectForKey:AVVideoHeightKey];
        
        NSAssert(videoCodec && width && height, @"OutputSettings is missing required parameters.");
        
        if( [outputSettings objectForKey:@"EncodingLiveVideo"] ) {
            NSMutableDictionary *tmp = [outputSettings mutableCopy];
            [tmp removeObjectForKey:@"EncodingLiveVideo"];
            outputSettings = tmp;
        }
    }
    
    assetWriterVideoInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:outputSettings];
    assetWriterVideoInput.expectsMediaDataInRealTime = _encodingLiveVideo;
    
    // BGRA <==> RGBA
    NSDictionary *sourcePixelBufferAttributesDictionary = [NSDictionary dictionaryWithObjectsAndKeys: [NSNumber numberWithInt:kCVPixelFormatType_32BGRA], kCVPixelBufferPixelFormatTypeKey,
                                                           [NSNumber numberWithInt:videoSize.width], kCVPixelBufferWidthKey,
                                                           [NSNumber numberWithInt:videoSize.height], kCVPixelBufferHeightKey,
                                                           nil];
    
    self.assetWriterPixelBufferInput = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:assetWriterVideoInput sourcePixelBufferAttributes:sourcePixelBufferAttributesDictionary];
    
    [assetWriter addInput:assetWriterVideoInput];
}

- (void)setEncodingLiveVideo:(BOOL) value
{
    _encodingLiveVideo = value;
    if (isRecording) {
        NSAssert(NO, @"Can not change Encoding Live Video while recording");
    }
    else
    {
        assetWriterVideoInput.expectsMediaDataInRealTime = _encodingLiveVideo;
        assetWriterAudioInput.expectsMediaDataInRealTime = _encodingLiveVideo;
    }
}

#pragma mark setupAssetWriter
/**
 *  设置读取音频信息的Reader
 */
- (void)setupAudioAssetReader {
    
    NSMutableArray *audioTracks = [NSMutableArray array];
    
    NSURL *movie = [[NSBundle mainBundle] URLForResource:@"abc" withExtension:@"mp4"];
    AVAsset *movieAsset = [AVAsset assetWithURL:movie];
    NSArray *movieTrack = [movieAsset tracksWithMediaType:AVMediaTypeAudio];
    [audioTracks addObject:movieTrack.firstObject];

    NSURL *audio = [[NSBundle mainBundle] URLForResource:@"Apart" withExtension:@"mp3"];
    AVAsset *audioAsset = [AVAsset assetWithURL:audio];
    NSArray *audioTrack = [audioAsset tracksWithMediaType:AVMediaTypeAudio];
    [audioTracks addObject:audioTrack.firstObject];

    AVMutableComposition* mixComposition = [AVMutableComposition composition];
    
    for(AVAssetTrack *track in audioTracks){
        if(![track isKindOfClass:[NSNull class]]){
            NSLog(@"track url: %@ duration: %.2f", track.asset, CMTimeGetSeconds(track.asset.duration));
            AVMutableCompositionTrack *compositionCommentaryTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio
                                                                     
                                                                                                preferredTrackID:kCMPersistentTrackID_Invalid];
            [compositionCommentaryTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, track.asset.duration)
                                                ofTrack:track
                                                 atTime:kCMTimeZero error:nil];
        }
    }
    
    self.assetAudioReader = [AVAssetReader assetReaderWithAsset:mixComposition error:nil];
    self.assetAudioReaderTrackOutput =
    [[AVAssetReaderAudioMixOutput alloc] initWithAudioTracks:[mixComposition tracksWithMediaType:AVMediaTypeAudio]
                                               audioSettings:nil];
    
    [self.assetAudioReader addOutput:self.assetAudioReaderTrackOutput];
}


/**
 *  设置写入音频信息的Writer
 */
- (void)setupAudioAssetWriter{
    double sampleRate = [[AVAudioSession sharedInstance] sampleRate];
    
    AudioChannelLayout acl;
    bzero( &acl, sizeof(acl));
    acl.mChannelLayoutTag = kAudioChannelLayoutTag_Mono;
    
    NSDictionary *audioOutputSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                         [ NSNumber numberWithInt: kAudioFormatMPEG4AAC], AVFormatIDKey,
                                         [ NSNumber numberWithInt: 1 ], AVNumberOfChannelsKey,
                                         @(sampleRate), AVSampleRateKey,
                                         [ NSData dataWithBytes: &acl length: sizeof( acl ) ], AVChannelLayoutKey,
                                         //[ NSNumber numberWithInt:AVAudioQualityLow], AVEncoderAudioQualityKey,
                                         [ NSNumber numberWithInt: 64000 ], AVEncoderBitRateKey,
                                         nil];
    
    assetWriterAudioInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:audioOutputSettings];
    [assetWriter addInput:assetWriterAudioInput];
    assetWriterAudioInput.expectsMediaDataInRealTime = _encodingLiveVideo;
}


/**
 *  开始录制
 */
- (void)startRecording;
{
    // 设置就绪后的block，需要等reader和writer都就绪才开始录制
    dispatch_group_notify([THImageMovieManager shared].readingAllReadyDispatchGroup, dispatch_get_main_queue(), ^{
        NSLog(@"all set, readers and writer both are ready");
        [self setupAudioAssetReader];
        [self setupAudioAssetWriter];
        
        alreadyFinishedRecording = NO;
        isRecording = YES;
        
        BOOL aduioReaderStartSuccess = [self.assetAudioReader startReading];
        if(!aduioReaderStartSuccess){
            NSLog(@"asset audio reader start reading failed: %@", self.assetAudioReader.error);
            return;
        }
        
        startTime = kCMTimeInvalid;
        [self.assetWriter startWriting];
        [self.assetWriter startSessionAtSourceTime:kCMTimeZero];
        NSLog(@"asset write is good to write...");
        
        [self kickoffRecording];
    });
}

- (void)kickoffRecording {

    // If the asset reader and writer both started successfully, create the dispatch group where the reencoding will take place and start a sample-writing session.
    self.recordingDispatchGroup = dispatch_group_create();
    self.audioFinished = NO;
    self.videoFinished = NO;
    
    [self kickOffAudioWriting];
    [self kickOffVideoWriting];
    
    __unsafe_unretained typeof(self) weakSelf = self;
    // Set up the notification that the dispatch group will send when the audio and video work have both finished.
    dispatch_group_notify(self.recordingDispatchGroup, [THImageMovieManager shared].mainSerializationQueue, ^{
        weakSelf.videoFinished = NO;
        weakSelf.audioFinished = NO;
        [weakSelf.assetWriter finishWritingWithCompletionHandler:^{
            if(weakSelf.completionBlock){
                weakSelf.completionBlock();
            }
        }];
    });

}

- (void)kickOffAudioWriting {
    dispatch_group_enter(self.recordingDispatchGroup);
    __unsafe_unretained typeof(self) weakSelf = self;
    
    CMTime shortestDuration = kCMTimeInvalid;
    for(THImageMovie *movie in self.movies) {
        AVAsset *asset = movie.asset;
        if(CMTIME_IS_INVALID(shortestDuration)){
            shortestDuration = asset.duration;
        }else{
            
            if(CMTimeCompare(asset.duration, shortestDuration) == -1){
                shortestDuration = asset.duration;
            }
        }
    }
    
    [assetWriterAudioInput requestMediaDataWhenReadyOnQueue:[THImageMovieManager shared].rwAudioSerializationQueue usingBlock:^{
        // Because the block is called asynchronously, check to see whether its task is complete.
        if (self.audioFinished)
            return;
        
        BOOL completedOrFailed = NO;
        // If the task isn't complete yet, make sure that the input is actually ready for more media data.
        while ([assetWriterAudioInput isReadyForMoreMediaData] && !completedOrFailed) {
            // Get the next audio sample buffer, and append it to the output file.
            CMSampleBufferRef sampleBuffer = [self.assetAudioReaderTrackOutput copyNextSampleBuffer];
            if (sampleBuffer != NULL) {
                CMTime currentSampleTime = CMSampleBufferGetOutputPresentationTimeStamp(sampleBuffer);
                BOOL isDone = CMTimeCompare(shortestDuration, currentSampleTime) == -1;
                
                BOOL success = [assetWriterAudioInput appendSampleBuffer:sampleBuffer];
                weakSelf.audioWroteDuration = CMTimeGetSeconds(currentSampleTime);
                if (success) {
                    //NSLog(@"append audio buffer success");
                } else {
                    NSLog(@"append audio buffer failed");
                }
                CFRelease(sampleBuffer);
                sampleBuffer = NULL;
                completedOrFailed = !success;
                
                if(isDone){
                    completedOrFailed = YES;
                }
            }
            else {
                completedOrFailed = YES;
            }
        }//end of loop
        
        if (completedOrFailed) {
            NSLog(@"kickOffAudioWriting wrint done");
            // Mark the input as finished, but only if we haven't already done so, and then leave the dispatch group (since the audio work has finished).
            BOOL oldFinished = self.audioFinished;
            self.audioFinished = YES;
            if (!oldFinished) {
                [assetWriterAudioInput markAsFinished];
                dispatch_group_leave(self.recordingDispatchGroup);
            };
        }
    }];
}

- (void)kickOffVideoWriting {
    
    dispatch_group_enter(self.recordingDispatchGroup);
    self.isFrameRecieved = NO;
    __unsafe_unretained typeof(self) weakSelf = self;
    self.firstVideoFrameTime = -1;
    self.onFramePixelBufferReceived = ^(CMTime frameTime, CVPixelBufferRef pixel_buffer){
        [weakSelf.assetWriterPixelBufferInput appendPixelBuffer:pixel_buffer withPresentationTime:frameTime];
        if(weakSelf.firstVideoFrameTime == -1){
            weakSelf.firstVideoFrameTime = CMTimeGetSeconds(frameTime);
        }
        CVPixelBufferUnlockBaseAddress(pixel_buffer, 0);
        weakSelf.videoWroteDuration = CMTimeGetSeconds(frameTime);
        if (![GPUImageContext supportsFastTextureUpload])
        {
            CVPixelBufferRelease(pixel_buffer);
        }
        weakSelf.isFrameRecieved = NO;
    };
    
    [assetWriterVideoInput requestMediaDataWhenReadyOnQueue:dispatch_get_main_queue() usingBlock:^{
//    [assetWriterVideoInput requestMediaDataWhenReadyOnQueue:[THImageMovieManager shared].rwVideoSerializationQueue usingBlock:^{
        if (self.videoFinished)
            return;
        BOOL completedOrFailed = NO;
        // If the task isn't complete yet, make sure that the input is actually ready for more media data.
        while ([assetWriterVideoInput isReadyForMoreMediaData] && !completedOrFailed) {
            if(!self.isFrameRecieved){
                self.isFrameRecieved = YES;
                for(THImageMovie *movie in self.movies){
                    BOOL hasMoreFrame = [movie renderNextFrame];
                    //NSLog(@"--movie: %@, has more frames: %d", movie.url.lastPathComponent, hasMoreFrame);
                    if(!hasMoreFrame){
                        completedOrFailed = YES;
                        break;
                    }
                }
            }
        }
        
        if(completedOrFailed){
            NSLog(@"kickOffVideoWriting mark as finish");
            // Mark the input as finished, but only if we haven't already done so, and then leave the dispatch group (since the video work has finished).
            BOOL oldFinished = self.videoFinished;
            self.videoFinished = YES;
            if (!oldFinished) {
                for(THImageMovie *movie in self.movies){
                    [movie cancelProcessing];
                }
                [assetWriterVideoInput markAsFinished];
                dispatch_group_leave(self.recordingDispatchGroup);
            }
        }
    }];
    
}
//- (void)kickOffVideoWriting {
//
//    dispatch_group_enter(self.recordingDispatchGroup);
//    self.isFrameRecieved = NO;
//    __unsafe_unretained typeof(self) weakSelf = self;
//    self.firstVideoFrameTime = -1;
//    self.onFramePixelBufferReceived = ^(CMTime frameTime, CVPixelBufferRef pixel_buffer){
//
//        [weakSelf.assetWriterPixelBufferInput appendPixelBuffer:pixel_buffer withPresentationTime:frameTime];
//        if(weakSelf.firstVideoFrameTime == -1){
//            weakSelf.firstVideoFrameTime = CMTimeGetSeconds(frameTime);
//        }
//        CVPixelBufferUnlockBaseAddress(pixel_buffer, 0);
//
//        weakSelf.videoWroteDuration = CMTimeGetSeconds(frameTime);
//
//        if (![GPUImageContext supportsFastTextureUpload])
//        {
//            CVPixelBufferRelease(pixel_buffer);
//        }
//        weakSelf.isFrameRecieved = NO;
//    };
//    THImageMovie *movie = [[THImageMovie alloc] initWithURL:_basicMovieURL];
//    [assetWriterVideoInput requestMediaDataWhenReadyOnQueue:[THImageMovieManager shared].rwVideoSerializationQueue usingBlock:^{
//        if (self.videoFinished)
//            return;
//        BOOL completedOrFailed = NO;
//        // If the task isn't complete yet, make sure that the input is actually ready for more media data.
//        while ([assetWriterVideoInput isReadyForMoreMediaData] && !completedOrFailed) {
//            if(!self.isFrameRecieved){
//                self.isFrameRecieved = YES;
//                BOOL hasMoreFrame = [movie renderNextFrame];
//                NSLog(@"%@, ", movie);
//                if(!hasMoreFrame){
//                    completedOrFailed = YES;
//                    break;
//                }
//            }
//        }
//
//        if(completedOrFailed){
//            NSLog(@"kickOffVideoWriting mark as finish");
//            // Mark the input as finished, but only if we haven't already done so, and then leave the dispatch group (since the video work has finished).
//            BOOL oldFinished = self.videoFinished;
//            self.videoFinished = YES;
//            if (!oldFinished) {
//                [movie cancelProcessing];
//                [assetWriterVideoInput markAsFinished];
//                dispatch_group_leave(self.recordingDispatchGroup);
//            }
//        }
//    }];
//}

- (void)startRecordingInOrientation:(CGAffineTransform)orientationTransform;

{
    assetWriterVideoInput.transform = orientationTransform;
    
    
    [self startRecording];
}

- (void)cancelRecording;
{
    if (assetWriter.status == AVAssetWriterStatusCompleted)
    {
        return;
    }
    
    isRecording = NO;
    runSynchronouslyOnContextQueue(_movieWriterContext, ^{
        alreadyFinishedRecording = YES;
        
        if( assetWriter.status == AVAssetWriterStatusWriting && ! videoEncodingIsFinished )
        {
            videoEncodingIsFinished = YES;
            [assetWriterVideoInput markAsFinished];
        }
        if( assetWriter.status == AVAssetWriterStatusWriting && ! audioEncodingIsFinished )
        {
            audioEncodingIsFinished = YES;
            [assetWriterAudioInput markAsFinished];
        }
        [assetWriter cancelWriting];
    });
}

- (void)finishRecording;
{
    [self finishRecordingWithCompletionHandler:NULL];
}

- (void)finishRecordingWithCompletionHandler:(void (^)(void))handler;
{
    runSynchronouslyOnContextQueue(_movieWriterContext, ^{
        isRecording = NO;
        
        if (assetWriter.status == AVAssetWriterStatusCompleted || assetWriter.status == AVAssetWriterStatusCancelled || assetWriter.status == AVAssetWriterStatusUnknown)
        {
            if (handler)
                runAsynchronouslyOnContextQueue(_movieWriterContext, handler);
            return;
        }
        if( assetWriter.status == AVAssetWriterStatusWriting && ! videoEncodingIsFinished )
        {
            videoEncodingIsFinished = YES;
            [assetWriterVideoInput markAsFinished];
        }
        if( assetWriter.status == AVAssetWriterStatusWriting && ! audioEncodingIsFinished )
        {
            audioEncodingIsFinished = YES;
            [assetWriterAudioInput markAsFinished];
        }
#if (!defined(__IPHONE_6_0) || (__IPHONE_OS_VERSION_MAX_ALLOWED < __IPHONE_6_0))
        // Not iOS 6 SDK
        [assetWriter finishWriting];
        if (handler)
            runAsynchronouslyOnContextQueue(_movieWriterContext,handler);
#else
        // iOS 6 SDK
        if ([assetWriter respondsToSelector:@selector(finishWritingWithCompletionHandler:)]) {
            // Running iOS 6
            [assetWriter finishWritingWithCompletionHandler:(handler ?: ^{ })];
        }
        else {
            // Not running iOS 6
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            [assetWriter finishWriting];
#pragma clang diagnostic pop
            if (handler)
                runAsynchronouslyOnContextQueue(_movieWriterContext, handler);
        }
#endif
    });
}

- (void)processAudioBuffer:(CMSampleBufferRef)audioBuffer;
{
    if (!isRecording)
    {
        return;
    }
    
    if (_hasAudioTrack)
    {
        CFRetain(audioBuffer);
        
        CMTime currentSampleTime = CMSampleBufferGetOutputPresentationTimeStamp(audioBuffer);
        
        if (CMTIME_IS_INVALID(startTime))
        {
            runSynchronouslyOnContextQueue(_movieWriterContext, ^{
                if ((audioInputReadyCallback == NULL) && (assetWriter.status != AVAssetWriterStatusWriting))
                {
                    [assetWriter startWriting];
                }
                [assetWriter startSessionAtSourceTime:currentSampleTime];
                startTime = currentSampleTime;
            });
        }
        
        if (!assetWriterAudioInput.readyForMoreMediaData && _encodingLiveVideo)
        {
            NSLog(@"1: Had to drop an audio frame: %@", CFBridgingRelease(CMTimeCopyDescription(kCFAllocatorDefault, currentSampleTime)));
            if (_shouldInvalidateAudioSampleWhenDone)
            {
                CMSampleBufferInvalidate(audioBuffer);
            }
            CFRelease(audioBuffer);
            return;
        }
        
        previousAudioTime = currentSampleTime;
        
        //if the consumer wants to do something with the audio samples before writing, let him.
        if (self.audioProcessingCallback) {
            //need to introspect into the opaque CMBlockBuffer structure to find its raw sample buffers.
            CMBlockBufferRef buffer = CMSampleBufferGetDataBuffer(audioBuffer);
            CMItemCount numSamplesInBuffer = CMSampleBufferGetNumSamples(audioBuffer);
            AudioBufferList audioBufferList;
            
            CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(audioBuffer,
                                                                    NULL,
                                                                    &audioBufferList,
                                                                    sizeof(audioBufferList),
                                                                    NULL,
                                                                    NULL,
                                                                    kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
                                                                    &buffer
                                                                    );
            //passing a live pointer to the audio buffers, try to process them in-place or we might have syncing issues.
            for (int bufferCount=0; bufferCount < audioBufferList.mNumberBuffers; bufferCount++) {
                SInt16 *samples = (SInt16 *)audioBufferList.mBuffers[bufferCount].mData;
                self.audioProcessingCallback(&samples, numSamplesInBuffer);
            }
        }
        
        NSLog(@"Recorded audio sample time: %lld, %d, %lld", currentSampleTime.value, currentSampleTime.timescale, currentSampleTime.epoch);
        void(^write)() = ^() {
            while( ! assetWriterAudioInput.readyForMoreMediaData && ! _encodingLiveVideo && ! audioEncodingIsFinished ) {
                NSDate *maxDate = [NSDate dateWithTimeIntervalSinceNow:0.5];
                NSLog(@"audio waiting...");
                [[NSRunLoop currentRunLoop] runUntilDate:maxDate];
            }
            if (!assetWriterAudioInput.readyForMoreMediaData)
            {
                NSLog(@"2: Had to drop an audio frame %@", CFBridgingRelease(CMTimeCopyDescription(kCFAllocatorDefault, currentSampleTime)));
            }
            else if(assetWriter.status == AVAssetWriterStatusWriting)
            {
                if (![assetWriterAudioInput appendSampleBuffer:audioBuffer])
                    NSLog(@"Problem appending audio buffer at time: %@", CFBridgingRelease(CMTimeCopyDescription(kCFAllocatorDefault, currentSampleTime)));
            }
            else
            {
                NSLog(@"Wrote an audio frame %@", CFBridgingRelease(CMTimeCopyDescription(kCFAllocatorDefault, currentSampleTime)));
            }
            
            if (_shouldInvalidateAudioSampleWhenDone)
            {
                CMSampleBufferInvalidate(audioBuffer);
            }
            CFRelease(audioBuffer);
        };
        if( _encodingLiveVideo )
            
        {
            runAsynchronouslyOnContextQueue(_movieWriterContext, write);
        }
        else
        {
            write();
        }
    }
}

- (void)enableSynchronizationCallbacks;
{

    if (videoInputReadyCallback != NULL)
    {
        if( assetWriter.status != AVAssetWriterStatusWriting )
        {
            [assetWriter startWriting];
        }
        videoQueue = dispatch_queue_create("com.sunsetlakesoftware.GPUImage.videoReadingQueue", NULL);
        [assetWriterVideoInput requestMediaDataWhenReadyOnQueue:dispatch_get_main_queue() usingBlock:^{
//            <#code#>
//        }];
//        [assetWriterVideoInput requestMediaDataWhenReadyOnQueue:videoQueue usingBlock:^{
            if( _paused )
            {
                usleep(10000);
                return;
            }
            while( assetWriterVideoInput.readyForMoreMediaData && ! _paused )
            {
                if( videoInputReadyCallback && ! videoInputReadyCallback() && ! videoEncodingIsFinished )
                {
                    runAsynchronouslyOnContextQueue(_movieWriterContext, ^{
                        if( assetWriter.status == AVAssetWriterStatusWriting && ! videoEncodingIsFinished )
                        {
                            videoEncodingIsFinished = YES;
                            [assetWriterVideoInput markAsFinished];
                        }
                    });
                }
            }
        }];
    }
    
    if (audioInputReadyCallback != NULL)
    {
        audioQueue = dispatch_queue_create("com.sunsetlakesoftware.GPUImage.audioReadingQueue", NULL);
        [assetWriterAudioInput requestMediaDataWhenReadyOnQueue:audioQueue usingBlock:^{
            if( _paused )
            {
                usleep(10000);
                return;
            }
            while( assetWriterAudioInput.readyForMoreMediaData && ! _paused )
            {
                if( audioInputReadyCallback && ! audioInputReadyCallback() && ! audioEncodingIsFinished )
                {
                    runAsynchronouslyOnContextQueue(_movieWriterContext, ^{
                        if( assetWriter.status == AVAssetWriterStatusWriting && ! audioEncodingIsFinished )
                        {
                            audioEncodingIsFinished = YES;
                            [assetWriterAudioInput markAsFinished];
                        }
                    });
                }
            }
        }];
    }
    
}

#pragma mark -
#pragma mark Frame rendering

- (void)createDataFBO;
{
    glActiveTexture(GL_TEXTURE1);
    glGenFramebuffers(1, &movieFramebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, movieFramebuffer);
    
    if ([GPUImageContext supportsFastTextureUpload])
    {
        // Code originally sourced from http://allmybrain.com/2011/12/08/rendering-to-a-texture-with-ios-5-texture-cache-api/
        
        
        CVPixelBufferPoolCreatePixelBuffer (NULL, [self.assetWriterPixelBufferInput pixelBufferPool], &renderTarget);
        
        /* AVAssetWriter will use BT.601 conversion matrix for RGB to YCbCr conversion
         * regardless of the kCVImageBufferYCbCrMatrixKey value.
         * Tagging the resulting video file as BT.601, is the best option right now.
         * Creating a proper BT.709 video is not possible at the moment.
         */
        CVBufferSetAttachment(renderTarget, kCVImageBufferColorPrimariesKey, kCVImageBufferColorPrimaries_ITU_R_709_2, kCVAttachmentMode_ShouldPropagate);
        CVBufferSetAttachment(renderTarget, kCVImageBufferYCbCrMatrixKey, kCVImageBufferYCbCrMatrix_ITU_R_601_4, kCVAttachmentMode_ShouldPropagate);
        CVBufferSetAttachment(renderTarget, kCVImageBufferTransferFunctionKey, kCVImageBufferTransferFunction_ITU_R_709_2, kCVAttachmentMode_ShouldPropagate);
        
        CVOpenGLESTextureCacheCreateTextureFromImage (kCFAllocatorDefault, [_movieWriterContext coreVideoTextureCache], renderTarget,
                                                      NULL, // texture attributes
                                                      GL_TEXTURE_2D,
                                                      GL_RGBA, // opengl format
                                                      (int)videoSize.width,
                                                      (int)videoSize.height,
                                                      GL_BGRA, // native iOS format
                                                      GL_UNSIGNED_BYTE,
                                                      0,
                                                      &renderTexture);
        
        glBindTexture(CVOpenGLESTextureGetTarget(renderTexture), CVOpenGLESTextureGetName(renderTexture));
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, CVOpenGLESTextureGetName(renderTexture), 0);
    }
    else
    {
        glGenRenderbuffers(1, &movieRenderbuffer);
        glBindRenderbuffer(GL_RENDERBUFFER, movieRenderbuffer);
        glRenderbufferStorage(GL_RENDERBUFFER, GL_RGBA8_OES, (int)videoSize.width, (int)videoSize.height);
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, movieRenderbuffer);
    }
    
    
    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    
    NSAssert(status == GL_FRAMEBUFFER_COMPLETE, @"Incomplete filter FBO: %d", status);
}

- (void)destroyDataFBO;
{
    runSynchronouslyOnContextQueue(_movieWriterContext, ^{
        [_movieWriterContext useAsCurrentContext];
        
        if (movieFramebuffer)
        {
            glDeleteFramebuffers(1, &movieFramebuffer);
            movieFramebuffer = 0;
        }
        
        if (movieRenderbuffer)
        {
            glDeleteRenderbuffers(1, &movieRenderbuffer);
            movieRenderbuffer = 0;
        }
        
        if ([GPUImageContext supportsFastTextureUpload])
        {
            if (renderTexture)
            {
                CFRelease(renderTexture);
            }
            if (renderTarget)
            {
                CVPixelBufferRelease(renderTarget);
            }
            
        }
    });
}

- (void)setFilterFBO;
{
    if (!movieFramebuffer)
    {
        [self createDataFBO];
    }
    
    glBindFramebuffer(GL_FRAMEBUFFER, movieFramebuffer);
    
    glViewport(0, 0, (int)videoSize.width, (int)videoSize.height);
}

- (void)renderAtInternalSizeUsingFramebuffer:(GPUImageFramebuffer *)inputFramebufferToUse;
{
    [_movieWriterContext useAsCurrentContext];
    [self setFilterFBO];
    
    [_movieWriterContext setContextShaderProgram:colorSwizzlingProgram];
    
    glClearColor(1.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    static const GLfloat squareVertices[] = {
        -1.0f, -1.0f,
        1.0f, -1.0f,
        -1.0f,  1.0f,
        1.0f,  1.0f,
    };
    
    const GLfloat *textureCoordinates = [GPUImageFilter textureCoordinatesForRotation:inputRotation];
    
    glActiveTexture(GL_TEXTURE4);
    glBindTexture(GL_TEXTURE_2D, [inputFramebufferToUse texture]);
    glUniform1i(colorSwizzlingInputTextureUniform, 4);
    
    glVertexAttribPointer(colorSwizzlingPositionAttribute, 2, GL_FLOAT, 0, 0, squareVertices);
    glVertexAttribPointer(colorSwizzlingTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, textureCoordinates);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    glFinish();
}

#pragma mark -
#pragma mark GPUImageInput protocol

- (void)newFrameReadyAtTime:(CMTime)frameTime atIndex:(NSInteger)textureIndex;
{
    if (!isRecording)
    {
        [firstInputFramebuffer unlock];
        return;
    }
    
    GPUImageFramebuffer *inputFramebufferForBlock = firstInputFramebuffer;
    glFinish();
    
    [_movieWriterContext useAsCurrentContext];
    
    [self renderAtInternalSizeUsingFramebuffer:inputFramebufferForBlock];
    
    CVPixelBufferRef pixel_buffer = NULL;
    
    if ([GPUImageContext supportsFastTextureUpload])
    {
        pixel_buffer = renderTarget;
        CVPixelBufferLockBaseAddress(pixel_buffer, 0);
    }
    else
    {
        CVReturn status = CVPixelBufferPoolCreatePixelBuffer (NULL, [self.assetWriterPixelBufferInput pixelBufferPool], &pixel_buffer);
        if ((pixel_buffer == NULL) || (status != kCVReturnSuccess))
        {
            CVPixelBufferRelease(pixel_buffer);
            return;
        }
        else
        {
            CVPixelBufferLockBaseAddress(pixel_buffer, 0);
            
            GLubyte *pixelBufferData = (GLubyte *)CVPixelBufferGetBaseAddress(pixel_buffer);
            glReadPixels(0, 0, videoSize.width, videoSize.height, GL_RGBA, GL_UNSIGNED_BYTE, pixelBufferData);
        }
    }
    
    runAsynchronouslyOnContextQueue(_movieWriterContext, ^{
        if (!assetWriterVideoInput.readyForMoreMediaData && _encodingLiveVideo)
        {
            [inputFramebufferForBlock unlock];
            NSLog(@"1: Had to drop a video frame: %@", CFBridgingRelease(CMTimeCopyDescription(kCFAllocatorDefault, frameTime)));
            return;
        }
        
        // Render the frame with swizzled colors, so that they can be uploaded quickly as BGRA frames
        [_movieWriterContext useAsCurrentContext];
        [self renderAtInternalSizeUsingFramebuffer:inputFramebufferForBlock];
        
        CVPixelBufferRef pixel_buffer = NULL;
        
        if ([GPUImageContext supportsFastTextureUpload])
        {
            pixel_buffer = renderTarget;
            CVPixelBufferLockBaseAddress(pixel_buffer, 0);
        }
        else
        {
            CVReturn status = CVPixelBufferPoolCreatePixelBuffer (NULL, [self.assetWriterPixelBufferInput pixelBufferPool], &pixel_buffer);
            if ((pixel_buffer == NULL) || (status != kCVReturnSuccess))
            {
                CVPixelBufferRelease(pixel_buffer);
                return;
            }
            else
            {
                CVPixelBufferLockBaseAddress(pixel_buffer, 0);
                
                GLubyte *pixelBufferData = (GLubyte *)CVPixelBufferGetBaseAddress(pixel_buffer);
                glReadPixels(0, 0, videoSize.width, videoSize.height, GL_RGBA, GL_UNSIGNED_BYTE, pixelBufferData);
            }
        }
        
        if(self.onFramePixelBufferReceived){
            self.onFramePixelBufferReceived(frameTime, pixel_buffer);
        }
        
        [inputFramebufferForBlock unlock];
    });
}

- (NSInteger)nextAvailableTextureIndex;
{
    return 0;
}

- (void)setInputFramebuffer:(GPUImageFramebuffer *)newInputFramebuffer atIndex:(NSInteger)textureIndex;
{
    [newInputFramebuffer lock];
    firstInputFramebuffer = newInputFramebuffer;
    
}

- (void)setInputRotation:(GPUImageRotationMode)newInputRotation atIndex:(NSInteger)textureIndex;
{
    inputRotation = newInputRotation;
}

- (void)setInputSize:(CGSize)newSize atIndex:(NSInteger)textureIndex;
{
}

- (CGSize)maximumOutputSize;
{
    return videoSize;
}

- (void)endProcessing
{
}

- (BOOL)shouldIgnoreUpdatesToThisTarget;
{
    return NO;
}

- (BOOL)wantsMonochromeInput;
{
    return NO;
}

- (void)setCurrentlyReceivingMonochromeInput:(BOOL)newValue;
{
    
}

#pragma mark -
#pragma mark Accessors

- (void)setHasAudioTrack:(BOOL)newValue
{
    [self setHasAudioTrack:newValue audioSettings:nil];
}

- (void)setHasAudioTrack:(BOOL)newValue audioSettings:(NSDictionary *)audioOutputSettings;
{
    _hasAudioTrack = newValue;
    
    if (_hasAudioTrack)
    {
        if (_shouldPassthroughAudio)
        {
            audioOutputSettings = nil;
        }
        else if (audioOutputSettings == nil)
        {
            AVAudioSession *sharedAudioSession = [AVAudioSession sharedInstance];
            double preferredHardwareSampleRate;
            
            if ([sharedAudioSession respondsToSelector:@selector(sampleRate)])
            {
                preferredHardwareSampleRate = [sharedAudioSession sampleRate];
            }
            else
            {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                preferredHardwareSampleRate = [[AVAudioSession sharedInstance] currentHardwareSampleRate];
#pragma clang diagnostic pop
            }
            
            AudioChannelLayout acl;
            bzero( &acl, sizeof(acl));
            acl.mChannelLayoutTag = kAudioChannelLayoutTag_Mono;
            
            audioOutputSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                   [ NSNumber numberWithInt: kAudioFormatMPEG4AAC], AVFormatIDKey,
                                   [ NSNumber numberWithInt: 1 ], AVNumberOfChannelsKey,
                                   [ NSNumber numberWithFloat: preferredHardwareSampleRate ], AVSampleRateKey,
                                   [ NSData dataWithBytes: &acl length: sizeof( acl ) ], AVChannelLayoutKey,
                                   [ NSNumber numberWithInt: 64000 ], AVEncoderBitRateKey,
                                   nil];
        }
        
        assetWriterAudioInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:audioOutputSettings];
        [assetWriter addInput:assetWriterAudioInput];
        assetWriterAudioInput.expectsMediaDataInRealTime = _encodingLiveVideo;
    }
    else
    {
        
    }
}

- (NSArray*)metaData {
    return assetWriter.metadata;
}

- (void)setMetaData:(NSArray*)metaData {
    assetWriter.metadata = metaData;
}

- (CMTime)duration {
    if( ! CMTIME_IS_VALID(startTime) )
        return kCMTimeZero;
    if( ! CMTIME_IS_NEGATIVE_INFINITY(previousFrameTime) )
        return CMTimeSubtract(previousFrameTime, startTime);
    if( ! CMTIME_IS_NEGATIVE_INFINITY(previousAudioTime) )
        return CMTimeSubtract(previousAudioTime, startTime);
    return kCMTimeZero;
}

- (CGAffineTransform)transform {
    return assetWriterVideoInput.transform;
}

- (void)setTransform:(CGAffineTransform)transform {
    assetWriterVideoInput.transform = transform;
}

- (AVAssetWriter*)assetWriter {
    return assetWriter;
}

// transform
+ (NSUInteger)degressFromVideoFileWithURL:(NSURL *)url
{
    NSUInteger degress = 0;
    
    AVAsset *asset = [AVAsset assetWithURL:url];
    NSArray *tracks = [asset tracksWithMediaType:AVMediaTypeVideo];
    if([tracks count] > 0) {
        AVAssetTrack *videoTrack = [tracks objectAtIndex:0];
        CGAffineTransform t = videoTrack.preferredTransform;
        
        if(t.a == 0 && t.b == 1.0 && t.c == -1.0 && t.d == 0){
            // Portrait
            degress = 90;
        }else if(t.a == 0 && t.b == -1.0 && t.c == 1.0 && t.d == 0){
            // PortraitUpsideDown
            degress = 270;
        }else if(t.a == 1.0 && t.b == 0 && t.c == 0 && t.d == 1.0){
            // LandscapeRight
            degress = 0;
        }else if(t.a == -1.0 && t.b == 0 && t.c == 0 && t.d == -1.0){
            // LandscapeLeft
            degress = 180;
        }
    }
    
    return degress;
}




@end
