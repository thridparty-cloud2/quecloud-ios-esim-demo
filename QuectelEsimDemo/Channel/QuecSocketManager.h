//
//  QuecSocketManager.h
//  QuectelEsimDemo
//
//  Created by quectel.tank on 1/27/26.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol QuecSocketDelegate <NSObject>

@optional
- (void)quecSocket:(NSString *)socketId didConnectToHost:(NSString *)host port:(uint16_t)port;
- (void)quecSocket:(NSString *)socketId didDisconnectwithError:(nullable NSError *)err;
- (void)quecSocket:(NSString *)socketId didReadData:(NSData *)data;

@end

@interface QuecSocketManager : NSObject

+ (instancetype)sharedInstance;

// 最大连接数量
@property (nonatomic, assign) int maxConnections;
// 指令回复超时时间
@property (nonatomic, assign) NSInteger commandResponseTimeout;

- (void)addDelegate:(id<QuecSocketDelegate>)delegate;

- (void)removeDelegate:(id<QuecSocketDelegate>)delegate;

- (NSString *)connectToHost:(NSString *)host onPort:(uint16_t)port socketId:(NSString *)socketId;

- (void)sendDataBySocketId:(NSString *)socketId data:(NSData *)data completion:(nullable void(^)(BOOL timeout, NSData *response))completion;

- (void)disConnectSocketWithSocketId:(NSString *)socketId;

- (void)disConnectAllSockets;

- (BOOL)isConnectedWithSocketId:(NSString *)socketId;

@end

NS_ASSUME_NONNULL_END
