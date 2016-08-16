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
} Header; //NOTE: This header is in big-endian   �Ҹо�Ӧ����8���ֽ�

//CLASS INTERFACES:

@interface TCPConnection (Internal)
- (id) _initWithRunLoop:(NSRunLoop*)runLoop readStream:(CFReadStreamRef)input writeStream:(CFWriteStreamRef)output;
- (void) _handleStreamEvent:(CFStreamEventType)type forStream:(CFTypeRef)stream;
@end

//FUNCTIONS:
//��̬��������������������ĳһ���¼���;͵����������
static void _ReadClientCallBack(CFReadStreamRef stream, CFStreamEventType type, void* clientCallBackInfo)
{
	NSAutoreleasePool*		localPool = [NSAutoreleasePool new];
	
	[(TCPConnection*)clientCallBackInfo _handleStreamEvent:type forStream:stream];
	
	[localPool release];
}
//��̬�������������������ĳһ���¼���;͵����������
static void _WriteClientCallBack(CFWriteStreamRef stream, CFStreamEventType type, void* clientCallBackInfo)
{
	NSAutoreleasePool*		localPool = [NSAutoreleasePool new];
	
	[(TCPConnection*)clientCallBackInfo _handleStreamEvent:type forStream:stream];
	
	[localPool release];
}

//CLASS IMPLEMENTATION:

@implementation TCPConnection

@synthesize delegate=_delegate;


//������ĳ�ʼ������
- (id) initWithSocketHandle:(int)socket
{
	CFReadStreamRef			readStream = NULL;
	CFWriteStreamRef		writeStream = NULL;
	//      //������һ���������������CFStreamCreatePairWithSocket()�����������������һ����������������ǵ��ѽ������ӵ�socket�������ڵ�nativeSocketHandle�����а󶨣��������ǵ�������ӾͿ���ͨ����һ����������������Ĳ�����
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
	//����������������kCFStreamPropertyShouldCloseNativeSocket����Ϊ�棬Ĭ���������������Ǽٵģ������Ϊ�����˵��������ǵ����ͷŵĻ�������������󶨵�socketҲҪ�ͷ�
	CFReadStreamSetProperty(readStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
	CFWriteStreamSetProperty(writeStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
	//
    self = [self _initWithRunLoop:[NSRunLoop currentRunLoop] readStream:readStream writeStream:writeStream];
	CFRelease(readStream);
	CFRelease(writeStream);
	
	return self;
}
//������ӵĻ����ǿͻ��˵�mac���õģ����������񲢽���֮�󣬿�ʼ��������iphone�����������Բ����ĵ�ַ�Ļ����Ƿ���˵ĵ�ַ
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
	//������Щ�������ǵõ����ӵ�socket������������������ڼ�ios������ͨ����ͨ��[netService getInputStream:&_inStream outputStream:&_outStream]�����Ƿ�װ���˵ģ�
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
	//������ӵ�������ѭ���У����򿪣�����֮����Ѿ���һ���ˣ��������Ҫ�ͷ����������
	self = [self _initWithRunLoop:[NSRunLoop currentRunLoop] readStream:readStream writeStream:writeStream];
	CFRelease(readStream); //�ͷ����ڵģ������Ѿ��ӽ�ȥ��
	CFRelease(writeStream);
	
	return self;
}
//�������뵽����ѭ���У���- (id) initWithSocketHandle:(int)socket�����������- (id) initWithRemoteAddress:(const struct sockaddr*)address
//��������е��õ�
- (id) _initWithRunLoop:(NSRunLoop*)runLoop readStream:(CFReadStreamRef)input writeStream:(CFWriteStreamRef)output
{
	CFStreamClientContext	context = {0, self, NULL, NULL, NULL};
	
	if((self = [super init])) {
		_inputStream = (CFReadStreamRef)CFRetain(input);
		_outputStream = (CFWriteStreamRef)CFRetain(output);
		_runLoop = runLoop;
		[_runLoop retain];
		//Ӧ����������仯�¼��ͼ��뵽����ѭ���У��ڼ�ios������ͨ�ŵ�ʾ���в�����ô���ģ���Ӧ�ö��ǿ��Ե�
		CFReadStreamSetClient(_inputStream, kCFStreamEventOpenCompleted | kCFStreamEventHasBytesAvailable | kCFStreamEventErrorOccurred | kCFStreamEventEndEncountered, _ReadClientCallBack, &context);
		CFReadStreamScheduleWithRunLoop(_inputStream, [_runLoop getCFRunLoop], kCFRunLoopCommonModes);
		CFWriteStreamSetClient(_outputStream, kCFStreamEventOpenCompleted | kCFStreamEventCanAcceptBytes | kCFStreamEventErrorOccurred | kCFStreamEventEndEncountered, _WriteClientCallBack, &context);
		CFWriteStreamScheduleWithRunLoop(_outputStream, [_runLoop getCFRunLoop], kCFRunLoopCommonModes);
		//�����Ƿ����û�У��������̵������仯����������switch case���Ǹ�������
		if(!CFReadStreamOpen(_inputStream) || !CFWriteStreamOpen(_outputStream)) { //�򿪺󴥷����仯�¼�
			[self release];
			return nil;
		}
	}
	
	return self;
}
//�ͷţ��߼���ʵ����invalidate����
- (void) dealloc
{	
	[self invalidate]; 
	
	if(_localAddress)
	free(_localAddress);
	if(_remoteAddress)
	free(_remoteAddress);
	
	[super dealloc];
}
//����ί��
- (void) setDelegate:(id<TCPConnectionDelegate>)delegate
{
	_delegate = delegate;
	
	SET_DELEGATE_METHOD_BIT(0, connectionDidFailOpening:);
	SET_DELEGATE_METHOD_BIT(1, connectionDidOpen:);
	SET_DELEGATE_METHOD_BIT(2, connectionDidClose:);
	SET_DELEGATE_METHOD_BIT(3, connection:didReceiveData:);
}
//�ж��Ƿ���Ч
- (BOOL) isValid
{   //Ҳ����opened���ڵ���3�������¼���Ҫһ�Σ��пռ䷢����Ҫһ�Σ��ܹ�3��
	return ((_opened >= kOpenedMax) && !_invalidating ? YES : NO);
}
//ʹ�������������������ѭ������Ч��˽�з���
- (void) _invalidate
{
	if(_inputStream) { //�ر��ͷ�������
		CFReadStreamSetClient(_inputStream, kCFStreamEventNone, NULL, NULL);
		CFReadStreamClose(_inputStream);
		CFRelease(_inputStream);
		_inputStream = NULL;
	}
	
	if(_outputStream) {//�ر��ͷ������
		CFWriteStreamSetClient(_outputStream, kCFStreamEventNone, NULL, NULL);
		CFWriteStreamClose(_outputStream);
		CFRelease(_outputStream);
		_outputStream = NULL;
	}
	
	if(_runLoop) { //�ͷŵ�ǰ������ѭ��
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
//ʹ֮��Ч�����з���
- (void) invalidate
{
	if(_invalidating == NO) {
		_invalidating = YES;
		
		[self _invalidate];
	}
}
//�������ͻ���д������data��ͼƬ���ݡ�˽�з���
- (BOOL) _writeData:(NSData*)data
{
	CFIndex					length = [data length],
							result;
	Header					header;
	
	header.magic = NSSwapHostIntToBig(kMagic); //�����ֽ���ת����������ֽ���Ӧ�������ֶ���
	header.length = NSSwapHostIntToBig(length);
	result = CFWriteStreamWrite(_outputStream, (const UInt8*)&header, sizeof(Header));//����ɽṹ�壬���͵��Է�����ȥ
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
	
	result = CFReadStreamRead(_inputStream, (UInt8*)&header, sizeof(Header)); //����0��˵���Ѿ�������
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
		if(result <= 0) { //resulet=0,������
			REPORT_ERROR(@"Read only %i bytes out of %i (%i) bytes in data", (int)result, (int)length, [data length]);
			return nil;
		}
		length -= result;
	}
	
	return data;
}
//��ʼ��������������ͨ��������Եõ�Զ�˺ͱ��صĵ�ַ��Ϣ
- (void) _initializeConnection:(CFTypeRef)stream
{
	int						value = 1;
	CFDataRef				data;
	CFSocketNativeHandle	socket;
	socklen_t				length;
	//if�����ǿ��������������������
	if((data = (CFGetTypeID(stream) == CFWriteStreamGetTypeID() ? CFWriteStreamCopyProperty((CFWriteStreamRef)stream, kCFStreamPropertySocketNativeHandle) : CFReadStreamCopyProperty((CFReadStreamRef)stream, kCFStreamPropertySocketNativeHandle)))) {
		CFDataGetBytes(data, CFRangeMake(0, sizeof(CFSocketNativeHandle)), (UInt8*)&socket);
		value = 1;
     //����setsockopt��������������socket��ѡ��  ,����һ��һ��socket����������
//��������ѡ���Ĳ�� ֧��SOL_SOCKET��IPPROTO_TCP��IPPROTO_IP��IPPROTO_IPV6 �����������õ�ѡ������֣������SO_REUSEADDR������ʾ�������ñ��ص�ַ�Ͷ˿ڣ�����˵������ѱ�ʹ�õĵ�ַ����˿ںţ���
//ȱʡ�����£�һ���׽ӿڲ�����һ������ʹ���еı��ص�ַ���󡣵���ʱ����Ҫ�����á���ַ����Ϊÿһ�����Ӷ��ɱ��ص�ַ��Զ�˵�ַ�����Ψһȷ��������ֻҪԶ�˵�ַ��ͬ�������׽ӿ���һ����ַ�����޴󰭡���;
//�����ģ���һ��ָ�룬ָ��Ҫ���õ�ѡ���ѡ��ֵ�Ļ������������Ǵ������������int����value�ĵ�ַ������˵���ǰ����ѡ����Ϊ1
//�����壺���ѡ��ֵ���ݻ������Ĵ�С��������sizeof��value�����ݳ��Ȳ����˽�ȥ��
		setsockopt(socket, SOL_SOCKET, SO_KEEPALIVE, &value, sizeof(value));
		value = sizeof(Header);
		setsockopt(socket, SOL_SOCKET, SO_SNDLOWAT, &value, sizeof(value));
		setsockopt(socket, SOL_SOCKET, SO_SNDLOWAT, &value, sizeof(value));
		CFRelease(data);
		
		length = SOCK_MAXADDRLEN; // ������һ��255��С��������������socket�ĵ�ַ
		_localAddress = malloc(length);
		if(getsockname(socket, _localAddress, &length) < 0) { //�õ����صĵ�ַ
			free(_localAddress);
			_localAddress = NULL;
			REPORT_ERROR(@"Unable to retrieve local address (%i)", errno);
		}
		length = SOCK_MAXADDRLEN;
		_remoteAddress = malloc(length);
		if(getpeername(socket, _remoteAddress, &length) < 0) {//�õ�Զ�̵ĵ�ַ
			free(_remoteAddress);
			_remoteAddress = NULL;
			REPORT_ERROR(@"Unable to retrieve remote address (%i)", errno);
		}
		
		if(TEST_DELEGATE_METHOD_BIT(1))
        //���ܶԷ����������Ӻ󣬵������������ʾ�Ѿ������������������ô�������أ������������
      //1.- (id) initWithSocketHandle:(int)socket 2.- (void) _handleStreamEvent:(CFStreamEventType)type forStream:(CFTypeRef)stream
 //3._initializeConnection
           //���ô����ӵ�ί�з���
		[_delegate connectionDidOpen:self]; //NOTE: Connection may have been invalidated after this call!
	}
	else
	[NSException raise:NSInternalInconsistencyException format:@"Unable to retrieve socket from CF stream"];
}

/* Behavior notes regarding socket based CF streams:
- The connection is really ready once both input & output streams are opened and the output stream is writable
- The connection can receive a "has bytes available" notification before it's ready as defined above, in which case it should be ignored as there seems to be no bytes available to read anyway
����������������򿪵�ʱ�������Ѿ�׼�����������ʱ��������ǿ���д�����ˡ�
 * ����������׼����֮ǰ���յ�һ������д���Լ���֪ͨ����Ϣ�������ʱ������Ӧ�ú���������Ϊû���ֽڿ�д
 */
- (void) _handleStreamEvent:(CFStreamEventType)type forStream:(CFTypeRef)stream
{
	NSData*				data;
	CFStreamError		error;
	
	
	switch(type) {
		
		case kCFStreamEventOpenCompleted:
		if(_opened < kOpenedMax) { //������Ϊ3��Ϊɶ��
			_opened += 1;
			if(_opened == kOpenedMax)
			[self _initializeConnection:stream];
		}
		break;
		//���ֽڿ��Խ��� ����û�����      NSStreamEventHasSpaceAvailable�����������пռ�ɹ�����д�룩����Ū�죬�������� 
		case kCFStreamEventHasBytesAvailable: //NOTE: kCFStreamEventHasBytesAvailable will be sent for 0 bytes available to read when stream reaches end   �����������
		if(_opened >= kOpenedMax) {
			do {
				data = [self _readData];  //(id)kCFNull˵���Ѿ�������
				if(data != (id)kCFNull) {
					if(data == nil) {
						[self invalidate]; //NOTE: "self" might have been already de-alloced after this call! ,
						return;
					}
					else {
						if((_invalidating == NO) && TEST_DELEGATE_METHOD_BIT(3)) //invalidating==NO(������Ч)
						[_delegate connection:(id)self didReceiveData:data]; //NOTE: Avoid type conflict with NSURLConnection delegate
					}
				}
			} while(!_invalidating && CFReadStreamHasBytesAvailable(_inputStream));
		}
		break;
		//���ֽڿ��Խ��յ�ʱ��
   /*
    ��CFNetwork�У���ʱ��ʹ��CFWriteStreamWrite����д����ʱ���ᵼ�¸��ֳɱ�����blockס��
    * ԭ����CFWriteStream���ܽ�������ʱ��д�����ˡ�
    * �������취����CFSriteStream�յ��첽��kCFStreamEventCanAcceptBytes֪ͨʱ��
    * �ٿ�ʼд���ݡ���ʱ�ɱ���CFWriteStreamWrite�����̱߳�block�����Ρ�

    */  //����˺Ϳͻ��˶����������������ΪֻҪ����������˫���������������������������ǻ��ߵģ��������ڷ������ʵ���˴򿪺��ί�з����������ȥ����main�е�ͼƬ�����ͻ���û��ʵ�����������������ȥ�������ݡ�
		case kCFStreamEventCanAcceptBytes:  //��stream���Խ����ֽ�д���ʱ�� ����һ����˼����NSStreamEventHasSpaceAvailable��API�ĵ�����������һ����˼���������Ե��������
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
//�������������Ƿ������ֽ���
- (BOOL) hasDataAvailable
{
	if(![self isValid])
	return NO;
	
	return CFReadStreamHasBytesAvailable(_inputStream);
}
//�������ݣ��������������⿪��
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
//���ͷ�������������
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
//���ر��صĵ�ַ�Ķ˿�
- (UInt16) localPort
{
	if(_localAddress)
	switch(_localAddress->sa_family) {
		case AF_INET: return ntohs(((struct sockaddr_in*)_localAddress)->sin_port); //ip4
		case AF_INET6: return ntohs(((struct sockaddr_in6*)_localAddress)->sin6_port); //IP6
	}
	
	return 0;
}
//���ر��ص�ַ
- (UInt32) localIPv4Address
{
	return (_localAddress && (_localAddress->sa_family == AF_INET) ? ((struct sockaddr_in*)_localAddress)->sin_addr.s_addr : 0);
}
//����Զ�̶˿�
- (UInt16) remotePort
{
	if(_remoteAddress)
	switch(_remoteAddress->sa_family) {
		case AF_INET: return ntohs(((struct sockaddr_in*)_remoteAddress)->sin_port);
	}
	
	return 0;
}
//����Զ�̵�ַ
- (UInt32) remoteIPv4Address
{
	return (_remoteAddress && (_remoteAddress->sa_family == AF_INET) ? ((struct sockaddr_in*)_remoteAddress)->sin_addr.s_addr : 0);
}
//���������
- (NSString*) description
{
	return [NSString stringWithFormat:@"<%@ = 0x%08X | valid = %i | local address = %@ | remote address = %@>", [self class], (long)self, [self isValid], SockaddrToString(_localAddress), SockaddrToString(_remoteAddress)];
}
//Զ�̵�ַ�ṹ��
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
