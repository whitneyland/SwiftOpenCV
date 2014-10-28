//
//  TextDectect.h
//  Recognize text
//
//  Created by Lee Whitney on 10/28/14.
//  Copyright (c) 2014 WhitneyLand. All rights reserved.
//

#ifndef __SwiftOCR__TextDetectionUtil__
#define __SwiftOCR__TextDetectionUtil__

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>


@interface CImage : NSObject

-(id)initWithImage: (UIImage*)img;

@property (strong, nonatomic) NSMutableArray *channels;

@end

@interface ExtremeRegionStat: NSObject

+(UIImage*)groupImage : (CImage*)image WithRegions: (NSArray *)regions;

@end

@interface ExtremeRegionFilter : NSObject

+(ExtremeRegionFilter*)createERFilterNM1: (NSString *)classifierPath c:(float) c x:(float) x y: (float) y f:(float) f a:(bool) a scale:(float) scale;
+(ExtremeRegionFilter*)createERFilterNM2: (NSString *)classifier andX: (float)x;

-(ExtremeRegionStat*)run : (UIImage*)img;

@end

@interface ExtremeRegionGroup: NSObject

-(void) group;

@end

#endif /* defined(__SwiftOCR__TextDetectionUtil__) */
