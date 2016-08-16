/*

===== IMPORTANT =====

This is sample code demonstrating API, technology or techniques in development.
Although this sample code has been reviewed for technical accuracy, it is not
final. Apple is supplying this information to help you plan for the adoption of
the technologies and programming interfaces described herein. This information
is subject to change, and software implemented based on this sample code should
be tested with final operating system software and final documentation. Newer
versions of this sample code may be provided with future seeds of the API or
technology. For information about updates to this and other developer
documentation, view the New & Updated sidebars in subsequent documentation
seeds.

=====================

File: TCPServer.h
Abstract: Subclass of TCPService that implements a full TCP server.

Version: 1.1

Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple Inc.
("Apple") in consideration of your agreement to the following terms, and your
use, installation, modification or redistribution of this Apple software
constitutes acceptance of these terms.  If you do not agree with these terms,
please do not use, install, modify or redistribute this Apple software.

In consideration of your agreement to abide by the following terms, and subject
to these terms, Apple grants you a personal, non-exclusive license, under
Apple's copyrights in this original Apple software (the "Apple Software"), to
use, reproduce, modify and redistribute the Apple Software, with or without
modifications, in source and/or binary forms; provided that if you redistribute
the Apple Software in its entirety and without modifications, you must retain
this notice and the following text and disclaimers in all such redistributions
of the Apple Software.
Neither the name, trademarks, service marks or logos of Apple Inc. may be used
to endorse or promote products derived from the Apple Software without specific
prior written permission from Apple.  Except as expressly stated in this notice,
no other rights or licenses, express or implied, are granted by Apple herein,
including but not limited to any patent rights that may be infringed by your
derivative works or by other works in which the Apple Software may be
incorporated.

The Apple Software is provided by Apple on an "AS IS" basis.  APPLE MAKES NO
WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION THE IMPLIED
WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS FOR A PARTICULAR
PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND OPERATION ALONE OR IN
COMBINATION WITH YOUR PRODUCTS.

IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL OR
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION, MODIFICATION AND/OR
DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED AND WHETHER UNDER THEORY OF
CONTRACT, TORT (INCLUDING NEGLIGENCE), STRICT LIABILITY OR OTHERWISE, EVEN IF
APPLE HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

Copyright (C) 2008 Apple Inc. All Rights Reserved.

*/

#import "TCPService.h"
#import "TCPConnection.h"

//CLASSES:

@class TCPServer, TCPServerConnection;

//PROTOCOLS:

@protocol TCPServerDelegate <NSObject> 
@optional
//端口成功弄好了，在startUsingRunLoop方法中调用（main没有实现）
- (void) serverDidStart:(TCPServer*)server;
//服务发布成功后的调用，（main没有实现）
- (void) serverDidEnableBonjour:(TCPServer*)server withName:(NSString*)name;
//发布不成功，让delegate的回调，在- (void)netService:(NSNetService *)sender didNotPublish:(NSDictionary *)errorDict
//中调用，main没有实现
- (void) server:(TCPServer*)server didNotEnableBonjour:(NSDictionary *)errorDict;
//表示同意或者拒绝连接（这个方法在main中实现了，弹出一个框问你是否同意对方的请求连接）
- (BOOL) server:(TCPServer*)server shouldAcceptConnectionFromAddress:(const struct sockaddr*)address;
//连接外部客户端的时候，这个方法将接受并设置TCPConnection委托
//From this method, you typically set the delegate of the connection to be able to send & receive data through it
//在这个方法- (void) _addConnection:(TCPServerConnection*)connection中调用的，而这个方法是在main中调用的
- (void) server:(TCPServer*)server didOpenConnection:(TCPServerConnection*)connection; 
//关闭连接，main没有实现
- (void) server:(TCPServer*)server didCloseConnection:(TCPServerConnection*)connection;
//即将停止服务（main没有实现）
- (void) serverWillDisableBonjour:(TCPServer*)server;
//全部即将停止（main没有实现）
- (void) serverWillStop:(TCPServer*)server;
@end

//CLASS INTERFACES:

/*
This subclass of TCPService implements a full TCP server which automatically maintains the list of active connections.
See TCPService.h for other methods.
这TCPService的子类实现一个完整的TCP服务器。它用来自动维护活动连接的列表
看到TCPService。 h对其他方法。

*/
@interface TCPServer : TCPService
{
@private
	NSMutableSet*				_connections; //承载connection的哈希表
	id<TCPServerDelegate>		_delegate;
	NSUInteger					_delegateMethods;
}
+ (Class) connectionClass; //Must be a subclass of "TCPServerConnection"

@property(readonly) NSArray* allConnections;

@property(assign) id<TCPServerDelegate> delegate;
@end

/*
Subclass of TCPConnection used by TCPServer for its connections.
TCPServerConnection为TCPConnection的子类
*/
@interface TCPServerConnection : TCPConnection
{
@private
	TCPServer*			_server; //Not retained
}
@property(readonly) TCPServer* server;
@end
