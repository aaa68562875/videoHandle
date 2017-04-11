//
//  ViewController.m
//  ximituDemo
//
//  Created by peter on 2017/4/7.
//  Copyright © 2017年 Zerdoor. All rights reserved.
//

#import "ViewController.h"
#import <ZYQAssetPickerController.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import "VideoClipVC.h"
#import "MBProgressHUD+MJ.h"


//生成随机数
#define RandomNum (arc4random() % 9999999999999999)
@interface ViewController ()<UITableViewDelegate,UITableViewDataSource,ZYQAssetPickerControllerDelegate,UINavigationControllerDelegate>
{
    UITableView * _tableview;
    NSArray * _titileArr;
    NSArray * _className;
    NSString *selectVideoPath;
}

@property (strong, nonatomic) MPMoviePlayerViewController *moviePlayerView;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self initUserInterface];
}

- (void)initUserInterface {
    _titileArr = @[@"录制视频+滤镜（美颜）+采集处理",@"本地视频+滤镜（美颜）+采集处理"];
    _className = @[@"CameraFilterVC",@"LocalVideoEditVC"];
    
    
    _tableview = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.view.bounds), 400) style:UITableViewStylePlain];
    _tableview.showsVerticalScrollIndicator = NO;
    _tableview.showsHorizontalScrollIndicator = NO;
    _tableview.delegate = self;
    _tableview.dataSource = self;
    _tableview.rowHeight = 50.0f;
    _tableview.tableFooterView = [UIView new];
    [self.view addSubview:_tableview];
}


-(void)selectImageFromAlbum
{
    ZYQAssetPickerController *picker = [[ZYQAssetPickerController alloc] init];
    picker.maximumNumberOfSelection = 1;//只选择一个视频
    picker.assetsFilter = [ALAssetsFilter allVideos];
    picker.showEmptyGroups=NO;
    picker.delegate=self;
    picker.selectionFilter = [NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        if ([[(ALAsset*)evaluatedObject valueForProperty:ALAssetPropertyType] isEqual:ALAssetTypeVideo]) {
            NSTimeInterval duration = [[(ALAsset*)evaluatedObject valueForProperty:ALAssetPropertyDuration] doubleValue];
            return duration >= 0;
        } else {
            return YES;
        }
    }];
    
    [self presentViewController:picker animated:YES completion:NULL];
}

- (void)creatSandBoxFilePathIfNoExist
{
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    NSString *pathDocuments = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    //创建目录
    NSString *createPath = [NSString stringWithFormat:@"%@/Video", pathDocuments];
    [fileManager removeItemAtPath:createPath error:nil];
    // 判断文件夹是否存在，如果不存在，则创建
    if (![[NSFileManager defaultManager] fileExistsAtPath:createPath]) {
        [fileManager createDirectoryAtPath:createPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
}

#pragma mark - ZYQAssetPickerController Delegate
-(void)assetPickerController:(ZYQAssetPickerController *)picker didFinishPickingAssets:(NSArray *)assets{
    //    [self cleanCachesVideo];
    for (int i=0; i<assets.count; i++) {
        ALAsset * asset = assets[i];
        NSURL * url = asset.defaultRepresentation.url;
        [self creatSandBoxFilePathIfNoExist];
        
//        [MBProgressHUD hideHUD];
        [MBProgressHUD showMessage:@"正在处理"];
        //保存至沙盒路径
        NSString *pathDocuments = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
        NSString *videoPath = [NSString stringWithFormat:@"%@/Video", pathDocuments];
        selectVideoPath = [videoPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%ld.mp4",RandomNum]];
        
        /** 如果有剪切后的视频路径，删除后重新创建 */
        if ([[NSFileManager defaultManager] fileExistsAtPath:selectVideoPath]) {
            NSError *error = nil;
            [[NSFileManager defaultManager] removeItemAtURL:[NSURL fileURLWithPath:selectVideoPath] error:&error];
            NSLog(@"remove exist file %@",error);
        }
        
        //转码配置
        AVURLAsset *selectAsset = [AVURLAsset URLAssetWithURL:url options:nil];
        
        //AVAssetExportPresetMediumQuality可以更改，是枚举类型，官方有提供，更改该值可以改变视频的压缩比例
        AVAssetExportSession *exportSession= [[AVAssetExportSession alloc] initWithAsset:selectAsset presetName:AVAssetExportPresetMediumQuality];
        exportSession.shouldOptimizeForNetworkUse = YES;
        exportSession.outputURL = [NSURL fileURLWithPath:selectVideoPath];
        //AVFileTypeMPEG4 文件输出类型，可以更改，是枚举类型，官方有提供，更改该值也可以改变视频的压缩比例
        exportSession.outputFileType = AVFileTypeMPEG4;
        [exportSession exportAsynchronouslyWithCompletionHandler:^{
            int exportStatus = exportSession.status;
            NSLog(@"%d",exportStatus);
            switch (exportStatus)
            {
                case AVAssetExportSessionStatusFailed:
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [MBProgressHUD hideHUD];
                        [MBProgressHUD showError:@"请重试"];
                    });
                    // log error to text view
                    NSError *exportError = exportSession.error;
                    NSLog (@"AVAssetExportSessionStatusFailed: %@", exportError);
                    break;
                }
                case AVAssetExportSessionStatusCompleted:
                {
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [MBProgressHUD hideHUD];
                        NSLog(@"视频转码成功");
                        NSData *data = [NSData dataWithContentsOfFile:selectVideoPath];
//                        [_moviePlayerView.view removeFromSuperview];
//                        _moviePlayerView = nil;
//                        _moviePlayerView =[[MPMoviePlayerViewController alloc] initWithContentURL:[NSURL fileURLWithPath:selectVideoPath]];
//                        [_moviePlayerView.moviePlayer prepareToPlay];
//                        [self.view addSubview:_moviePlayerView.view];
//                        
//                        _moviePlayerView.moviePlayer.shouldAutoplay=YES;
//                        [_moviePlayerView.moviePlayer setControlStyle:MPMovieControlStyleDefault];
//                        [_moviePlayerView.moviePlayer setFullscreen:YES];
//                        [_moviePlayerView.view setFrame:self.view.bounds];
//                        
//                        //播放完后的通知
//                        [[NSNotificationCenter defaultCenter] addObserver:self
//                                                                 selector:@selector(movieFinishedCallback:)
//                                                                     name:MPMoviePlayerPlaybackDidFinishNotification                                                      object:nil];
//                        //离开全屏时通知，因为默认点击Done是是退出全屏，要离开播放器就有覆盖掉这个事件
//                        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(exitFullScreen:) name: MPMoviePlayerDidExitFullscreenNotification object:nil];
                        UIStoryboard *main = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
                        VideoClipVC *clip = [main instantiateViewControllerWithIdentifier:@"clipVC"];
                        clip.videoUrlPath = [NSURL fileURLWithPath:selectVideoPath];
                        [self.navigationController pushViewController:clip animated:YES];
                    });
                    
                }
            }
        }];
       
    }

}

//播放结束后离开播放器,点击上一曲、下一曲也是播放结束
-(void)movieFinishedCallback:(NSNotification*)notify {
    MPMoviePlayerController* theMovie = [notify object];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:MPMoviePlayerPlaybackDidFinishNotification
                                                  object:theMovie];
    [theMovie.view removeFromSuperview];
    UIStoryboard *main = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    VideoClipVC *clip = [main instantiateViewControllerWithIdentifier:@"clipVC"];
    clip.videoUrlPath = [NSURL fileURLWithPath:selectVideoPath];
    [self.navigationController pushViewController:clip animated:YES];
}

-(void)exitFullScreen:(NSNotification *)notification{
    [_moviePlayerView.view removeFromSuperview];
}


#pragma mark - UITableViewDelegate,UITableViewDataSource
-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _titileArr.count;
}
-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString * cellId = @"cell";
    UITableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellId];
    }
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textLabel.text = _titileArr[indexPath.row];
    return cell;
}
-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row == 0) {
        Class class = NSClassFromString(_className[indexPath.row]);
        if (class) {
            UIViewController * vc = [(UIViewController *)[class alloc] init];
            vc.title = _className[indexPath.row];
            [self.navigationController pushViewController:vc animated:YES];
        }
    }else {

        [self selectImageFromAlbum];
    }
    
}


@end
