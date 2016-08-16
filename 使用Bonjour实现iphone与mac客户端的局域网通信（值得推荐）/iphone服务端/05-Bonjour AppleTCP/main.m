/*
 Erica Sadun, http://ericasadun.com
 iPhone Developer's Cookbook, 3.0 Edition
 BSD License, Use at your own risk
 */

#import <UIKit/UIKit.h>
#import "ModalAlert.h"
#import "NetReachability.h"
#import "TCPServer.h"

#define COOKBOOK_PURPLE_COLOR	[UIColor colorWithRed:0.20392f green:0.19607f blue:0.61176f alpha:1.0f]
#define BARBUTTON(TITLE, SELECTOR) 	[[[UIBarButtonItem alloc] initWithTitle:TITLE style:UIBarButtonItemStylePlain target:self action:SELECTOR] autorelease]

@interface TestBedViewController : UIViewController <UINavigationControllerDelegate, UIImagePickerControllerDelegate, TCPServerDelegate, TCPConnectionDelegate>
{
	UIImage *image;
	TCPServer *server;
}
@property (retain) UIImage *image;
@property (retain) TCPServer *server;
@end

@implementation TestBedViewController
@synthesize image;
@synthesize server;

- (void) baseButtons
{
	self.navigationItem.leftBarButtonItem = BARBUTTON(@"Choose Image", @selector(pickImage:));
	if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera])
		self.navigationItem.rightBarButtonItem = BARBUTTON(@"Camera", @selector(snapImage:));
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
	self.image = [info objectForKey:@"UIImagePickerControllerOriginalImage"];  //选择之后显示照片，测试程序的时候我并没有使用图像选取功能，就是随便拿一张照片
	[(UIImageView *)[self.view viewWithTag:101] setImage:self.image];
	[self dismissModalViewControllerAnimated:YES];
	[picker release];
	[self baseButtons];
}

- (void) imagePickerControllerDidCancel: (UIImagePickerController *)picker
{
	[self dismissModalViewControllerAnimated:YES];
	[picker release];
	[self baseButtons];
}

- (void) requestImageOfType: (NSString *) type
{
	UIImagePickerController *ipc = [[UIImagePickerController alloc] init];
	ipc.sourceType = [type isEqualToString:@"Camera"] ? UIImagePickerControllerSourceTypeCamera : UIImagePickerControllerSourceTypePhotoLibrary;
	ipc.delegate = self;
	ipc.allowsImageEditing = NO;
	[self presentModalViewController:ipc animated:YES];	
}
//点击左键执行的方法
- (void) pickImage: (id) sender
{
	self.navigationItem.leftBarButtonItem = nil;
	self.navigationItem.rightBarButtonItem = nil;
	[self performSelector:@selector(requestImageOfType:) withObject:@"Library" afterDelay:0.5f];
}

- (void) snapImage: (id) sender
{
	self.navigationItem.leftBarButtonItem = nil;
	self.navigationItem.rightBarButtonItem = nil;
	[self performSelector:@selector(requestImageOfType:) withObject:@"Camera" afterDelay:0.5f];
}
//　返回本地主机的标准主机名。 
- (NSString *) hostname
{
	char baseHostName[256]; // Thanks, Gunnar Larisch
	int success = gethostname(baseHostName, 255);
	if (success != 0) return nil;
	baseHostName[255] = '\0';
	return [NSString stringWithCString:baseHostName encoding:NSUTF8StringEncoding];
}
//在父类的AcceptCallBack中调用，表示有连接请求了，询问你是否同意（在TCPServer里的- (void) handleNewConnectionWithSocket:(NSSocketNativeHandle)socket fromRemoteAddress:(const struct sockaddr*)address
//调用的）  TCPServer的委托。
- (BOOL) server:(TCPServer*)server shouldAcceptConnectionFromAddress:(const struct sockaddr*)address
{
	return [ModalAlert ask:@"Accept remote connection?"];
}
//连接之后，连接委托将收到connectionDidOpen回调 这个方法是在TCPConnection中的 _initializeConnection方法中过来的
//连接成功后开始发送数据，TCPConnection的委托
- (void) connectionDidOpen:(TCPConnection*)connection
{
	printf("Connection did open\n");
   //开始发送数据啦。
	if ([connection sendData:UIImageJPEGRepresentation(self.image, 0.75f)])
		printf("Data sent\n");
	[connection invalidate];
}
//连接外部客户端的时候这个方法会调用   - (void) _addConnection:(TCPServerConnection*)connection
//调用的，就是说增加一个connection之后，马上把本类设置为委托
//TCPServer的委托
- (void) server:(TCPServer*)server didOpenConnection:(TCPServerConnection*)connection
{
	[connection setDelegate:self]; //设置主类为委托
}

- (void) viewDidLoad
{   //******************检查是否能够连接网络（已经看懂）***********************
	NetReachability *nr = [[[NetReachability alloc] initWithDefaultRoute:YES] autorelease];
	if (![nr isReachable] || ([nr isReachable] && [nr isUsingCell]))
	{
		[ModalAlert performSelector:@selector(say:) withObject:@"This application requires WiFi. Please enable WiFi in Settings and run this application again." afterDelay:0.5f];
		return;
	}
	//***************检查是否能够连接网络结束**********************
	self.server = [[[TCPServer alloc] initWithPort:0] autorelease];
	//设置本类为TCPServerDelegate的委托，要求本类实现其中的委托的一些方法
    [self.server setDelegate:self]; 
	[self.server startUsingRunLoop:[NSRunLoop currentRunLoop]]; //这个逻辑主要是生成一个socket来监听端口，并加入到运行循环中，并触发serverDidStart方法（显然这里没有实现）
   //[self hostname] 　返回本地主机的标准主机名。 
    //这个方法的逻辑是发布服务
	[self.server enableBonjourWithDomain:@"local" applicationProtocol:@"PictureThrow" name:[self hostname]]; //

	self.navigationController.navigationBar.tintColor = COOKBOOK_PURPLE_COLOR;
	[self baseButtons];
	self.image = [UIImage imageNamed:@"cover320x416.png"];
}
@end

@interface TestBedAppDelegate : NSObject <UIApplicationDelegate>
@end

@implementation TestBedAppDelegate
- (void)applicationDidFinishLaunching:(UIApplication *)application {	
	UIWindow *window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:[[TestBedViewController alloc] init]];
	[window addSubview:nav.view];
	[window makeKeyAndVisible];
}
@end

int main(int argc, char *argv[])
{
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	int retVal = UIApplicationMain(argc, argv, nil, @"TestBedAppDelegate");
	[pool release];
	return retVal;
}
