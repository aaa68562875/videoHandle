//
//  VideoClipVC.m
//  ximituDemo
//
//  Created by peter on 2017/4/7.
//  Copyright © 2017年 Zerdoor. All rights reserved.
//

#import "VideoClipVC.h"
#import "JLDoubleSlider.h"
#import <MediaPlayer/MediaPlayer.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import "MBProgressHUD+MJ.h"
#import <AFNetworking.h>
#import "XjAVPlayerSDK.h"

@interface VideoClipVC ()<XjAVPlayerSDKDelegate>
{
    JLDoubleSlider *_slider;
    XjAVPlayerSDK *myPlayer;
}
@property (weak, nonatomic) IBOutlet UIImageView *startImage;
@property (weak, nonatomic) IBOutlet UIImageView *endImage;
@property (weak, nonatomic) IBOutlet UIButton *saveBtn;

@end

@implementation VideoClipVC

- (void)viewDidLoad {
    [super viewDidLoad];
    [self initUserInterface];
}

/** 视频总时长 */
- (CGFloat)_videoSecondes:(AVAsset*)asset {
    return asset.duration.value*1.0f/asset.duration.timescale;
}

/**
 根据时间获取对应帧的图片
 
 @param videoURL 视频沙盒路径
 @param time 时间
 */
- (UIImage*) thumbnailImageForVideo:(NSURL *)videoURL atTime:(NSTimeInterval)time {
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:videoURL options:nil];
    NSParameterAssert(asset);
    AVAssetImageGenerator *assetImageGenerator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
    assetImageGenerator.appliesPreferredTrackTransform = YES;
    assetImageGenerator.apertureMode = AVAssetImageGeneratorApertureModeEncodedPixels;

    CGImageRef thumbnailImageRef = NULL;
    CFTimeInterval thumbnailImageTime = time * asset.duration.timescale;
//    CFTimeInterval thumbnailImageTime = time;
    NSError *thumbnailImageGenerationError = nil;
    thumbnailImageRef = [assetImageGenerator copyCGImageAtTime:CMTimeMake(thumbnailImageTime, asset.duration.timescale) actualTime:NULL error:&thumbnailImageGenerationError];
    
    if (!thumbnailImageRef)
        NSLog(@"thumbnailImageGenerationError %@", thumbnailImageGenerationError);
    
    UIImage *thumbnailImage = thumbnailImageRef ? [[UIImage alloc] initWithCGImage:thumbnailImageRef] : nil;
        
    return thumbnailImage;
}


/** 采集后的视频路径 */
- (NSURL*)clipUrl {
    NSArray *docPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask, YES);
    NSString *documentsPath = [docPath objectAtIndex:0];
    return [NSURL fileURLWithPath:[documentsPath stringByAppendingPathComponent:@"clip.mp4"]];
}

- (void)save {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" message:@"是否保存到系统相册?" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            if (UIVideoAtPathIsCompatibleWithSavedPhotosAlbum([self clipUrl].path)) {
                
                UISaveVideoAtPathToSavedPhotosAlbum([self clipUrl].path, self, @selector(video:didFinishSavingWithError:contextInfo:), nil);
            }
        });
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

// 视频保存回调
- (void)video:(NSString *)videoPath didFinishSavingWithError:(NSError *)error contextInfo: (void *)contextInfo {
    if (error) {
        NSLog(@"保存视频过程中发生错误，错误信息:%@",error.localizedDescription);
    }else{
        [MBProgressHUD showSuccess:@"保存成功"];
        NSLog(@"视频保存成功.");
    }
}

/** 视频采集 */
- (void)clipWithUrl:(NSString *)clipPath{
    
    /** 如果有剪切后的视频路径，删除后重新创建 */
    if ([[NSFileManager defaultManager] fileExistsAtPath:[[self clipUrl] path]]) {
        NSError *error = nil;
        [[NSFileManager defaultManager] removeItemAtURL:[self clipUrl] error:&error];
        NSLog(@"remove exist file %@",error);
    }
    
    AVMutableComposition *mainComposition = [[AVMutableComposition alloc] init];
    /** 这里视频和声音都要做采集处理 */
    AVMutableCompositionTrack *compositionVideoTrack = [mainComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    AVMutableCompositionTrack *soundtrackTrack = [mainComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    
    CMTime duration = kCMTimeZero;
    AVAsset *asset = [AVAsset assetWithURL:[NSURL fileURLWithPath:clipPath]];
    
    /** 采集的范围，从开始位置开始，采集结束位置减去开始的时长，因为这个是代表从某个位置开始采集，然后采集多少时长 */
    CMTimeRange rangeTime = CMTimeRangeMake(CMTimeMakeWithSeconds( _slider.currentMinValue, asset.duration.timescale), CMTimeMakeWithSeconds( _slider.currentMaxValue - _slider.currentMinValue, asset.duration.timescale));
    
    /** 视频采集，音频采集范围应一致 */
    [compositionVideoTrack insertTimeRange:rangeTime ofTrack:[asset tracksWithMediaType:AVMediaTypeVideo].firstObject atTime:duration error:nil];
    /** 声音采集，音频采集范围应一致 */
    [soundtrackTrack insertTimeRange:rangeTime ofTrack:[asset tracksWithMediaType:AVMediaTypeAudio].firstObject atTime:duration error:nil];
    
    /** 视频导出类 */
    AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:mainComposition presetName:AVAssetExportPreset1280x720];
    /** 采集后的视频返回的路径 */
    exporter.outputURL = [self clipUrl];
    exporter.outputFileType = AVFileTypeMPEG4;
    exporter.shouldOptimizeForNetworkUse = YES;
    __weak typeof(self) weakSelf = self;
    [exporter exportAsynchronouslyWithCompletionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            switch (exporter.status) {
                case AVAssetExportSessionStatusWaiting:
                    break;
                case AVAssetExportSessionStatusExporting:
                    break;
                case AVAssetExportSessionStatusCompleted:
                    NSLog(@"exporting completed");
                    // 想做什么事情在这个做
                    [weakSelf save];
                    break;
                case AVAssetExportSessionStatusFailed:
                    NSLog(@"error:%@",exporter.error);
                    [MBProgressHUD showError:@"请重试"];
                    break;
                case AVAssetExportSessionStatusUnknown:
                    NSLog(@"Unknown");
                    break;
                default:
                    
                    NSLog(@"exporting failed %@",[exporter error]);
                    break;
            }
            
        });
        
    }];
}

- (void)initUserInterface {
    
    myPlayer = [[XjAVPlayerSDK alloc] initWithFrame:CGRectMake(0, 64, self.view.frame.size.width, self.view.frame.size.width/2 + 40)];
    myPlayer.xjPlayerUrl = self.videoUrlPath.path;
    myPlayer.xjPlayerTitle = @"播放";
    myPlayer.xjAutoOrient = NO;
    myPlayer.XjAVPlayerSDKDelegate = self;
    myPlayer.xjLastTime = 0;
    
    [self.view addSubview:myPlayer];
    
    
    AVAsset *asset = [AVAsset assetWithURL:[NSURL fileURLWithPath:[self.videoUrlPath path]]];
    /** 视频总时长 */
    float videoSecondes = [self _videoSecondes:asset];
    _slider = [[JLDoubleSlider alloc]initWithFrame:CGRectMake(30, CGRectGetMaxY(self.startImage.frame) + 40, CGRectGetWidth(self.view.frame) - 60, 40)];
    _slider.minNum = 0;
    _slider.maxNum = videoSecondes;
    _slider.minTintColor = [UIColor whiteColor];
    _slider.maxTintColor = [UIColor whiteColor];
    _slider.mainTintColor = [UIColor blueColor];
    
    self.startImage.image = [self thumbnailImageForVideo:self.videoUrlPath atTime:0];
    self.endImage.image = [self thumbnailImageForVideo:self.videoUrlPath atTime:videoSecondes];
    __weak typeof(self) weakSelf = self;
    [_slider handlerRowWithBlock:^(CGFloat min, CGFloat max) {
        
        myPlayer.xjLastTime = min;
//        weakSelf.startImage.image = [weakSelf thumbnailImageForVideo:weakSelf.videoUrlPath atTime:min];
//        weakSelf.endImage.image = [weakSelf thumbnailImageForVideo:weakSelf.videoUrlPath atTime:max];
    }];
    [self.view addSubview:_slider];
    
    
}

/** 视频上传 */
- (void)uploadVideoWithPath:(NSString *)videoPath {
    AFHTTPRequestSerializer *ser = [[AFHTTPRequestSerializer alloc] init];
    NSError *error = nil;
    NSMutableURLRequest *request = [ser multipartFormRequestWithMethod:@"POST" URLString:@"" parameters:@{} constructingBodyWithBlock:^(id<AFMultipartFormData>  _Nonnull formData) {
        [formData appendPartWithFileURL:[self clipUrl] name:@"video" fileName:@"video.mp4" mimeType:@"video/mp4" error:nil];
    } error:&error];
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.responseSerializer = [AFHTTPResponseSerializer serializer];
    [manager uploadTaskWithStreamedRequest:request progress:^(NSProgress * _Nonnull uploadProgress) {
        NSLog(@"进度:%.2f@",uploadProgress.fractionCompleted);
    } completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
        
    }];
}


- (IBAction)saveAction:(UIButton *)sender {
    [self clipWithUrl:[self.videoUrlPath path]];
    
}

- (void)loadImageFinished:(UIImage *)image
{
    UIImageWriteToSavedPhotosAlbum(image, self, @selector(image:didFinishSavingWithError:contextInfo:), (__bridge void *)self);
}

- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo
{
    
    NSLog(@"image = %@, error = %@, contextInfo = %@", image, error, contextInfo);
}


#pragma mark - XjAVPlayerSDKDelegate
- (void)xjGoBack{
    //    [myPlayer xjStopPlayer];
    //    [self dismissViewControllerAnimated:YES completion:nil];
}




- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
