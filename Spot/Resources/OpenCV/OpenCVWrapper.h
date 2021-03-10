//
//  OpenCVWrapper.h
//  Spot
//
//  Created by Kenny Barone on 3/1/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "OpenCVWrapper.h"

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface OpenCVWrapper : NSObject

+ (NSURL *)processVideoFileWithOpenCV:(NSURL*)url : (NSURL*)result;

@end

NS_ASSUME_NONNULL_END
