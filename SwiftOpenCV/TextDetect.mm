//
//  TextDectect.mm
//  Recognize text
//
//  Created by Lee Whitney on 10/28/14.
//  Copyright (c) 2014 WhitneyLand. All rights reserved.
//

#import  "TextDetect.h"
#include  "opencv2/text.hpp"
#include  "opencv2/highgui.hpp"
#include  "opencv2/imgproc.hpp"
#include  <vector>
#include  <iostream>
#include  <iomanip>
#import "ImageWrapper.h"

using namespace std;
using namespace cv;
using namespace cv::text;

@implementation CImage

NSMutableArray *_channels;
Mat _image;
Mat _grouping;

vector<Mat> _vchannels;

-(id)initWithImage:(UIImage *)img {
    self = [super init];
    if(self){
        _channels = [[NSMutableArray alloc] init];
        
        NSData *data = [NSData dataWithData:UIImageJPEGRepresentation(img, 0.8f)];
        
        NSString *temp = NSTemporaryDirectory();
        NSString *guid = [[NSUUID new] UUIDString];
        NSString *fileName = [NSString stringWithFormat:@"%@.jpg",guid];
        NSString *localFilePath = [temp stringByAppendingPathComponent:fileName];
        [data writeToFile:localFilePath atomically:YES];
        
        
        _image = imread(localFilePath.UTF8String);
        
        Mat grey;
        cvtColor(_image,grey,COLOR_RGB2GRAY);
        _vchannels.clear();
        _vchannels.push_back(grey);
        _vchannels.push_back(255 - grey);
        
        for (int i = 0; i < 2; i++) {
            UIImage *img = MatToUIImage(_vchannels[i]);
            [_channels addObject:img];
        }
    }
    
    return self;
}

-(Mat)getImage {
    return _image;
}

-(vector<Mat>)getCVChannels {
    return _vchannels;
}

-(NSMutableArray *)channels {
    return _channels;
}

void UIImageToMat(const UIImage* image, cv::Mat& m,
                  bool alphaExist)
{
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(image.
                                                      CGImage);
    CGFloat cols = image.size.width, rows = image.size.height;
    CGContextRef contextRef;
    CGBitmapInfo bitmapInfo = kCGImageAlphaPremultipliedLast;
    if (CGColorSpaceGetModel(colorSpace) == 0)
    {
        m.create(rows, cols, CV_8UC1);
        //8 bits per component, 1 channel
        bitmapInfo = kCGImageAlphaNone;
        if (!alphaExist)
            bitmapInfo = kCGImageAlphaNone;
        contextRef = CGBitmapContextCreate(m.data, m.cols, m.rows,
                                           8,
                                           m.step[0], colorSpace,
                                           bitmapInfo);
    }
    else
    {
        m.create(rows, cols, CV_8UC4); // 8 bits per component, 4
        if (!alphaExist)
            bitmapInfo = kCGImageAlphaNoneSkipLast |
            kCGBitmapByteOrderDefault;
        contextRef = CGBitmapContextCreate(m.data, m.cols, m.rows,
                                           8,
                                           m.step[0], colorSpace,
                                           bitmapInfo);
    }
    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows),
                       image.CGImage);
    CGContextRelease(contextRef);
}


UIImage* MatToUIImage(const cv::Mat& image)
{
    NSData *data = [NSData dataWithBytes:image.data length:image.
                    elemSize()*image.total()];
    
    CGColorSpaceRef colorSpace;
    
    if (image.elemSize() == 1) {
        colorSpace = CGColorSpaceCreateDeviceGray();
    } else {
        colorSpace = CGColorSpaceCreateDeviceRGB();
    }
    
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    
    // Creating CGImage from cv::Mat
    CGImageRef imageRef = CGImageCreate(image.cols,   //width
                                        
                                        image.rows,   //height
                                        8,            //bits percomponent
                                        8*image.elemSize(),//bits
                                        
                                        image.step.p[0],   //
                                        
                                        colorSpace,   //colorspace
                                        kCGImageAlphaNone|kCGBitmapByteOrderDefault,//
                                        provider,     //
                                        //CGDataProviderRef
                                        NULL,         //decode
                                        false,        //should
                                        //interpolate
                                        kCGRenderingIntentDefault
                                        //intent
                                        );
    
    // Getting UIImage from CGImage
    UIImage *finalImage = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    
    return finalImage;
}


-(UIImage*)getImage:(UIImage*)resizedImage {
    ImageWrapper *greyScale= Image::createImage(resizedImage, resizedImage.size.width, resizedImage.size.height);
    ImageWrapper *edges = greyScale.image->autoLocalThreshold();
    return edges.image->toUIImage();
}

@end

@implementation ExtremeRegionStat

vector<ERStat> _region;

-(id)initWithRegion: (vector<ERStat>)region {
    self = [super init];
    if(self) {
        _region = region;
    }
    return self;
}

-(vector<ERStat>)getRegion {
    return _region;
}

+(UIImage*)groupImage : (CImage*)image WithRegions: (NSArray *)regions{
    
    vector<vector<ERStat>> _regions;
    
    for(int i = 0; i< regions.count; i++){
        ExtremeRegionStat *stat = [regions objectAtIndex:i];
        _regions.push_back([stat getRegion]);
    }
    vector< vector<Vec2i> > nm_region_groups;
    vector<cv::Rect> nm_boxes;
    
    Mat cvImg = [image getImage];
    
    erGrouping(cvImg, [image getCVChannels] , _regions, nm_region_groups, nm_boxes,ERGROUPING_ORIENTATION_HORIZ);
    
    groups_draw(cvImg, nm_boxes);
    
    return MatToUIImage(cvImg);
}

void groups_draw(Mat &src, vector<cv::Rect> &groups)
{
    for (int i=(int)groups.size()-1; i>=0; i--)
    {
        if (src.type() == CV_8UC3)
            rectangle(src,groups.at(i).tl(),groups.at(i).br(),Scalar( 0, 255, 255 ), 3, 8 );
        else
            rectangle(src,groups.at(i).tl(),groups.at(i).br(),Scalar( 255 ), 3, 8 );
    }
}

@end

@interface ExtremeRegionFilter ()

@property (nonatomic) Ptr<ERFilter> filter;

@end

@implementation ExtremeRegionFilter

-(id) init {
    self = [super init];
    if(self){
        
    }
    return self;
}

-(ExtremeRegionStat*)run : (UIImage*)img{
    vector<ERStat> region;
   
    Mat cMat;
    UIImageToMat(img, cMat, false);
    
    _filter->run(cMat, region);
    ExtremeRegionStat * stat = [[ExtremeRegionStat alloc] initWithRegion:region];
    return stat;
}

+ (ExtremeRegionFilter *)createERFilterNM1:(NSString *)classifierPath c:(float)c x:(float)x y:(float)y f:(float)f a:(bool)a scale:(float)scale {
    
    const char *classifier1utf = classifierPath.UTF8String;
    
    Ptr<ERFilter> filter = createERFilterNM1(loadClassifierNM1(classifier1utf),c, x , y, f, a, scale);
    
    ExtremeRegionFilter *erFilter = [[ExtremeRegionFilter alloc] init];
    [erFilter setFilter:filter];
    
    return erFilter;
}

+ (ExtremeRegionFilter *)createERFilterNM2:(NSString *)classifier andX:(float)x {
    
    const char *classifier2utf = classifier.UTF8String;
    
    Ptr<ERFilter> filter = createERFilterNM2(loadClassifierNM1(classifier2utf),x);
    
    ExtremeRegionFilter *erFilter = [[ExtremeRegionFilter alloc] init];
    [erFilter setFilter:filter];
    
    return erFilter;
}

@end


