GPUImageInput
---
GPUImageInput 是GPUImage中的一个重要的协议，实现这个协议的类表示这个类能接受帧缓存的输入，在响应链中每一个中间节点都能够接受输入经过它的处理之后又能输出给下一个节点。正式这样的过程构成了一个响应链条，这也是叠加滤镜、组合滤镜的基础。

kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange = '420v'，表示输出的视频格式为NV12；范围： (luma=[16,235] chroma=[16,240])
kCVPixelFormatType_420YpCbCr8BiPlanarFullRange = '420f'，表示输出的视频格式为NV12；范围： (luma=[0,255] chroma=[1,255])
kCVPixelFormatType_32BGRA = 'BGRA', 输出的是BGRA的格式


定义    扩展名
AVFileTypeQuickTimeMovie    .mov 或 .qt
AVFileTypeMPEG4    .mp4
AVFileTypeAppleM4V    .m4v
AVFileTypeAppleM4A    .m4a
AVFileType3GPP    .3gp 或 .3gpp 或 .sdv
AVFileType3GPP2    .3g2 或 .3gp2
AVFileTypeCoreAudioFormat    .caf
AVFileTypeWAVE    .wav 或 .wave 或 .bwf
AVFileTypeAIFF    .aif 或 .aiff
AVFileTypeAIFC    .aifc 或 .cdda
AVFileTypeAMR    .amr
AVFileTypeWAVE    .wav 或 .wave 或 .bwf
AVFileTypeMPEGLayer3    .mp3
AVFileTypeSunAU    .au 或 .snd
AVFileTypeAC3    .ac3
AVFileTypeEnhancedAC3    .eac3
