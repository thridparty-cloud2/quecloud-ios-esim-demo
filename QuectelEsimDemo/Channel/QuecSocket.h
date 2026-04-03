//
//  QuecSocket.h
//  QuectelEsimDemo
//
//  Created by quectel.tank on 1/27/26.
//

#import <CocoaAsyncSocket/GCDAsyncSocket.h>

NS_ASSUME_NONNULL_BEGIN

@interface QuecSocket : GCDAsyncSocket
// id
@property (nonatomic, copy) NSString *socketId;
@end

NS_ASSUME_NONNULL_END
