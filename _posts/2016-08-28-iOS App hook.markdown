---
layout:     post		
title:      "iOS App hook"		
date:       2016-08-28	
author:     "KingXt"		
tags:
    - iOS
---

---
Hook app前需要一台越狱手机，越狱手机要装上OpenSSH
整体步骤如下：
> 1. [Clutch](https://github.com/KJCracks/Clutch)给Hook的App砸壳
> 2. 安装[Reveal](http://revealapp.com/)，分析App结构
> 2. 用[class-dump](https://github.com/nygard/class-dump)或者[Hopper](http://www.hopper.com/)分析App，[IDA](https://www.hex-rays.com/index.shtml)更加专业。
> 3. 用[theos](https://github.com/theos/theos) hook app


#### 1 给App砸壳
可以在[这里](https://github.com/KJCracks/Clutch/releases)下载一个可执行的clutch，下载好后将clutch放在手机/usr/bin/目录下，导入时候要输手机密码，这个密码不是手机密码也不是电脑密码，如果没有改过，初始密码是alpine
```shell
scp /path/to/Clutch root@<your.device.ip>:/usr/bin/
```
或者通过pp助手import进去也可以。
然后通过openssh连接到手机执行下面操作：
```shell
➜  / ssh root@192.168.1.103
a-iPhone:~ root# clutch -i
Installed apps:
1:   腾讯新闻-头条新闻热点资讯掌上阅读软件 <com.tencent.info>
2:   支付宝 - 口碑 生活 理财 钱包 <com.alipay.iphoneclient>
3:  WeChat <com.tencent.xin>

a-iPhone:~ root# clutch -d com.tencent.xin

com.tencent.xin contains watchOS 2 compatible application. It is not possible to dump watchOS 2 apps with Clutch 2.0.4 at this moment.
Zipping WeChat.app
ASLR slide: 0x100030000
Dumping <WeChatShareExtensionNew> (arm64)
Patched cryptid (64bit segment)
Writing new checksum
ASLR slide: 0x1000ec000
Dumping <WeChat> (arm64)
Patched cryptid (64bit segment)
Zipping WeChatShareExtensionNew.appex
Writing new checksum
DONE: /private/var/mobile/Documents/Dumped/com.tencent.xin-iOS7.0-(Clutch-2.0.4).ipa
Finished dumping com.tencent.xin in 29.8 seconds

```

可以通过PP助手提取出砸过壳的ipa，类似上面的/private/var/mobile/Documents/Dumped/com.tencent.xin-iOS7.0-(Clutch-2.0.4).ipa位置。

#### 2 Reveal 分析app
这个步骤要完成的是你要干什么事，通过reveal你可以查看某个页面具体viewcontroller名字。
在Cydia里面下载一个叫做Reveal load 工具，在设置面板里面就可以打开想要reveal的app

#### 3 class-dump提取header文件
这个很简单，将ipa后缀改成zip，解压文件，在Payload目录下面执行class-dump
```shell
➜  Payload ./class-dump -H -o ./Headers WeChat.app 
```
在当前目录下面会有一个Headers文件夹，里面是app里面的所有头文件。

#### 4 用theos hook app
关键部分在这里，首先得安装theos。
建议mac电脑里面安装[brew](http://brew.sh/), 执行下面命令安装
```shell
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
```
然后安装[这个文章](https://github.com/theos/theos/wiki/Installation)安装theos。

```shell
➜  crack export THEOS=/opt/theos/
➜  crack $THEOS/bin/nic.pl
NIC 2.0 - New Instance Creator
------------------------------
  [1.] iphone/activator_event
  [2.] iphone/application_modern
  [3.] iphone/cydget
  [4.] iphone/flipswitch_switch
  [5.] iphone/framework
  [6.] iphone/ios7_notification_center_widget
  [7.] iphone/library
  [8.] iphone/notification_center_widget
  [9.] iphone/preference_bundle_modern
  [10.] iphone/tool
  [11.] iphone/tweak
  [12.] iphone/xpc_service
Choose a Template (required): 11
Project Name (required): hookwechat
Package Name [com.yourcompany.hookwechat]: com.mycompany.hookwecht
Author/Maintainer Name [XXX]: tester
[iphone/tweak] MobileSubstrate Bundle filter [com.apple.springboard]: com.tencent.xin
[iphone/tweak] List of applications to terminate upon installation (space-separated, '-' for none) [SpringBoard]: 
Instantiating iphone/tweak in hookwechat/...
Done.
```
MobileSubstrate Bundle filter  这个命令后面选择你要hook app的bundle id。
按照上面步骤操作后，在执行命令目录下面会有一个hookwechat目录，目录下面有四个文件，
分别是control, hookwechat.plist, Makefile, Tweak.xm。

修改Makefile如下

```shell
export THEOS=/opt/theos
#手机ip
THEOS_DEVICE_IP = 192.168.1.111 
include $(THEOS)/makefiles/common.mk
#hook时候如果用到了UIKit需要导入这个framework
WelcomeWagon_FRAMEWORKS = UIKit
TWEAK_NAME = newhook
newhook_FILES = Tweak.xm

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"
```

tweak.xm 默认文本如下

```objc
/* How to Hook with Logos
Hooks are written with syntax similar to that of an Objective-C @implementation.
You don't need to #include <substrate.h>, it will be done automatically, as will
the generation of a class list and an automatic constructor.

%hook ClassName

// Hooking a class method
+ (id)sharedInstance {
	return %orig;
}

// Hooking an instance method with an argument.
- (void)messageName:(int)argument {
	%log; // Write a message about this call, including its class, name and arguments, to the system log.

	%orig; // Call through to the original function with its original arguments.
	%orig(nil); // Call through to the original function with a custom argument.

	// If you use %orig(), you MUST supply all arguments (except for self and _cmd, the automatically generated ones.)
}

// Hooking an instance method with no arguments.
- (id)noArguments {
	%log;
	id awesome = %orig;
	[awesome doSomethingElse];

	return awesome;
}

// Always make sure you clean up after yourself; Not doing so could have grave consequences!
%end
*/
```
这个文件要从头到尾看看，里面有hook语法。

```objc
%hook XXXViewController

%new
- (void)clickGreat {
	UIButton *_btn = MSHookIvar<id>(self, "_button");
	if (!_btn.isHidden) {
		[_btn sendActionsForControlEvents:UIControlEventTouchUpInside];
	}
}

%end



%hook FoundObtainViewController

- (void)viewDidLoad {
	%orig;
	[[UIApplication sharedApplication] setIdleTimerDisabled:YES];
	[self performSelector:@selector(clickGreat)];
}

%end

%hook FoundObtainViewController

-(void)viewDidDisappear:(BOOL)animated {
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
}

%end
```

%new 给类添加一个方法。具体语法规则可以查看[theos wiki](https://github.com/theos/theos/wiki)文档。

MSHookIvar 的作用是获取类总ivar变量，具体定义可以看theos里面substrate.h文件。
如果需求很复杂，写起来还是蛮头疼的。写好后可以 执行make命令测试下有没有语法错误。没有语法错误可以执行make package会在目录下面生成一个packages目录，里面有deb补丁包，然后通过make package install 安装到越狱机器上。
