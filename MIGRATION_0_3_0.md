# 从 0.2.1 升级到 0.3.0

0.3.0 是一次不提供旧 API 兼容层的破坏性升级。建议先替换插件包并修复编译错误，再处理 Session 迁移和平台配置，最后重新构建 Android 与 iOS 产物。

## 1. 初始化与设备信息

0.2.1 要求调用方创建 `SharedCoreDeviceConfiguration`，并通过 `device` 传入部分设备信息：

```dart
final client = await SharedCore.configure(
  SharedCoreConfiguration(
    baseUrl: apiBaseUrl,
    appId: appId,
    device: SharedCoreDeviceConfiguration(
      vpn: vpn,
      hasWxOrQQ: hasWxOrQQ,
      networkOperator: networkOperator,
      simOperator: simOperator,
      templateLanguage: templateLanguage,
      installReferrer: installReferrer,
    ),
    signSecret: signSecret,
  ),
);
```

0.3.0 会在 `SharedCore.configure` 中自动采集平台、Bundle ID/包名、应用版本、设备标识、系统版本、语言、时区、VPN、运营商以及微信/QQ 安装状态。通常只需要传 `appId` 和服务地址：

```dart
final client = await SharedCore.configure(
  SharedCoreConfiguration(
    baseUrl: apiBaseUrl,
    appId: appId,
    signSecret: null,
  ),
);
```

只有 App 明确掌握更准确的数据时才使用 `deviceOverrides`：

```dart
final client = await SharedCore.configure(
  SharedCoreConfiguration(
    baseUrl: apiBaseUrl,
    appId: appId,
    deviceOverrides: SharedCoreDeviceOverrides(
      templateLanguage: selectedTemplateLanguage,
      installReferrer: installReferrer,
    ),
  ),
);
```

对应变化：

- `SharedCoreDeviceConfiguration` 删除，改为可选的 `SharedCoreDeviceOverrides`。
- `hasWxOrQQ` 改名为 `hasWeChatOrQQInstalled`。
- 不再要求调用方传入 `device`。
- `SharedCore` 仍是进程级全局单例；同配置重复调用 `configure` 会返回已有客户端，不同配置会抛出 `SharedCoreLocalError.alreadyConfigured`。
- 原生能力初始化由 `configure` 和 `version` 内部完成，App 不需要单独初始化。

## 2. 配置参数

### 签名密钥

`signSecret` 从默认空字符串改为 `String?`：

- `null`：使用插件内置并保护保存的默认值。
- 非 `null`：严格使用调用方传入的值，包括空字符串。

如果旧项目依赖插件默认签名密钥，升级时使用 `signSecret: null` 或直接省略该参数。

### Endpoint 路径策略

0.3.0 使用 `apiPathMode` 明确选择路径来源：

- `SharedCoreApiPathMode.builtIn`：默认值，使用内置真实路径，忽略 `endpointPaths`。
- `SharedCoreApiPathMode.custom`：使用调用方提供的映射；必须提供全部 21 个 Endpoint。
- `SharedCoreApiPathMode.bundleDerived`：根据运行时 Android 包名或 iOS Bundle ID 派生混淆路径。

旧项目如果只覆盖了少量 Endpoint，不能直接切换到 `custom`。应删除该映射并使用 `builtIn`，或者补齐全部 21 项。

`testServerMode: true` 的优先级最高：它会直接使用内置测试服地址和未混淆的真实路径，忽略生产环境的 `baseUrl`、`apiPathMode` 和自定义路径映射。

### JSON noise

在 `builtIn` 和 `custom` 模式下，`jsonNoisePrefix` 与 `jsonNoiseFieldCount` 仍按调用方传值工作。

在 `bundleDerived` 模式下，这两个配置会被忽略：插件根据 Bundle ID/包名派生 `_xxxxxxxx_` 格式的前缀，并固定处理 20 个 noise 字段。

### HTTP 配置

`proxyHost` 和 `proxyPort` 已删除，代理改为完整 URL：

```dart
SharedCoreConfiguration(
  appId: appId,
  http: const SharedCoreHttpConfiguration(
    proxyUrl: 'http://127.0.0.1:8080',
  ),
)
```

连接超时、响应读取空闲超时和总体请求超时默认均为 60 秒。大多数 App 不需要设置 `http`。

## 3. Session 与登录状态

0.2.1 恢复 Session 时可以同时传 `accessToken`、`userId` 和 `email`：

```dart
await client.setSession(
  accessToken: savedSession.accessToken,
  userId: savedSession.userId,
  email: savedSession.email,
);
```

0.3.0 只接受 token，并自动请求后端补齐账号信息：

```dart
await client.setSession(accessToken: savedAccessToken);
```

需要注意：

- `setSession` 现在会发起网络请求，只有账号刷新成功才算导入完成。
- iOS 继续使用原插件的 `NSUserDefaults` 键；默认 `sessionStorageKeyPrefix: 'SharedCore'` 时可以直接恢复旧 Session。
- Android 0.3.0 改为插件私有 `SharedPreferences` 自动持久化。旧版本的 token 如果保存在 App 自己的任意位置，需要在升级后的第一次启动调用一次 `setSession(accessToken: oldToken)`。
- 此后 `configure` 会自动恢复 Session，登录、绑定、刷新和退出也会自动保存或清理 Session。
- `migrateUserSession` 和 `SharedCoreEndpoint.userMigration` 已彻底删除，没有替代 API。

## 4. 方法迁移

| 0.2.1 | 0.3.0 | 迁移要点 |
|---|---|---|
| `uploadUserDeviceIdentifiers(sdid: ..., idfa: ...)` | `uploadUserDeviceIdentifiers(SharedCoreSingularIdentifiers(...))` | 多个标识改为一个值对象 |
| `exchangeCode(code)` → `Future<Map<String, Object?>>` | `exchangeCode(code)` → `Future<bool>` | 后端 JSON `code == 200` 为 `true`，其他已解析业务码为 `false` |
| `deleteHistoryItemIds(ids)` | `deleteHistoryItems(ids)` | 仅名称调整 |
| `uploadFileResult(path)` | `uploadFile(path)` | 返回值仍是 `SharedCoreUploadResult` |
| `submitVideoTask(...)` | `submitVideoTask(SharedCoreSubmitVideoOptions(...))` | 视频参数统一到值对象 |
| `submitWaveSpeedTask(styleId:, imageURL:)` | `submitImageTaskFromImageUrl(imageUrl:, style:)` | 明确为图生图；裸 `styleId` 改为 `SharedCoreImageStyle` |
| `submitWaveSpeedTaskWithImagePath(styleId:, imagePath:)` | `submitImageTaskFromImagePath(imagePath:, style:)` | 插件内部先上传再提交图生图任务 |
| 四个 Apple/Google 购买与订阅验证方法 | `verifyPurchase(productId:, purchaseData:)` | 自动判断平台和购买类型 |
| `loadSensitiveWordList()` | `loadSensitiveWords()` | 仅名称调整 |
| `migrateUserSession(...)` | 已删除 | 不再提供用户迁移接口 |

分页参数也从可空值改为明确默认值：`page = 1`、`pageSize = 20`，并要求二者大于零。

## 5. 图生图风格

原来的裸数字 `styleId` 改为 `SharedCoreImageStyle`：

| 枚举 | 后端 ID | 风格 |
|---|---:|---|
| `chestModerate` | 1 | Chest — Moderate |
| `chestBusty` | 2 | Chest — Busty |
| `buttCurvy` | 3 | Butt — Curvy |
| `buttThick` | 4 | Butt — Thick |
| `slimWaistTrim` | 5 | Slim Waist — Trim |
| `slimWaistSlim` | 6 | Slim Waist — Slim |
| `absDefineToned` | 7 | Abs Define — Toned |
| `absDefineRipped` | 8 | Abs Define — Ripped |

示例：

```dart
final submission = await client.submitImageTaskFromImagePath(
  imagePath: imagePath,
  style: SharedCoreImageStyle.absDefineToned,
);
```

## 6. 购买验证

0.2.1 由调用方同时判断平台和购买类型，再调用四个不同方法。0.3.0 统一为：

```dart
final result = await client.verifyPurchase(
  productId: purchase.productID,
  purchaseData: platformPurchaseData,
);
```

- iOS 的 `purchaseData` 是 Apple receipt data。
- Android 的 `purchaseData` 是 Google Play purchase token。
- 只有 v2 商品目录 `creditPage.purchaseList` 中的商品按一次性内购验证。
- v2 商品目录中其他已知商品全部按订阅验证。
- 如果尚未加载商品目录，插件会自动加载并缓存。
- 找不到 `productId` 时抛出 `SharedCoreLocalError.purchaseProductNotFound`，不会猜测商品类型。

## 7. 异常处理

0.2.1 的 `code`、`errorCode`、`type`、`errorName`、`businessCode`、`businessReason`、`retryable` 和 `underlying*` 已全部删除。

0.3.0 只区分两种来源：

```dart
try {
  await client.loadHomeContent();
} on SharedCoreException catch (error) {
  if (error.isBackendError) {
    // backendCode 和 message 来自后端业务响应。
    handleBackendError(error.backendCode!, error.message);
  } else {
    // localError 是稳定的本地错误枚举。
    handleLocalError(error.localError!, error.message);
  }
}
```

- 后端错误：`backendCode != null`、`localError == null`。
- 本地错误：`backendCode == null`、`localError != null`。
- `message` 是后端返回的消息或本机诊断信息。
- `httpStatus` 只有在能取得 HTTP 状态码时才非空。
- 没有后端业务包裹的 HTTP 失败归类为 `SharedCoreLocalError.http`。

## 8. Endpoint 枚举迁移

0.3.0 的枚举名与真实 API 路径一致，只省略开头的 `/`：

| 0.2.1（已删除） | 0.3.0 | 实际路径 |
|---|---|---|
| `userMigration` | 无 | `/userMigration` 已移除 |
| `homeData` | `homeDataNew` | `/homeDataNew` |
| `videoHistory` | `videoTaskHistory` | `/videoTaskHistory` |
| `imageHistory` | `userAlbum` | `/userAlbum` |
| `videoTemplates` | `videoList` | `/videoList` |
| `deleteHistory` | `videoDel` | `/videoDel` |
| `submitBodyEnhance` | `submitWaveSpeed` | `/submitWaveSpeed` |
| `purchaseOptions` | `rechargePurchaseListV2` | `/rechargePurchaseListV2` |
| `appleSubscription` | `subscribeApple` | `/subscribeApple` |
| `googleSubscription` | `subscribeGoogle` | `/subscribeGoogle` |
| `uploadUserDeviceIdentifiers` | `updateUserData` | `/updateUserData` |

其他 Endpoint 名称没有变化。`custom` 模式下仍需使用 0.3.0 的全部 21 个枚举成员提供完整映射。

## 9. 数据模型变化

- `SharedCoreReplacementApp.schema` 删除。
- `SharedCoreReplacementApp.hasTarget` 删除。
- `SharedCoreReplacementApp.isEnabled` 只读取后端 `enabled` 或 `newAppEnabled`；字段缺失或无法解析时为 `false`。
- `SharedCorePurchaseVerificationResult.shouldDiscardReceipt` 删除。
- 新增 `SharedCoreSession`，用于读取插件当前持有的完整 Session；调用方恢复 Session 时仍只传 `accessToken`。

## 10. 平台与产物

0.3.0 已整体替换原生实现与二进制分发方式；调用方只需要整体安装插件包，不要单独复制或混用不同版本的原生文件。

支持目标：

- Android `arm64-v8a`
- iOS ARM64 真机
- Apple Silicon Mac 上的 iOS ARM64 模拟器

不再提供 x86、x86_64 或 32 位 ARM 产物。升级后应清理旧构建缓存并重新构建 App。

iOS 如果需要自动检测微信和 QQ，在宿主 App 的 `Info.plist` 中加入：

```xml
<key>LSApplicationQueriesSchemes</key>
<array>
  <string>weixin</string>
  <string>mqq</string>
</array>
```

Android 所需的微信/QQ package visibility queries 已由插件声明。

## 升级验收清单

- [ ] 删除 `SharedCoreDeviceConfiguration`，只在必要时使用 `deviceOverrides`。
- [ ] 明确 `signSecret: null` 的语义。
- [ ] 删除不完整的 `endpointPaths`，或切换到 `custom` 并补齐全部 21 项。
- [ ] 将旧 Session 恢复代码改为只传 `accessToken`。
- [ ] Android 在首次升级启动时导入 App 原来保存的 token。
- [ ] 替换已改名或已删除的方法。
- [ ] 将四个购买验证入口改为 `verifyPurchase`。
- [ ] 将错误处理改为 `backendCode` / `localError` 两路分流。
- [ ] 删除对 `schema`、`hasTarget`、`shouldDiscardReceipt` 的读取。
- [ ] iOS 根据需要补充 `LSApplicationQueriesSchemes`。
- [ ] 确认所有目标设备都是 ARM64，并重新构建 Android/iOS App。
