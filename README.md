# eSIM 服务: QuecEsimManagerSdk

## 功能概述

`QuecEsimManagerSdk` 是用于 **eSIM 服务管理与商城接入** 的 iOS SDK。  
通过该 SDK，开发者可以在 App 内快速集成 **eSIM 商城及 eSIM Profile 管理能力**，实现从购买到安装的完整流程。

SDK 主要提供以下功能：

- **eSIM 商城接入**
  - 打开 eSIM H5 商城页面
  - 浏览和购买 eSIM 套餐

- **eSIM Profile 管理**
  - Profile 下载与安装
  - Profile 删除
  - Profile 状态查询

- **eSIM 通信能力**
  - APDU 指令交互
  - eSIM 激活流程处理
  - QR Code 扫码激活

- **用户交互流程**
  - 扫码获取 eSIM 激活码
  - 下载 Profile 确认
  - eSIM 下载过程控制

通过 `QuecEsimManagerSdk`，开发者无需自行处理复杂的 **eSIM 通信协议与激活流程**，即可快速完成 eSIM 服务能力接入。

---

## 集成方式

工程**Podfile**新增source 'https://github.com/thridparty-cloud2/QuecPublicSpecs.git', 使用 **CocoaPods** 集成 SDK：

```ruby
pod 'QuecEsimManagerSdk', '~> 0.0.1'
pod 'QuecPayKit/wechat', "2.0.0"
```

安装完成后执行：
```
pod install --repo-update
```
然后在需要使用的文件中导入 SDK：
```
#import <QuecEsimManagerSdk/QuecEsimManagerSdk.h>
```

### eSim初始化

**接口说明**

打开eSim H5商城页面

```objc
- (void)openStoreFrom:(UIViewController *)fromVC config:(QuecEsimStoreModel *)config;
```

**参数说明**

| 参数         | 是否必传 | 说明               |
|------------|------|------------------|
| fromVC | 是    | 用于展示商城的当前 UIViewController，SDK 会从这个控制器 push 或 present 商城页面              |
| config | 是    | QuecEsimStoreModel 配置对象，包含商城显示风格、eSIM 信息、导航栏样式等           |

**QuecEsimStoreModel属性定义**

| 字段        | 类型                 | 描述      |
|-----------|--------------------|---------|
| eimId  | NSString            | eSIM ID，用于标识用户的 eSIM 服务 |
| eimDomain | NSString | eSIM 服务域名，用于访问商城后台    |
| url | NSString | 自定义商城 URL，如果为空，SDK 使用默认内部 URL    |
| presentStyle | QuecEsimPresentStyle | 打开商城的展示方式：push 或 present   |
| webNavReturnImg | UIImage | 自定义导航栏返回按钮图片    |
| webNavTintColor | NSString | 导航栏控件颜色（返回按钮、右侧按钮），为空则使用系统默认    |
| webNavTitleAttrs | NSString | 导航栏标题文字属性，例如字体、颜色    |
| webNavTitle | NSString | 导航栏标题文字   |
| webNavBackgroundColor | NSString | 导航栏背景颜色    |

**示例代码**

```swift
    import QuecEsimManagerSdk
    let config = QuecEsimStoreModel()
    config.url = "https://****.quectel.com/app/pages/esim/index?companyCode=B9001&entityValue=01&entityType=2&color=1&mode=2&lang=zh"
    config.appKey = "your appKey"
    config.appSecret = "your appSecret"
    config.presentStyle = .push
    if let backImg = UIImage(
        named: "back",
        in: Bundle.main,
        compatibleWith: nil
    ) {
        config.webNavReturnImg = backImg
    }
    config.webNavTitleAttrs = [
        .foregroundColor: UIColor.white,
        .font: UIFont.systemFont(ofSize: 18, weight: .medium)
    ]
    config.webNavTitle = "eSim Store"
    config.webNavBackgroundColor = .red
    config.webNavTintColor = .white
    let manager = QuecEsimManager.shared()
    manager.delegate = self
    manager.openStore(from: self, config: config)
```
### eSIM APDU代理监听

>实现 QuecEsimApduDelegate 代理协议后，SDK 在 eSIM 通信或用户交互过程中会通过回调通知应用层。
开发者需要在对应回调中完成 APDU 指令发送、二维码获取以及下载确认等逻辑。

**QuecEsimApduDelegate**

```objc
@protocol QuecEsimApduDelegate <NSObject>

/// Send APDU command
/// @param channel Logical channel used for APDU communication
/// @param data APDU command data
/// @param completion APDU response callback
- (void)transmitApduWithChannel:(uint8_t)channel
                           data:(NSData *)data
                     completion:(void (^)(NSData *rsp, NSError * _Nullable error))completion;

/// SDK requests a QR code for eSIM activation
/// @param completion Return the scanned QR code string
- (void)onNeedScanQr:(void (^)(NSString * _Nonnull qr))completion;

/// Callback before starting profile download
/// @param completion Return whether the download is allowed to start
- (void)onStartDownloadProfile:(void (^)(BOOL isStart))completion;

@end
```

**示例代码**
```swift
extension QuecEsimTestViewController: QuecEsimApduDelegate {
    func transmitApdu(withChannel channel: UInt8, data: Data, completion: @escaping @Sendable (Data, (any Error)?) -> Void) {
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else {
                completion(Data(), NSError(
                    domain: "com.quectel.apdu",
                    code: -999,
                    userInfo: [NSLocalizedDescriptionKey: "controller released"]
                ))
                return
            }

            do {
                // APDU交互
                let rsp = try await self.transmitApduAsync(
                    channel: channel,
                    data: data
                )
                completion(rsp, nil)

            } catch {
                completion(Data(), error)
            }
        }
    }
    
    @objc
    func onNeedScanQr(_ completion: @escaping (String) -> Void) {
        Task.detached { [weak self] in
            guard let self else {
                completion("")
                return
            }
            let qr = await self.scanQrAsync()
            completion(qr)
        }
    }

    @objc
    func onStartDownloadProfile(_ completion: @escaping (Bool) -> Void) {
        Task.detached {
            // 如果有耗时逻辑
            // await downloadPrepare()
            completion(true)
        }
    }
}
```

### eSIM 跳转微信小程序支付
> 如应用已集成微信支付可忽略以下注册。

为保证 eSIM 场景下能够正常跳转微信小程序并在支付完成后回到 App，需要完成以下配置：

---

#### 1、新增 Associated Domains（通用链接配置）
**配置步骤：**
1. 打开 Xcode，选择 Target → Signing & Capabilities  
2. 点击 “+ Capability”，添加 **Associated Domains**  

#### 2、工程配置 URL Types
**配置步骤：**
1.    打开 Xcode，选择 Target → Info → URL Types
2.    点击 “+” 添加一项
3.    按如下方式填写：
Identifier：建议填写 Bundle Identifier
URL Schemes：填写微信开放平台申请的 AppID

#### 3、QuecPayKit引用

```objc
#import <QuecPayKit/QuecPayKit.h>

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions {
    // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
    // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
    // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
    [self registerWeChat];
}

- (void)registerWeChat {
    [QuecPaymentService.sharedManager registerApp:@"wxAppId" universalLink:@"your universalLink"];
}

- (void)scene:(UIScene *)scene openURLContexts:(NSSet<UIOpenURLContext *> *)URLContexts {
    UIOpenURLContext *context = URLContexts.allObjects.firstObject;
    NSURL *url = context.URL;
    [QuecPaymentService.sharedManager handleOpenURL:url];
}

- (void)scene:(UIScene *)scene continueUserActivity:(NSUserActivity *)userActivity {
    [QuecPaymentService.sharedManager handleOpenUniversalLink:userActivity];
}

```

