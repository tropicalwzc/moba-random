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
- 独立分路权重页面，自动读取角色池并保存每个角色合计为 100 的整数权重
- 打开权重设置时重新扫描当前输入；角色移动到其他分路后自动重置为新分路 100
- 权重总和超过 100 时按当前比例自动换算，并以最大余数法保证整数总和为 100
- 与网页及 iOS 版一致的 Mulberry32 时间戳随机算法
- 可选“降低上一轮角色的抽中概率”；开启后自动读取上一轮结果并与分路权重组合计算，无需手填角色
- 普通模式全局角色不重复；镜像模式允许跨组重复但保持组内唯一
- 点按结果中的角色可在同一分路随机更换，并高亮标记已更换角色
- 自动保存最近 100 局历史记录；同一局内的角色更换会同步更新记录
- 动态玩家编号、结果复制、触觉反馈和格式错误提示
- 完全离线；Manifest 不声明 `android.permission.INTERNET`

应用启动图标来自各 `mipmap-*` 资源目录；用于商店发布的 512×512 图标保存在 `artwork/playstore-icon.png`。
