//
//  STKStickersEntityService.m
//  StickerPipe
//
//  Created by Vadim Degterev on 27.07.15.
//  Copyright (c) 2015 908 Inc. All rights reserved.
//

#import "STKStickersEntityService.h"
#import "STKStickersCache.h"
#import "STKStickersApiService.h"
#import "STKStickersSerializer.h"
#import "STKStickerPackObject.h"
#import "STKUtility.h"
#import "STKStickersConstants.h"
#import "STKStickerPack.h"

static NSString *const kLastModifiedDateKey = @"kLastModifiedDateKey";
static NSString *const recentName = @"Recent";
static NSUInteger const firstNewStickers = 3;
static const NSTimeInterval kUpdatesDelay = 900.0; //15 min

@interface STKStickersEntityService()

@property (strong, nonatomic) STKStickersApiService *apiService;
@property (strong, nonatomic) STKStickersCache *cacheEntity;
@property (strong, nonatomic) STKStickersSerializer *serializer;
@property (strong, nonatomic) dispatch_queue_t queue;

@end

@implementation STKStickersEntityService

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.apiService = [[STKStickersApiService alloc] init];
        self.cacheEntity = [[STKStickersCache alloc] init];
        self.serializer = [[STKStickersSerializer alloc] init];
        self.queue = dispatch_queue_create("com.stickers.service", DISPATCH_QUEUE_SERIAL);
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(packDownloaded:) name:STKStickerPackDownloadedNotification object:nil];
    }
    return self;
}

- (void)packDownloaded:(NSNotification *)notification {
   
    NSDictionary *pack = notification.userInfo[@"packDict"];
    __weak typeof(self) weakSelf = self;

    [self getStickerPacksIgnoringRecentWithType:nil completion:^(NSArray *stickerPacks) {
        STKStickerPackObject *object = [weakSelf.serializer serializeStickerPack:pack];
            object.order = @(0);
        object.disabled = @(NO);
            for (int i = 0; i < stickerPacks.count; i++) {
                STKStickerPackObject *pack = stickerPacks[i];
                pack.order = @(pack.order.integerValue + 1);
            }
        NSArray *array = [stickerPacks arrayByAddingObject:object];
        weakSelf.stickersArray = array;
        [self saveStickerPacks:array];
    } failure:nil];
}

#pragma mark - Get sticker packs

- (void)loadStickerPacksFromCache:(NSString *)type
                       completion:(void (^)(NSArray *))completion {
    __weak typeof(self) weakSelf = self;
    
    [self.cacheEntity getStickerPacks:^(NSArray *stickerPacks) {
        if (stickerPacks.count == 0) {
            [self updateStickerPacksWithType:type completion:^(NSArray *stickerPacks) {
                [weakSelf loadStickersForPacks:stickerPacks completion:^(NSArray *stickerPacks) {
                    completion(stickerPacks);
                }];
                    }];
        } else {
            [weakSelf loadStickersForPacks:stickerPacks completion:^(NSArray *stickerPacks) {
                completion(stickerPacks);
            }];
           
        }
    }];
}

- (void)loadStickersForPacks:(NSArray *)packs completion:(void (^)(NSArray *))completion{
    
    __weak typeof(self) weakSelf = self;
    
    if (packs.count > 1) {
        for (int i = 1; i < packs.count; i ++) {
            STKStickerPackObject *pack = packs[i];
            if (pack.stickers.count == 0) {
                [self.apiService loadStickerPackWithName:pack.packName andPricePoint:pack.pricePoint success:^(id response) {
                    NSDictionary *serverPack = response[@"data"];
                    STKStickerPackObject *object = [weakSelf.serializer serializeStickerPack:serverPack];
                    pack.stickers = object.stickers;
                    [self.cacheEntity updateStickerPack:pack];
                } failure:^(NSError *error) {
                    
                }];
            }
            if (i == packs.count - 1) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(packs);
                });
            }
        }
    }
}

- (void)getStickerPacksWithType:(NSString *)type
                     completion:(void (^)(NSArray *))completion
                        failure:(void (^)(NSError *))failure
{
    
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.queue, ^{
        NSTimeInterval lastUpdate = [self lastUpdateDate];
        NSTimeInterval timeSinceLastUpdate = [[NSDate date] timeIntervalSince1970] - lastUpdate;
        if (timeSinceLastUpdate > kUpdatesDelay) {
            [weakSelf updateStickerPacksWithType:type completion:^(NSArray *stickerPacks) {
                [weakSelf loadStickerPacksFromCache:type completion:^(NSArray *stickerPacks) {
                    if (completion) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            completion(stickerPacks);
                        });
                    }
                }];
            }];
        } else {
            [weakSelf loadStickerPacksFromCache:type completion:completion];
        }
    });
}


-(void)getPackWithMessage:(NSString *)message completion:(void (^)(STKStickerPackObject *, BOOL))completion {
    
    NSArray *separaredStickerNames = [STKUtility trimmedPackNameAndStickerNameWithMessage:message];
    NSString *packName = [[separaredStickerNames firstObject] lowercaseString];
    
    STKStickerPackObject *stickerPackObject =  [self.cacheEntity getStickerPackWithPackName:packName];
    if (!stickerPackObject) {
        
        __weak typeof(self) weakSelf = self;
        
        [self.apiService getStickerPackWithName:packName success:^(id response) {
            
            NSDictionary *serverPack = response[@"data"];
            STKStickerPackObject *object = [weakSelf.serializer serializeStickerPack:serverPack];
            //TODO:Refactoring
            if (![self isPackDownloaded:object.packName]) {
                [weakSelf.cacheEntity saveDisabledStickerPack:object];
                object.disabled = @YES;
            }
            
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(object, NO);
                });
            }
        } failure:^(NSError *error) {
            
        }];
    } else {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(stickerPackObject, YES);
            });
        }
    }
    
}

- (void)getStickerPacksIgnoringRecentWithType:(NSString *)type completion:(void (^)(NSArray *))completion failure:(void (^)(NSError *))failre {
    
    [self.cacheEntity getStickerPacksIgnoringRecent:^(NSArray *stickerPacks) {
        if (completion) {
            completion(stickerPacks);
        }
    }];
    
}

- (STKStickerPackObject *)getStickerPackWithName:(NSString *)packName {
    return [self.cacheEntity getStickerPackWithPackName:packName];
}

#pragma mark - Update sticker packs

- (void)updateStickerPacksWithType:(NSString*)type completion:(void(^)(NSArray *stickerPacks))completion {
    
    __weak typeof(self) weakSelf = self;
    
    [self.apiService getStickersPacksForUserWithSuccess:^(id response,
                                                          NSTimeInterval lastModifiedDate) {
        
        NSArray* serializedObjects = [weakSelf.serializer serializeStickerPacks:response[@"data"]];
        // if (lastModifiedDate != [weakSelf lastModifiedDate]) {
        [weakSelf.cacheEntity saveStickerPacks:serializedObjects];
        if (lastModifiedDate > [weakSelf lastModifiedDate]) {
            self.hasNewModifiedPacks = YES;
            [weakSelf setLastModifiedDate:lastModifiedDate];
        }
        else  {
            self.hasNewModifiedPacks = NO;
        }

        STKStickerPackObject *recentPack = weakSelf.cacheEntity.recentStickerPack;
        NSArray *packsWithRecent = nil;
        if (recentPack) {
            NSArray *recentPackArray = @[recentPack];
            packsWithRecent = [recentPackArray arrayByAddingObjectsFromArray:serializedObjects];
        } else {
            packsWithRecent = serializedObjects;
        }
        [weakSelf setLastUpdateDate:[[NSDate date] timeIntervalSince1970]];
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(packsWithRecent);
            });
        }
        
    } failure:^(NSError *error) {
        if (completion) {
            //TODO:REfactoring
            completion(nil);
        }
    }];
}

#pragma mark ----------

- (void)saveStickerPacks:(NSArray *)stickerPacks {
    [self.cacheEntity saveStickerPacks:stickerPacks];
}

- (void)updateStickerPackInCache:(STKStickerPackObject *)stickerPackObject {
    [self.cacheEntity updateStickerPack:stickerPackObject];
}

- (void)incrementStickerUsedCountWithID:(NSNumber *)stickerID {
    [self.cacheEntity incrementUsedCountWithStickerID:stickerID];
}


- (void)togglePackDisabling:(STKStickerPackObject *)pack {
    BOOL status = pack.disabled.boolValue;
    pack.disabled = @(!status);
    
    [self.cacheEntity markStickerPack:pack disabled:!status];
}

- (BOOL)hasRecentStickers {
    STKStickerPackObject *recentStickerPack = [self.cacheEntity recentStickerPack];
    
    return [recentStickerPack.stickers count] > 0;
}

- (BOOL)hasNewPacks {
    NSArray *arr = self.stickersArray;
    NSUInteger newsCount = 0;
    NSUInteger size = (arr.count < firstNewStickers + 1) ? arr.count : firstNewStickers +1;
    for (int i = 0; i < size; i++) {
        STKStickerPackObject *stickerPack = arr[i];
        if (stickerPack.isNew.boolValue) {
            newsCount ++;
        }
    }
    return ![self hasRecentStickers] || newsCount > 0;
}

#pragma mark Check save delete

- (BOOL)isPackDownloaded:(NSString*)packName {
    
    return [self.cacheEntity isStickerPackDownloaded:packName];
}

- (void)saveStickerPack:(STKStickerPackObject *)stickerPack {
    [self.cacheEntity saveStickerPacks:@[stickerPack]];
}
- (void)deleteStickerPack:(STKStickerPackObject *)stickerPack {
    [self.cacheEntity deleteStickerPacks:@[stickerPack]];
}

#pragma mark - LastUpdateTime

- (NSTimeInterval)lastUpdateDate {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSTimeInterval lastUpdateDate = [defaults doubleForKey:kLastUpdateIntervalKey];
    return lastUpdateDate;
}

- (void)setLastUpdateDate:(NSTimeInterval) lastUpdateInterval {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setDouble:lastUpdateInterval forKey:kLastUpdateIntervalKey];
}

#pragma mark - LastModifiedDate

- (NSTimeInterval)lastModifiedDate {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSTimeInterval timeInterval = [defaults doubleForKey:kLastModifiedDateKey];
    return timeInterval;
}

- (void)setLastModifiedDate:(NSTimeInterval)lastModifiedDate {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setDouble:lastModifiedDate forKey:kLastModifiedDateKey];
}

#pragma mark -----

- (NSInteger)indexOfPackWithName:(NSString *)packName {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", STKStickerPackAttributes.packName, packName];
    STKStickerPackObject *stickerPack  = [[self.stickersArray filteredArrayUsingPredicate:predicate] firstObject];
    
    NSUInteger stickerIndex = [self.stickersArray indexOfObject:stickerPack];

    return stickerIndex;
}




@end
