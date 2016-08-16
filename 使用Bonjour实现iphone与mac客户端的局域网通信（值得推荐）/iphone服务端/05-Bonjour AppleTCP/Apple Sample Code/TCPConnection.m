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

File: TCPConnection.m
Abstract: Convenience class that acts as a controller for TCP based network
connections.

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

#import <unistd.h>
#import <netinet/in.h>

#import <CFNetwork/CFNetwork.h>
#import "TCPConnection.h"
#import "NetUtilities.h"
#import "Networking_Internal.h"

//CONSTANTS:

#define kMagic						0x1234ABCD
#define kOpenedMax					3

//STRUCTURE:

typedef struct {
	NSUInteger		magic;
	NSUInteger		length;
} Header; //NOTE: This header is in big-endian   我感觉应该是8个字节

//CLASS INTERFACES:

@interface TCPConnection (Internal)
- (id) _initWithRunLoop:(NSRunLoop*)runLoop readStream:(CFReadStreamRef)input writeStream:(CFWriteStreamRef)output;
- (void) _handleStreamEvent:(CFStreamEventType)type forStream:(CFTypeRef)stream;
@end

//FUNCTIONS:
//静态方法，当触发输入流的某一个事件后就就调用这个方法
static void _ReadClientCallBack(CFReadStreamRef stream, CFStreamEventType type, void* clientCallBackInfo)
{
	NSAutoreleasePool*		localPool = [NSAutoreleasePool new];
	
	[(TCPConnection*)clientCallBackInfo _handleStreamEvent:type forStream:stream];
	
	[localPool release];
}
//静态方法，当触发输出流的某一个事件后就就调用这个方法
static void _WriteClientCallBack(CFWriteStreamRef stream, CFStreamEventType type, void* clientCallBackInfo)
{
	NSAutoreleasePool*		localPool = [NSAutoreleasePool new];
	
	[(TCPConnection*)clientCallBackInfo _handleStreamEvent:type forStream:stream];
	
	[localPool release];
}

//CLASS IMPLEMENTATION:

@implementation TCPConnection

@synthesize delegate=_delegate;


//连接类的初始化方法
- (id) initWithSocketHandle:(int)socket
{
	CFReadStreamRef			readStream = NULL;
	CFWriteStreamRef		writeStream = NULL;
	//      //申请了一对输入输出流，用CFStreamCreatePairWithSocket()方法把我们申请的这一对输入输出流和我们的已建立连接的socket（即现在的nativeSocketHandle）进行绑定，这样我们的这个连接就可以通过这一对流进行输入输出的操作了
	CFStreamCreatePairWithSocket(kCFAllocatorDefault, socket, &readStream, &writeStream);
	if(!readStream || !writeStream) {
		close(socket);
		if(readStream)
		CFRelease(readStream);
		if(writeStream)
		CFRelease(writeStream);
		[self release];
		return nil;
	}
	//把这两个流的属性kCFStreamPropertyShouldCloseNativeSocket设置为真，默认情况下这个属性是假的，这个设为真就是说，如果我们的流释放的话，我们这个流绑定的socket也要释放
	CFReadStreamSetProperty(readStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
	CFWriteStreamSetProperty(writeStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
	//
    self = [self _initWithRunLoop:[NSRunLoop currentRunLoop] readStream:readStream writeStream:writeStream];
	CFRelease(readStream);
	CFRelease(writeStream);
	
	return self;
}
//这个例子的话就是客户端的mac调用的，搜索到服务并解析之后，开始请求连接iphone服务器，所以参数的地址的话就是服务端的地址
- (id) initWithRemoteAddress:(const struct sockaddr*)address
{
	CFReadStreamRef			readStream = NULL;
	CFWriteStreamRef		writeStream = NULL;
	CFSocketSignature		signature;
	CFDataRef				data;
	
	data = (address ? CFDataCreate(kCFAllocatorDefault, (const UInt8*)address, address->sa_len) : NULL);
	if(data == NULL) {
		[self release];
		return nil;
	}
	//反正这些操作就是得到连接的socket的输入流和输出流（在简单ios局域网通信是通过[netService getInputStream:&_inStream outputStream:&_outStream]估计是封装好了的）
	signature.protocolFamily = PF_INET;
	signature.socketType = SOCK_STREAM;
	signature.protocol = IPPROTO_TCP;
	signature.address = data;
	CFStreamCreatePairWithPeerSocketSignature(kCFAllocatorDefault, &signature, &readStream, &writeStream);
	CFRelease(data);
	if(!readStream || !writeStream) {
		if(readStream)
		CFRelease(readStream);
		if(writeStream)
		CFRelease(writeStream);
		[self release];
		return nil;
	}
	//把流添加到了运行循环中，并打开，加入之后就已经有一份了，所以最后要释放输入输出流
	self = [self _initWithRunLoop:[NSRunLoop currentRunLoop] readStream:readStream writeStream:writeStream];
	CFRelease(readStream); //释放现在的，上面已经加进去了
	CFRelease(writeStream);
	
	return self;
}
//把流加入到运行循环中，在- (id) initWithSocketHandle:(int)socket这个方法或者- (id) initWithRemoteAddress:(const struct sockaddr*)address
//这个方法中调用的
- (id) _initWithRunLoop:(NSRunLoop*)runLoop readStream:(CFReadStreamRef)input writeStream:(CFWriteStreamRef)output
{
	CFStreamClientContext	context = {0, self, NULL, NULL, NULL};
	
	if((self = [super init])) {
		_inputStream = (CFReadStreamRef)CFRetain(input);
		_outputStream = (CFWriteStreamRef)CFRetain(output);
		_runLoop = runLoop;
		[_runLoop retain];
		//应该是添加流变化事件和加入到运行循环中，在简单ios局域网通信的示例中不是这么做的，但应该都是可以的
		CFReadStreamSetClient(_inputStream, kCFStreamEventOpenCompleted | kCFStreamEventHasBytesAvailable | kCFStreamEventErrorOccurred | kCFStreamEventEndEncountered, _ReadClientCallBack, &context);
		CFReadStreamScheduleWithRunLoop(_inputStream, [_runLoop getCFRunLoop], kCFRunLoopCommonModes);
		CFWriteStreamSetClient(_outputStream, kCFStreamEventOpenCompleted | kCFStreamEventCanAcceptBytes | kCFStreamEventErrorOccurred | kCFStreamEventEndEncountered, _WriteClientCallBack, &context);
		CFWriteStreamScheduleWithRunLoop(_outputStream, [_runLoop getCFRunLoop], kCFRunLoopCommonModes);
		//看看是否打开了没有，打开了立刻调用流变化方法（就是switch case的那个方法）
		if(!CFReadStreamOpen(_inputStream) || !CFWriteStreamOpen(_outputStream)) { //打开后触发流变化事件
			[self release];
			return nil;
		}
	}
	
	return self;
}
//释放，逻辑其实都在invalidate里了
- (void) dealloc
{	
	[self invalidate]; 
	
	if(_localAddress)
	free(_localAddress);
	if(_remoteAddress)
	free(_remoteAddress);
	
	[super dealloc];
}
//设置委托
- (void) setDelegate:(id<TCPConnectionDelegate>)delegate
{
	_delegate = delegate;
	
	SET_DELEGATE_METHOD_BIT(0, connectionDidFailOpening:);
	SET_DELEGATE_METHOD_BIT(1, connectionDidOpen:);
	SET_DELEGATE_METHOD_BIT(2, connectionDidClose:);
	SET_DELEGATE_METHOD_BIT(3, connection:didReceiveData:);
}
//判断是否无效
- (BOOL) isValid
{   //也就是opened大于等于3，连接事件需要一次，有空间发送需要一次，总共3次
	return ((_opened >= kOpenedMax) && !_invalidating ? YES : NO);
}
//使输出流，输入流，运行循环等无效。私有方法
- (void) _invalidate
{
	if(_inputStream) { //关闭释放输入流
		CFReadStreamSetClient(_inputStream, kCFStreamEventNone, NULL, NULL);
		CFReadStreamClose(_inputStream);
		CFRelease(_inputStream);
		_inputStream = NULL;
	}
	
	if(_outputStream) {//关闭释放输出流
		CFWriteStreamSetClient(_outputStream, kCFStreamEventNone, NULL, NULL);
		CFWriteStreamClose(_outputStream);
		CFRelease(_outputStream);
		_outputStream = NULL;
	}
	
	if(_runLoop) { //释放当前的运行循环
		[_runLoop release];
		_runLoop = nil;
	}
	
	if(_opened >= kOpenedMax) {
		if(TEST_DELEGATE_METHOD_BIT(2))
		[_delegate connectionDidClose:self];
		_opened = 0;
	}
	else if(TEST_DELEGATE_METHOD_BIT(0))
	[_delegate connectionDidFailOpening:self];
}
//使之无效，公有方法
- (void) invalidate
{
	if(_invalidating == NO) {
		_invalidating = YES;
		
		[self _invalidate];
	}
}
//服务端向客户端写东西，data是图片数据。私有方法
- (BOOL) _writeData:(NSData*)data
{
	CFIndex					length = [data length],
							result;
	Header					header;
	
	header.magic = NSSwapHostIntToBig(kMagic); //主机字节序转换成网络大字节序，应该是区分东西
	header.length = NSSwapHostIntToBig(length);
	result = CFWriteStreamWrite(_outputStream, (const UInt8*)&header, sizeof(Header));//打包成结构体，发送到对方那里去
	if(result != sizeof(Header)) {
		REPORT_ERROR(@"Wrote only %i bytes out of %i bytes in header", (int)result, (int)sizeof(Header));
		return NO;
	}
	
	while(length > 0) {
		result = CFWriteStreamWrite(_outputStream, (UInt8*)[data bytes] + [data length] - length, length);
		if(result <= 0) {
			REPORT_ERROR(@"Wrote only %i bytes out of %i (%i) bytes in data", (int)result, (int)length, [data length]);
			return NO;
		}
		length -= result;
	}
	
	return YES;
}

- (NSData*) _readData
{
	NSMutableData*			data;
	CFIndex					result,
							length;
	Header					header;
	
	result = CFReadStreamRead(_inputStream, (UInt8*)&header, sizeof(Header)); //读到0，说明已经结束了
	if(result == 0)
	return (id)kCFNull;
	if(result != sizeof(Header)) {
		REPORT_ERROR(@"Read only %i bytes out of %i bytes in header", (int)result, (int)sizeof(Header));
		return nil;
	}
	if(NSSwapBigIntToHost(header.magic) != kMagic) {
		REPORT_ERROR(@"Invalid header", NULL);
		return nil;
	}
	
	length = NSSwapBigIntToHost(header.length);
	data = [NSMutableData dataWithCapacity:length];
	[data setLength:length];
	
	while(length > 0) {
		result = CFReadStreamRead(_inputStream, (UInt8*)[data mutableBytes] + [data length] - length, length);
		if(result <= 0) { //resulet=0,读完了
			REPORT_ERROR(@"Read only %i bytes out of %i (%i) bytes in data", (int)result, (int)length, [data length]);
			return nil;
		}
		length -= result;
	}
	
	return data;
}
//初始化流，这里来看通过这个可以得到远端和本地的地址信息
- (void) _initializeConnection:(CFTypeRef)stream
{
	int						value = 1;
	CFDataRef				data;
	CFSocketNativeHandle	socket;
	socklen_t				length;
	//if里面是看看是输入流还是输出流
	if((data = (CFGetTypeID(stream) == CFWriteStreamGetTypeID() ? CFWriteStreamCopyProperty((CFWriteStreamRef)stream, kCFStreamPropertySocketNativeHandle) : CFReadStreamCopyProperty((CFReadStreamRef)stream, kCFStreamPropertySocketNativeHandle)))) {
		CFDataGetBytes(data, CFRangeMake(0, sizeof(CFSocketNativeHandle)), (UInt8*)&socket);
		value = 1;
     //调用setsockopt（）方法来设置socket的选项  ,参数一：一个socket的描述符，
//参数二：选项定义的层次 支持SOL_SOCKET、IPPROTO_TCP、IPPROTO_IP和IPPROTO_IPV6 参数三：设置的选项的名字，如果是SO_REUSEADDR。（表示允许重用本地地址和端口，就是说充许绑定已被使用的地址（或端口号），
//缺省条件下，一个套接口不能与一个已在使用中的本地地址捆绑。但有时会需要“重用”地址。因为每一个连接都由本地地址和远端地址的组合唯一确定，所以只要远端地址不同，两个套接口与一个地址捆绑并无大碍。）;
//参数四：是一个指针，指向要设置的选项的选项值的缓冲区，这里是传入上面申请的int变量value的地址，就是说我们把这个选项设为1
//参数五：这个选项值数据缓冲区的大小，这里用sizeof得value的数据长度并传了进去。
		setsockopt(socket, SOL_SOCKET, SO_KEEPALIVE, &value, sizeof(value));
		value = sizeof(Header);
		setsockopt(socket, SOL_SOCKET, SO_SNDLOWAT, &value, sizeof(value));
		setsockopt(socket, SOL_SOCKET, SO_SNDLOWAT, &value, sizeof(value));
		CFRelease(data);
		
		length = SOCK_MAXADDRLEN; // 申请了一个255大小的数组用来接收socket的地址
		_localAddress = malloc(length);
		if(getsockname(socket, _localAddress, &length) < 0) { //得到本地的地址
			free(_localAddress);
			_localAddress = NULL;
			REPORT_ERROR(@"Unable to retrieve local address (%i)", errno);
		}
		length = SOCK_MAXADDRLEN;
		_remoteAddress = malloc(length);
		if(getpeername(socket, _remoteAddress, &length) < 0) {//得到远程的地址
			free(_remoteAddress);
			_remoteAddress = NULL;
			REPORT_ERROR(@"Unable to retrieve remote address (%i)", errno);
		}
		
		if(TEST_DELEGATE_METHOD_BIT(1))
        //接受对方发出的连接后，调用这个方法表示已经打开啦。这个方法是怎么过来的呢，看下面的流程
      //1.- (id) initWithSocketHandle:(int)socket 2.- (void) _handleStreamEvent:(CFStreamEventType)type forStream:(CFTypeRef)stream
 //3._initializeConnection
           //调用打开连接的委托方法
		[_delegate connectionDidOpen:self]; //NOTE: Connection may have been invalidated after this call!
	}
	else
	[NSException raise:NSInternalInconsistencyException format:@"Unable to retrieve socket from CF stream"];
}

/* Behavior notes regarding socket based CF streams:
- The connection is really ready once both input & output streams are opened and the output stream is writable
- The connection can receive a "has bytes available" notification before it's ready as defined above, in which case it should be ignored as there seems to be no bytes available to read anyway
当输入流和输出流打开的时候，连接已经准备好啦，这个时候输出流是可以写东西了。
 * 流会在真正准备好之前会收到一个可以写入自己的通知的消息，但这个时候我们应该忽略他，因为没有字节可写
 */
- (void) _handleStreamEvent:(CFStreamEventType)type forStream:(CFTypeRef)stream
{
	NSData*				data;
	CFStreamError		error;
	
	
	switch(type) {
		
		case kCFStreamEventOpenCompleted:
		if(_opened < kOpenedMax) { //连接最为3，为啥？
			_opened += 1;
			if(_opened == kOpenedMax)
			[self _initializeConnection:stream];
		}
		break;
		//有字节可以接收 这里没有这个      NSStreamEventHasSpaceAvailable（当流对象有空间可供数据写入）老是弄混，害苦我了 
		case kCFStreamEventHasBytesAvailable: //NOTE: kCFStreamEventHasBytesAvailable will be sent for 0 bytes available to read when stream reaches end   ，针对输入流
		if(_opened >= kOpenedMax) {
			do {
				data = [self _readData];  //(id)kCFNull说明已经读完了
				if(data != (id)kCFNull) {
					if(data == nil) {
						[self invalidate]; //NOTE: "self" might have been already de-alloced after this call! ,
						return;
					}
					else {
						if((_invalidating == NO) && TEST_DELEGATE_METHOD_BIT(3)) //invalidating==NO(不是无效)
						[_delegate connection:(id)self didReceiveData:data]; //NOTE: Avoid type conflict with NSURLConnection delegate
					}
				}
			} while(!_invalidating && CFReadStreamHasBytesAvailable(_inputStream));
		}
		break;
		//有字节可以接收的时候
   /*
    在CFNetwork中，有时候使用CFWriteStreamWrite方法写数据时，会导致该现成被长久block住。
    * 原因：在CFWriteStream不能接受数据时，写数据了。
    * 具体解决办法：在CFSriteStream收到异步的kCFStreamEventCanAcceptBytes通知时，
    * 再开始写数据。此时可避免CFWriteStreamWrite导致线程被block的情形。

    */  //服务端和客户端都会走这个方法，因为只要打开流，而且双方都有输出流，所以这个方法都是会走的，区别在于服务端有实现了打开后的委托方法，里面回去发送main中的图片，而客户端没有实现这个方法，所以是去接收数据。
		case kCFStreamEventCanAcceptBytes:  //当stream可以接收字节写入的时候 和他一个意思的是NSStreamEventHasSpaceAvailable（API文档上这两个是一个意思），这个针对的是输出流
		if(_opened < kOpenedMax) {
			_opened += 1;
			if(_opened == kOpenedMax)
			[self _initializeConnection:stream];
		}
		break;
		
		case kCFStreamEventErrorOccurred:
		error = (CFGetTypeID(stream) == CFWriteStreamGetTypeID() ? CFWriteStreamGetError((CFWriteStreamRef)stream) : CFReadStreamGetError((CFReadStreamRef)stream));
		REPORT_ERROR(@"Error (%i) occured in CF stream", (int)error.error);
		case kCFStreamEventEndEncountered:
		[self invalidate];
		break;
				
	}
}
//看看输入流中是否有了字节了
- (BOOL) hasDataAvailable
{
	if(![self isValid])
	return NO;
	
	return CFReadStreamHasBytesAvailable(_inputStream);
}
//接收数据，公共方法，对外开放
- (NSData*) receiveData
{
	NSData*				data;
	
	if(![self isValid])
	return nil;
	
	data = [self _readData];
	if(data == nil)
	[self invalidate];
	else if(data == (id)kCFNull)
	data = nil;
	
	return data;
}
//发送方法，公共方法
- (BOOL) sendData:(NSData*)data
{
	if(![self isValid] || !data)
	return NO;
	
	if(![self _writeData:data]) {
		[self invalidate];
		return NO;
	}
	
	return YES;
}
//返回本地的地址的端口
- (UInt16) localPort
{
	if(_localAddress)
	switch(_localAddress->sa_family) {
		case AF_INET: return ntohs(((struct sockaddr_in*)_localAddress)->sin_port); //ip4
		case AF_INET6: return ntohs(((struct sockaddr_in6*)_localAddress)->sin6_port); //IP6
	}
	
	return 0;
}
//返回本地地址
- (UInt32) localIPv4Address
{
	return (_localAddress && (_localAddress->sa_family == AF_INET) ? ((struct sockaddr_in*)_localAddress)->sin_addr.s_addr : 0);
}
//返回远程端口
- (UInt16) remotePort
{
	if(_remoteAddress)
	switch(_remoteAddress->sa_family) {
		case AF_INET: return ntohs(((struct sockaddr_in*)_remoteAddress)->sin_port);
	}
	
	return 0;
}
//返回远程地址
- (UInt32) remoteIPv4Address
{
	return (_remoteAddress && (_remoteAddress->sa_family == AF_INET) ? ((struct sockaddr_in*)_remoteAddress)->sin_addr.s_addr : 0);
}
//本类的描述
- (NSString*) description
{
	return [NSString stringWithFormat:@"<%@ = 0x%08X | valid = %i | local address = %@ | remote address = %@>", [self class], (long)self, [self isValid], SockaddrToString(_localAddress), SockaddrToString(_remoteAddress)];
}
//远程地址结构体
- (const struct sockaddr*) remoteSocketAddress
{
	return _remoteAddress;
}

+ (NSString*) bonjourTypeFromIdentifier:(NSString*)identifier {
	if (![identifier length])
    return nil;
    
    return [NSString stringWithFormat:@"_%@._tcp.", identifier];
}
@end
