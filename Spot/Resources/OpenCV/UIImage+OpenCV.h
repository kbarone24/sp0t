//
//  UIImage+OpenCV.h
//  Spot
//
//  Created by Kenny Barone on 3/1/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <opencv2/opencv.hpp>

NS_ASSUME_NONNULL_BEGIN

@interface UIImage (UIImage_OpenCV)

+(UIImage *)imageWithCVMat:(const cv::Mat&)cvMat;
-(id)initWithCVMat:(const cv::Mat&)cvMat;

@property(nonatomic, readonly) cv::Mat CVMat;
@property(nonatomic, readonly) cv::Mat CVGrayscaleMat;

@end

NS_ASSUME_NONNULL_END
