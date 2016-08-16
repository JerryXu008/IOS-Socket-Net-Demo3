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

File: NetReachability.m
Abstract: Convenience class that wraps the SCNetworkReachability APIs from
SystemConfiguration.

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

#import <SystemConfiguration/SCNetworkReachability.h>
#import <netinet/in.h>

#import "NetReachability.h"
#import "Networking_Internal.h"

//MACROS:
//�������YES�Ļ�����һ��(__FLAGS__) & kSCNetworkReachabilityFlagsReachable) Ҳ����Ҫ��֤״̬Ϊ�ܹ���������   �ڶ��ǣ������ܹ��������磬�������ȵý������ӹ��̣�Ŀǰ��������ɶ��˼��
#define IS_REACHABLE(__FLAGS__) (((__FLAGS__) & kSCNetworkReachabilityFlagsReachable) && !((__FLAGS__) & kSCNetworkReachabilityFlagsConnectionRequired))
#if TARGET_IPHONE_SIMULATOR
#define IS_CELL(__FLAGS__) (0)
#else
//�������yes�Ļ�����һ�Ǳ�֤״̬Ϊ���� �ڶ����Ƿ���ͨ��WiFi�����ӣ����������������Ҫ����WIFI�����Է���YES�Ļ�����ʾδ����WIFI��
#define IS_CELL(__FLAGS__) (IS_REACHABLE(__FLAGS__) && ((__FLAGS__) & kSCNetworkReachabilityFlagsIsWWAN))
#endif

//CLASS IMPLEMENTATION:
//SystemConfiguration����кͲ�����������״̬��صĺ���������SCNetworkReachability.H�ļ���
//������Ҫ�����Ľ��ͣ�
/*
 
 ===================================SCNetworkReachabilityCreateWithAddress �������ͣ�
 * ԭ�ͣ�SCNetworkReachabilityRef SCNetworkReachabilityCreateWithAddress (
   CFAllocatorRef allocator,
   const struct sockaddr *address
);

 ���ã������������ӵ����ã�
����һ������ΪNULL��kCFAllocatorDefault
 * ��������Ҫ�������ӵ�IP��ַ����Ϊ0.0.0.0ʱ����Բ�ѯ��������������״̬
 * ����ֵ������һ�����ñ�����������ͷ�
 
 ==================================SCNetworkReachabilityRef SCNetworkReachabilityCreateWithName ��������
 * ԭ�ͣ�SCNetworkReachabilityRef SCNetworkReachabilityCreateWithName (
   CFAllocatorRef allocator,
   const char *nodename
);
����һ������ΪNULL��kCFAllocatorDefault
 ������������Ϊ"www.apple.com"����ַ��
 * 
 *================================== SCNetworkReachabilityGetFlags ��������
 *ԭ�ͣ�
Boolean SCNetworkReachabilityGetFlags (
   SCNetworkReachabilityRef target,
   SCNetworkReachabilityFlags *flags
);

 *���ã�ȷ�����ӵ�״̬���������������ò������ӵ�״̬��
 *��һ������Ϊ֮ǰ�����Ĳ������ӵ����ã��ڶ����������������õ�״̬������ܻ��״̬�򷵻�TRUE�����򷵻�FALSE
 *
 * 
 * ��4����Ҫ�������ܣ�
SCNetworkReachabilityFlags�����淵�صĲ�������״̬
���г��õ�״̬�У�
kSCNetworkReachabilityFlagsReachable���ܹ���������
kSCNetworkReachabilityFlagsConnectionRequired���ܹ��������磬�������ȵý������ӹ���
kSCNetworkReachabilityFlagsIsWWAN���ж��Ƿ�ͨ�����������ǵ����ӣ�����EDGE��GPRS����Ŀǰ��3G.��Ҫ������ͨ��WiFi�����ӡ�

*/

@implementation NetReachability
//���ӳɹ�֮��Ļص�����
static void _ReachabilityCallBack(SCNetworkReachabilityRef target, SCNetworkConnectionFlags flags, void* info)
{
	NSAutoreleasePool*		pool = [NSAutoreleasePool new];
	NetReachability*		self = (NetReachability*)info;
	
	[self->_delegate reachabilityDidUpdate:self reachable:(IS_REACHABLE(flags) ? YES : NO) usingCell:(IS_CELL(flags) ? YES : NO)];
	
	[pool release];
}

@synthesize delegate=_delegate;

/*
This will consume a reference of "reachability"   �⽫ʹ��һ���ɴ��Ե�������Ϊ����
*/
- (id) _initWithNetworkReachability:(SCNetworkReachabilityRef)reachability
{
	if(reachability == NULL) {
		[self release];
		return nil;
	}
	
	if((self = [super init])) {
		_runLoop = [[NSRunLoop currentRunLoop] retain];
		_netReachability = (void*)reachability;   //����ɴ��Ե�����
	}
	
	return self;
}
//������ad hoc��������һ���������ͨ���շ��豸���ƶ��ڵ���ɣ���������ʱ�������ĵ�����ϵͳ��
//��Ad-Hoc�� ԭ����ָ ���ض��ģ�һ���Եġ�������רָ������ģ����ɵġ����ԡ�����������г��˸��ݲ��������Ͳ���˵������в����⣬����Ҫ�����������(Ad-hoc testing)����Ҫ�Ǹ��ݲ����ߵľ����������й��ܺ����ܳ�顣
- (id) initWithDefaultRoute:(BOOL)ignoresAdHocWiFi
{
   /// /ע��:INADDR_ANY��IN_LINKLOCALNETNUM������Ϊһ���������ֽڳ���,��������Ӧ���ֽڽ���,���ǰ������ֽ���ת���������ֽ���
	return [self initWithIPv4Address:(htonl(ignoresAdHocWiFi ? INADDR_ANY : IN_LINKLOCALNETNUM))]; //NOTE: INADDR_ANY and IN_LINKLOCALNETNUM are defined as a host-endian constants, so they should be byte swapped
}
//��������ʾ��ַ�Ľṹ��
- (id) initWithAddress:(const struct sockaddr*)address
{
	return [self _initWithNetworkReachability:(address ? SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, address) : NULL)];
}
//��������ַ��ֵ��INADDR_ANY��ʾ����������õ�ַ
//INADDR_ANY����ָ����ַΪ0.0.0.0�ĵ�ַ,�����ַ��ʵ�ϱ�ʾ��ȷ����ַ,�����е�ַ�����������ַ���� һ����˵���ڸ���ϵͳ�о������Ϊ0ֵ��
- (id) initWithIPv4Address:(UInt32)address
{
	struct sockaddr_in				ipAddress;
	
	bzero(&ipAddress, sizeof(ipAddress));
	ipAddress.sin_len = sizeof(ipAddress);
	ipAddress.sin_family = AF_INET;
	ipAddress.sin_addr.s_addr = address;
	
	return [self initWithAddress:(struct sockaddr*)&ipAddress];
}

//��һ����ַȥ��֤�ɴ���
- (id) initWithHostName:(NSString*)name
{
	return [self _initWithNetworkReachability:([name length] ? SCNetworkReachabilityCreateWithName(kCFAllocatorDefault, [name UTF8String]) : NULL)];
}

- (void) dealloc
{
	[self setDelegate:nil];
	
	[_runLoop release];
	if(_netReachability)
	CFRelease(_netReachability); //�Ƿ����ӵ�����
	 
	[super dealloc];
}
//�����Ƿ������������ YESΪ����
- (BOOL) isReachable
{
	SCNetworkConnectionFlags		flags;
	
	return (SCNetworkReachabilityGetFlags(_netReachability, &flags) && IS_REACHABLE(flags) ? YES : NO);
}
//�����Ƿ�ͨ���������ӣ�����EDGE��GPRS����Ŀǰ��3G����������WIFI
- (BOOL) isUsingCell
{
	SCNetworkConnectionFlags		flags;
	
	return (SCNetworkReachabilityGetFlags(_netReachability, &flags) && IS_CELL(flags) ? YES : NO);
}
//����ί�У�������ί�����е��ûص�����
- (void) setDelegate:(id<NetReachabilityDelegate>)delegate
{
	SCNetworkReachabilityContext	context = {0, self, NULL, NULL, NULL};
	
	if(delegate && !_delegate) {
		if(SCNetworkReachabilitySetCallback(_netReachability, _ReachabilityCallBack, &context)) {
			if(!SCNetworkReachabilityScheduleWithRunLoop(_netReachability, [_runLoop getCFRunLoop], kCFRunLoopCommonModes)) {
				SCNetworkReachabilitySetCallback(_netReachability, NULL, NULL);
				delegate = nil;
			}
		}
		else
		delegate = nil;
		if(delegate == nil)
		REPORT_ERROR(@"Failed installing SCNetworkReachability callback on runloop %p", _runLoop);
	}
	else if(!delegate && _delegate) {
		SCNetworkReachabilityUnscheduleFromRunLoop(_netReachability, [_runLoop getCFRunLoop], kCFRunLoopCommonModes);
		SCNetworkReachabilitySetCallback(_netReachability, NULL, NULL);
	}
	
	_delegate = delegate;
}

- (NSString*) description
{
	return [NSString stringWithFormat:@"<%@ = 0x%08X | reachable = %i>", [self class], (long)self, [self isReachable]];
}

@end
