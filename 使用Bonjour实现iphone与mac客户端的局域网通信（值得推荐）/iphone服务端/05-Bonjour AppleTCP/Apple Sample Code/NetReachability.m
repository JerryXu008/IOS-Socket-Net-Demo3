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
//如果返回YES的话，第一是(__FLAGS__) & kSCNetworkReachabilityFlagsReachable) 也就是要保证状态为能够连接网络   第二是：不是能够连接网络，但是首先得建立连接过程（目前还不明白啥意思）
#define IS_REACHABLE(__FLAGS__) (((__FLAGS__) & kSCNetworkReachabilityFlagsReachable) && !((__FLAGS__) & kSCNetworkReachabilityFlagsConnectionRequired))
#if TARGET_IPHONE_SIMULATOR
#define IS_CELL(__FLAGS__) (0)
#else
//如果返回yes的话，第一是保证状态为连接 第二是是否不是通过WiFi的连接（但这个程序正好是要求用WIFI，所以返回YES的话就提示未连接WIFI）
#define IS_CELL(__FLAGS__) (IS_REACHABLE(__FLAGS__) && ((__FLAGS__) & kSCNetworkReachabilityFlagsIsWWAN))
#endif

//CLASS IMPLEMENTATION:
//SystemConfiguration框架中和测试网络连接状态相关的函数定义在SCNetworkReachability.H文件中
//几个主要方法的解释：
/*
 
 ===================================SCNetworkReachabilityCreateWithAddress 方法解释：
 * 原型：SCNetworkReachabilityRef SCNetworkReachabilityCreateWithAddress (
   CFAllocatorRef allocator,
   const struct sockaddr *address
);

 作用：创建测试连接的引用：
参数一：可以为NULL或kCFAllocatorDefault
 * 参数二：要测试连接的IP地址，当为0.0.0.0时则可以查询本机的网络连接状态
 * 返回值：返回一个引用必须在用完后释放
 
 ==================================SCNetworkReachabilityRef SCNetworkReachabilityCreateWithName 方法解释
 * 原型：SCNetworkReachabilityRef SCNetworkReachabilityCreateWithName (
   CFAllocatorRef allocator,
   const char *nodename
);
参数一：可以为NULL或kCFAllocatorDefault
 参数二：比如为"www.apple.com"，地址名
 * 
 *================================== SCNetworkReachabilityGetFlags 方法解释
 *原型：
Boolean SCNetworkReachabilityGetFlags (
   SCNetworkReachabilityRef target,
   SCNetworkReachabilityFlags *flags
);

 *作用：确定连接的状态：这个函数用来获得测试连接的状态，
 *第一个参数为之前建立的测试连接的引用，第二个参数用来保存获得的状态，如果能获得状态则返回TRUE，否则返回FALSE
 *
 * 
 * （4）主要常量介绍：
SCNetworkReachabilityFlags：保存返回的测试连接状态
其中常用的状态有：
kSCNetworkReachabilityFlagsReachable：能够连接网络
kSCNetworkReachabilityFlagsConnectionRequired：能够连接网络，但是首先得建立连接过程
kSCNetworkReachabilityFlagsIsWWAN：判断是否通过蜂窝网覆盖的连接，比如EDGE，GPRS或者目前的3G.主要是区别通过WiFi的连接。

*/

@implementation NetReachability
//连接成功之后的回调函数
static void _ReachabilityCallBack(SCNetworkReachabilityRef target, SCNetworkConnectionFlags flags, void* info)
{
	NSAutoreleasePool*		pool = [NSAutoreleasePool new];
	NetReachability*		self = (NetReachability*)info;
	
	[self->_delegate reachabilityDidUpdate:self reachable:(IS_REACHABLE(flags) ? YES : NO) usingCell:(IS_CELL(flags) ? YES : NO)];
	
	[pool release];
}

@synthesize delegate=_delegate;

/*
This will consume a reference of "reachability"   这将使用一个可达性的引用作为参数
*/
- (id) _initWithNetworkReachability:(SCNetworkReachabilityRef)reachability
{
	if(reachability == NULL) {
		[self release];
		return nil;
	}
	
	if((self = [super init])) {
		_runLoop = [[NSRunLoop currentRunLoop] retain];
		_netReachability = (void*)reachability;   //保存可达性的引用
	}
	
	return self;
}
//参数：ad hoc网络是有一组带有无线通信收发设备的移动节点组成，多跳，临时与无中心的自治系统。
//“Ad-Hoc” 原意是指 “特定的，一次性的”，这里专指“随机的，自由的”测试。在软件测试中除了根据测试样例和测试说明书进行测试外，还需要进行随机测试(Ad-hoc testing)，主要是根据测试者的经验对软件进行功能和性能抽查。
- (id) initWithDefaultRoute:(BOOL)ignoresAdHocWiFi
{
   /// /注意:INADDR_ANY和IN_LINKLOCALNETNUM被定义为一个主机端字节常量,所以他们应该字节交换,就是把主机字节序转换成网络字节序
	return [self initWithIPv4Address:(htonl(ignoresAdHocWiFi ? INADDR_ANY : IN_LINKLOCALNETNUM))]; //NOTE: INADDR_ANY and IN_LINKLOCALNETNUM are defined as a host-endian constants, so they should be byte swapped
}
//参数：表示地址的结构体
- (id) initWithAddress:(const struct sockaddr*)address
{
	return [self _initWithNetworkReachability:(address ? SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, address) : NULL)];
}
//参数：地址的值，INADDR_ANY表示分配任意可用地址
//INADDR_ANY就是指定地址为0.0.0.0的地址,这个地址事实上表示不确定地址,或“所有地址”、“任意地址”。 一般来说，在各个系统中均定义成为0值。
- (id) initWithIPv4Address:(UInt32)address
{
	struct sockaddr_in				ipAddress;
	
	bzero(&ipAddress, sizeof(ipAddress));
	ipAddress.sin_len = sizeof(ipAddress);
	ipAddress.sin_family = AF_INET;
	ipAddress.sin_addr.s_addr = address;
	
	return [self initWithAddress:(struct sockaddr*)&ipAddress];
}

//用一个网址去验证可达性
- (id) initWithHostName:(NSString*)name
{
	return [self _initWithNetworkReachability:([name length] ? SCNetworkReachabilityCreateWithName(kCFAllocatorDefault, [name UTF8String]) : NULL)];
}

- (void) dealloc
{
	[self setDelegate:nil];
	
	[_runLoop release];
	if(_netReachability)
	CFRelease(_netReachability); //是否连接的引用
	 
	[super dealloc];
}
//返回是否可以连接网络 YES为可以
- (BOOL) isReachable
{
	SCNetworkConnectionFlags		flags;
	
	return (SCNetworkReachabilityGetFlags(_netReachability, &flags) && IS_REACHABLE(flags) ? YES : NO);
}
//返回是否通过蜂窝连接（比如EDGE，GPRS或者目前的3G），而不是WIFI
- (BOOL) isUsingCell
{
	SCNetworkConnectionFlags		flags;
	
	return (SCNetworkReachabilityGetFlags(_netReachability, &flags) && IS_CELL(flags) ? YES : NO);
}
//设置委托，用于在委托类中调用回调函数
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
