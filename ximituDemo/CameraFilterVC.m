//
//  CameraFilterVC.m
//  ximituDemo
//
//  Created by peter on 2017/4/7.
//  Copyright © 2017年 Zerdoor. All rights reserved.
//

#import "CameraFilterVC.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <GPUImage.h>
#import "GPUImageBeautifyFilter.h"
#import "MBProgressHUD+MJ.h"
#import "VideoClipVC.h"
#import "FilterChooseView.h"

#define FilterViewHeight 95

@interface CameraFilterVC ()<UIAlertViewDelegate>
{
    NSString *pathToMovie;
    NSInteger time;
    
}

@property (nonatomic,retain) UIButton *movieButton;

@property (nonatomic,retain) GPUImageVideoCamera *camera;
@property (nonatomic,strong) GPUImageView * filterView;
@property (nonatomic,retain) GPUImageMovieWriter *writer;
@property (nonatomic,retain) GPUImageOutput<GPUImageInput> *filter;

@property (assign, nonatomic) NSInteger count;
@property (strong, nonatomic) NSTimer *timer;

@end

@implementation CameraFilterVC

- (void)viewDidLoad {
    [super viewDidLoad];
    [self initUserInterface];
}

- (void)initUserInterface {
    self.view.backgroundColor = [UIColor blackColor];
    
    _filterView = [[GPUImageView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:_filterView];
    
    self.camera = [[GPUImageVideoCamera alloc] initWithSessionPreset:AVCaptureSessionPreset1280x720 cameraPosition:AVCaptureDevicePositionFront];
    self.camera.audioEncodingTarget = self.writer;
    
    self.camera.outputImageOrientation = UIInterfaceOrientationPortrait;
    [_camera addAudioInputsAndOutputs];
    self.camera.horizontallyMirrorFrontFacingCamera = NO;
    self.camera.horizontallyMirrorRearFacingCamera = NO;
    GPUImageOutput<GPUImageInput> * beautifyFilter = [[GPUImageBeautifyFilter alloc] init];
    self.filter = beautifyFilter;
    [self.camera removeAllTargets];
    [self.camera addTarget:beautifyFilter];
    [self.filter addTarget:self.filterView];
    if (self.filter) {
        [self.camera addTarget:_filter];
        [_filter addTarget:_filterView];
    }else{
        [self.camera addTarget:_filterView];
    }
    [self.camera startCameraCapture];
    
    self.count = 5;
    
    FilterChooseView * chooseView = [[FilterChooseView alloc] initWithFrame:CGRectMake(0, self.view.frame.size.height-FilterViewHeight-60, self.view.frame.size.width, FilterViewHeight)];
    chooseView.backback = ^(GPUImageOutput<GPUImageInput> * filter){
        [self choose_callBack:filter];
    };
    [self.view addSubview:chooseView];
    
    self.movieButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.movieButton setFrame:CGRectMake(0, 0, self.view.frame.size.width/3, 40)];
    self.movieButton.center = CGPointMake(self.view.frame.size.width/2, self.view.frame.size.height-30);
    self.movieButton.layer.borderWidth  = 2;
    self.movieButton.layer.borderColor = [UIColor whiteColor].CGColor;
    [self.movieButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.movieButton setTitle:@"start" forState:UIControlStateNormal];
    [self.movieButton setTitle:@"stop" forState:UIControlStateSelected];
    [self.movieButton addTarget:self action:@selector(start_stop) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.movieButton];
    
    UIButton *deviceBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    deviceBtn.frame = CGRectMake(0, 64, 50, 30);
    [deviceBtn setTitle:@"切换" forState:0];
    [deviceBtn setBackgroundColor:[UIColor cyanColor]];
    [deviceBtn addTarget:self action:@selector(changeCount) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:deviceBtn];
}

#pragma mark 选择滤镜
-(void)choose_callBack:(GPUImageOutput<GPUImageInput> *)filter
{
    BOOL isSelected = self.movieButton.isSelected;
    if (isSelected) {
        return;
    }
    self.filter = filter;
    [self.camera removeAllTargets];
    [self.camera addTarget:_filter];
    [_filter addTarget:_filterView];
}

#pragma mark - action
/**
 切换摄像头
 */
- (void)changeCount {
    [self.camera rotateCamera];
}


- (void)start_stop
{
    
    BOOL isSelected = self.movieButton.isSelected;
    [self.movieButton setSelected:!isSelected];
    if (isSelected) {//结束录制
        [self.filter removeTarget:self.writer];
        self.camera.audioEncodingTarget = nil;
        [self.writer finishRecording];
        
        NSLog(@"path:%@",pathToMovie);
        UIStoryboard *main = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
        VideoClipVC *clip = [main instantiateViewControllerWithIdentifier:@"clipVC"];
        clip.videoUrlPath = [NSURL fileURLWithPath:pathToMovie];
        [self.navigationController pushViewController:clip animated:YES];
        
    }else{//开始录制
        /** 生成计时器，控制录制时长 */
//        self.timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(timeCount) userInfo:nil repeats:YES];
        
        NSString *fileName = [@"Documents/" stringByAppendingFormat:@"Movie%d.m4v",(int)[[NSDate date] timeIntervalSince1970]];
        pathToMovie = [NSHomeDirectory() stringByAppendingPathComponent:fileName];
        
        NSURL *movieURL = [NSURL fileURLWithPath:pathToMovie];
        /** 录制完成生成路径 */
        self.writer = [[GPUImageMovieWriter alloc] initWithMovieURL:movieURL size:CGSizeMake(480.0, 640.0)];
        [self.filter addTarget:self.writer];
        self.camera.audioEncodingTarget = self.writer;
        [self.writer startRecording];
    }
}

- (void)timeCount {
    time++;
    NSLog(@"%ld",(long)time);
    if (time >= self.count) {//已经到规定的录制时长，结束录制
        [self.timer invalidate];
        self.timer = nil;
        self.movieButton.selected = NO;

        [self.filter removeTarget:self.writer];
        self.camera.audioEncodingTarget = nil;
        [self.writer cancelRecording];

    }
}

#pragma mark - UIAlertViewDelegate
-(void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 1) {
        NSLog(@"baocun");
        [self save_to_photosAlbum:pathToMovie];
    }
}

-(void)save_to_photosAlbum:(NSString *)path
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(path)) {
            
            UISaveVideoAtPathToSavedPhotosAlbum(path, self, @selector(video:didFinishSavingWithError:contextInfo:), nil);
        }
    });
}
// 视频保存回调
- (void)video:(NSString *)videoPath didFinishSavingWithError:(NSError *)error contextInfo: (void *)contextInfo {
    if (error) {
        NSLog(@"保存视频过程中发生错误，错误信息:%@",error.localizedDescription);
    }else{
        NSLog(@"视频保存成功.");
    }
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    
}


@end
