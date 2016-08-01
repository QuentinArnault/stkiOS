//
//  STKChatViewController.h
//  StickerFactory
//
//  Created by Vadim Degterev on 03.07.15.
//  Copyright (c) 2015 908 Inc. All rights reserved.
//
#import <UIKit/UIKit.h>

@class STKStickerController;

@interface STKChatViewController : UIViewController

@property (nonatomic, readonly) STKStickerController* stickerController;

@end
