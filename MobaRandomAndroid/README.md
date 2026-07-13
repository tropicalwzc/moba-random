# MOBA 分组助手（Android）

`moba-random.html` 的原生 Android 版本，支持 Android 11（API 30）及以上版本。

## 运行

1. 使用 Android Studio 打开 `MobaRandomAndroid` 文件夹。
2. 等待 Gradle 同步完成。
3. 选择 Android 11 或更新版本的模拟器/设备并运行 `app`。

也可以在此目录运行：

```bash
./gradlew test assembleDebug
```

生成的调试 APK 位于 `app/build/outputs/apk/debug/app-debug.apk`。

## 特性

- 原生 Material 3 手机与平板布局，支持深色模式
- 自定义角色池自动本地保存
- 与网页及 iOS 版一致的 Mulberry32 时间戳随机算法
- 上一局角色抽取权重降至其他角色的 1/10
- 普通模式角色不重复；镜像模式允许相同角色
- 动态玩家编号、结果复制、触觉反馈和格式错误提示
- 完全离线；Manifest 不声明 `android.permission.INTERNET`

应用启动图标来自各 `mipmap-*` 资源目录；用于商店发布的 512×512 图标保存在 `artwork/playstore-icon.png`。
