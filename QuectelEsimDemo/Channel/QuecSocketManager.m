//
//  QuecSocketManager.m
//  QuectelEsimDemo
//
//  Created by quectel.tank on 1/27/26.
//

#import "QuecSocketManager.h"
#import "QuecSocket.h"
#import <QuecFoundationKit/QuecFoundationKit.h>

static NSInteger const QuecSocketTimeout          = 60;

@interface QuecSocketManager () <GCDAsyncSocketDelegate> {
    dispatch_source_t _timer;
}
@property (nonatomic, strong) NSMutableArray *delegateArray;
@property (nonatomic, strong) NSLock *delegateArrayLock;
@property (nonatomic, strong) NSMutableDictionary *socketDictionary;
@property (nonatomic, strong) NSMutableDictionary *callBackDictionary;

@end

static id _instance = nil;
@implementation QuecSocketManager

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (!_instance) {
            _instance = [[self alloc] init];
        }
    });
    return _instance;
}

+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [super allocWithZone:zone];
    });
    return _instance;
}

- (id)copyWithZone:(NSZone *)zone {
    return _instance;
}

- (id)mutableCopyWithZone:(NSZone *)zone {
    return _instance;
}

- (instancetype)init {
    if (self = [super init]) {
        _delegateArray = @[].mutableCopy;
        _delegateArrayLock = [[NSLock alloc] init];
        _socketDictionary = @{}.mutableCopy;
        _commandResponseTimeout = 30;
        _callBackDictionary = @{}.mutableCopy;
    }
    return self;
}

- (void)startTimer {
    __weak typeof(self) weakSelf = self;
    if (!_timer) {
        _timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
        dispatch_source_set_timer(_timer, dispatch_walltime(NULL,0), 10 * NSEC_PER_SEC, 0);
        dispatch_source_set_event_handler(_timer, ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            [strongSelf sendHeart];
        });
        dispatch_resume(_timer);
    }
}

- (void)pauseTimer {
    if (_timer) {
        dispatch_suspend(_timer);
    }
}

- (void)cancleTimer {
    if (_timer) {
        dispatch_cancel(_timer);
    }
    _timer = nil;
}

- (QuecSocket *)getSocketWithHost:(NSString *)host port:(uint16_t)port {
    QuecSocket *socket = [[QuecSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    socket.socketId = [NSString stringWithFormat:@"%@:%hu", host, port];
    return socket;
}

- (void)sendHeart {
    NSArray *socketIds = [_socketDictionary allKeys];
    for (int i = 0; i < socketIds.count; i ++) {
        [self sendDataBySocketId:socketIds[i] data:NSData.data completion:nil];
    }
}

- (void)callDecodeResultDelegateWithSocketId:(NSString *)socketId decodeResult:(NSData *)result {
    QuecSocket *socket = [_socketDictionary valueForKey:socketId];
    if (socket) {
        NSString *packageId = [NSString stringWithFormat:@"%d", 9999];
        NSString *callbackId = [QuecSocketManager getCallbackId:socketId packageId:packageId];
        if ([self.callBackDictionary objectForKey:socketId]) {
            void(^callBack)(BOOL timeout, id response) = [self.callBackDictionary objectForKey:callbackId];
            if (callBack) {
                callBack(NO, result);
            }
            [self.callBackDictionary removeObjectForKey:callbackId];
            return;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            for (int i = 0; i < self.delegateArray.count; i ++) {
                id<QuecSocketDelegate> delegate = self.delegateArray[i];
                if (delegate && [delegate respondsToSelector:@selector(quecSocket:didReadData:)]) {
                    [delegate quecSocket:socketId didReadData:result];
                }
            }
        });
    }
}

- (void)callCommandTimeoutWithParams:(NSDictionary *)params {
    NSLog(@"callCommandTimeoutWithParams: %@",params);
    NSString *socketId = params[@"socketId"];
    NSString *packageId = params[@"packageId"];
    NSString *callbackId = [QuecSocketManager getCallbackId:socketId packageId:packageId];
    QuecSocket *socket = [_socketDictionary valueForKey:socketId];
    if (!socket) {
        return;
    }
    if ([self.callBackDictionary objectForKey:callbackId]) {
        void(^callBack)(BOOL timeout, id response) = [self.callBackDictionary objectForKey:callbackId];
        if (callBack) {
            callBack(YES,nil);
        }
        [self.callBackDictionary removeObjectForKey:callbackId];
    }
}

#pragma mark -GCDAsyncSocketDelegate
- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket {
    NSLog(@"[socket][tcp] didAcceptNewSocket");
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    NSLog(@"[socket][tcp] didConnectToHost: %@ %hu",host,port);
    [sock readDataWithTimeout:-1 tag:0];
    QuecSocket *socket = (QuecSocket *)sock;
    [_socketDictionary setValue:socket forKey:socket.socketId];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        for (int i = 0; i < self.delegateArray.count; i ++) {
            id<QuecSocketDelegate> delegate = self.delegateArray[i];
            if (delegate && [delegate respondsToSelector:@selector(quecSocket:didConnectToHost:port:)]) {
                [delegate quecSocket:socket.socketId didConnectToHost:host port:port];
            }
        }
    });
//    [self startTimer];
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToUrl:(NSURL *)url {
    NSLog(@"[socket][tcp] didConnectToUrl: %@",url);
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    [sock readDataWithTimeout:-1 tag:0];
    QuecSocket *socket = (QuecSocket *)sock;
    NSLog(@"[tcp][%@] read data: %@", socket.socketId, [self intToLog:data]);
    if (socket) {
        QuecSocket *socket = (QuecSocket *)sock;
        [self callDecodeResultDelegateWithSocketId:socket.socketId decodeResult:data];
    }
}

- (void)socket:(GCDAsyncSocket *)sock didReadPartialDataOfLength:(NSUInteger)partialLength tag:(long)tag {
    NSLog(@"[socket][tcp] didReadPartialDataOfLength: %ld",partialLength);
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag{
    NSLog(@"[socket][tcp] didWriteDataWithTag: %ld",tag);
}

- (void)socket:(GCDAsyncSocket *)sock didWritePartialDataOfLength:(NSUInteger)partialLength tag:(long)tag {
    NSLog(@"[socket][tcp] didWritePartialDataOfLength: %ld",partialLength);
}

- (void)socketDidCloseReadStream:(GCDAsyncSocket *)sock {
    
}
- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(nullable NSError *)err {
    NSLog(@"[socket][tcp] socketDidDisconnect: %@, err: %@", sock.connectedHost, err);
    if (!sock) {
        return;
    }
    QuecSocket *socket = (QuecSocket *)sock;
    [_socketDictionary removeObjectForKey:socket.socketId];
    if ([_socketDictionary allKeys].count == 0) {
        [self cancleTimer];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        for (int i = 0; i < self.delegateArray.count; i ++) {
            id<QuecSocketDelegate> delegate = self.delegateArray[i];
            if (delegate && [delegate respondsToSelector:@selector(quecSocket:didDisconnectwithError:)]) {
                [delegate quecSocket:socket.socketId didDisconnectwithError:err];
            }
        }
    });
}

- (void)socketDidSecure:(GCDAsyncSocket *)sock {
    NSLog(@"[socket][tcp]socketDidSecure");
}

- (void)socket:(GCDAsyncSocket *)sock didReceiveTrust:(SecTrustRef)trust completionHandler:(void (^)(BOOL shouldTrustPeer))completionHandler {
    NSLog(@"[socket][tcp]didReceiveTrust");
}

#pragma mark -public method
- (void)addDelegate:(id<QuecSocketDelegate>)delegate {
    [_delegateArrayLock lock];
    if (![self.delegateArray containsObject:delegate]) {
        [self.delegateArray addObject:delegate];
    }
    [_delegateArrayLock unlock];
}

- (void)removeDelegate:(id<QuecSocketDelegate>)delegate {
    [_delegateArrayLock lock];
    if ([self.delegateArray containsObject:delegate]) {
        [self.delegateArray removeObject:delegate];
    }
    [_delegateArrayLock unlock];
}

- (NSString *)connectToHost:(NSString *)host onPort:(uint16_t)port socketId:(NSString *)socketId {
    if ([_socketDictionary objectForKey:socketId]) {
        NSLog(@"[socket][tcp] %@ is connected", socketId);
        return socketId;
    }
    QuecSocket *socket = [self getSocketWithHost:host port:port];
    if (socketId && socketId.length) {
        socket.socketId = socketId;
    }
    NSError *error;
    [socket connectToHost:host onPort:port withTimeout:QuecSocketTimeout error:&error];
    if (error) {
        NSLog(@"[socket][tcp] connectToHost: %@ port: %hu error: %@", host, port, error);
    }
    return socket.socketId;
}

- (void)sendDataBySocketId:(NSString *)socketId data:(NSData *)data completion:(void (^)(BOOL, NSData *))completion {
    QuecSocket *socket = [_socketDictionary valueForKey:socketId];
    if (socket) {
        NSLog(@"[tcp][%@] send data: %@", socketId, [self intToLog:data]);
        [socket writeData:data withTimeout:QuecSocketTimeout tag:9999];
        if (completion) {
            NSString *packageId = [NSString stringWithFormat:@"%d", 9999];
            NSString *callbackId = [QuecSocketManager getCallbackId:socketId packageId:packageId];
            [self.callBackDictionary setValue:completion forKey:callbackId];
            quec_async_on_main(^{
                quec_delay_on_main(self.commandResponseTimeout, ^{
                    [self callCommandTimeoutWithParams:@{@"socketId": socketId, @"packageId": packageId}];;
                });
            });
        }
    }
}

- (void)disConnectSocketWithSocketId:(NSString *)socketId {
    QuecSocket *socket = [_socketDictionary valueForKey:socketId];
    if (socket) {
        [socket disconnect];
        [self.socketDictionary removeObjectForKey:socket.socketId];
    }
}

- (void)disConnectAllSockets {
    NSArray *socketsArray = _socketDictionary.allValues;
    for (int i = 0; i < socketsArray.count; i ++) {
        QuecSocket *socket = socketsArray[i];
        [self disConnectSocketWithSocketId:socket.socketId];
    }
}

- (BOOL)isConnectedWithSocketId:(NSString *)socketId {
    QuecSocket *socket = [_socketDictionary valueForKey:socketId];
    if (!socket) {
        return false;
    }
    return socket.isConnected;
}

+ (NSString *)getCallbackId:(NSString *)socketId packageId:(NSString *)packageId {
    return [NSString stringWithFormat:@"%@@%@", socketId, packageId];
}

- (NSString *)intToLog:(NSData *)data {
    const uint8_t *bytes = data.bytes;
    NSMutableString *sb = [NSMutableString string];

    for (NSUInteger i = 0; i < data.length; i++) {
        [sb appendFormat:@"0x%02X ", bytes[i]];
    }
    return sb;
}


@end
