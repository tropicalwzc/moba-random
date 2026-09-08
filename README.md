# MOBA 分组助手

## iOS
[App Store链接](https://apps.apple.com/cn/app/%E9%9A%8F%E6%9C%BA%E6%88%BF%E5%88%86%E7%BB%84%E5%8A%A9%E6%89%8B/id6790402359)

## Android
1. [Github下载](https://github.com/tropicalwzc/moba-random/releases/download/1.0/moba-random_1.01.apk)
或者
2. [百度网盘链接](https://pan.baidu.com/s/1IQLXuHYsIjNuMb8pMzM14w?pwd=sd8n)

## Windows
[下载html在浏览器运行](https://github.com/tropicalwzc/moba-random/blob/main/moba-random.html)

## 功能介绍

- 自定义角色池解析与本地持久化
- 独立分路权重设置页，自动读取自定义角色与分路
- 每个角色使用合计为 100 的非负整数权重；超过 100 时按比例自动归一化
- 新角色默认在其列表分路为 100、其他分路为 0，角色池变化后自动迁移有效设置
- 每次打开权重设置都会重新扫描当前角色池；角色被移动到其他分路时，该角色权重自动重置为新分路 100
- iPad 权重页使用自适应角色卡片网格，横屏空间足够时每行显示 3 个角色
- iOS 权重页支持从剪切板导入、导出带分路顺序的 JSON；导入后按角色最高权重分路立即重建主页角色池
- 导入生成的主页文本统一使用 `职业：角色A、角色B、角色C` 格式
- 新版本首次启动时会一次性导入内置的 `default-role-weights-v1.json` 权重预设并刷新主页角色池；成功后记录迁移标记，不会在后续启动覆盖用户修改
- 毫秒时间戳种子和 Mulberry32 随机算法
- 可选“降低上一轮角色的抽中概率”；开启后自动读取上一轮结果并与分路权重组合计算，无需手填角色
- 默认模式下角色在整场结果中不重复
- 镜像模式允许角色分别在两组出现，但同一组内不重复
- 根据分路数量动态生成并洗牌玩家编号
- 点按结果中的角色可在同一分路随机更换，并高亮标记已更换角色
- 自动保存最近 100 局历史记录；同一局内的角色更换会同步更新记录
- 与网页版一致的复制结果文本格式

## 权重示例

角色 A 设置为“射手 80、中路 20、其他 0”后，会以 `0.8` 加入射手候选权重、以 `0.2` 加入中路候选权重。数值是与同一分路其他角色比较的相对权重，还会受到可选的上一轮自动避让和阵容唯一性约束影响。

若一次编辑后的权重为 `90/20/0/0`，提交输入时会按当前比例自动换算为 `82/18/0/0`，保证仍为整数且总和严格等于 100。

## 验证

```bash
xcodebuild -project MobaRandom.xcodeproj -scheme MobaRandom -destination 'platform=iOS Simulator,name=iPhone 16 Pro' CODE_SIGNING_ALLOWED=NO test
cd MobaRandomAndroid && ./gradlew testDebugUnitTest assembleDebug
node scripts/test_web_weights.js
```
# moba-random
# moba-random
# moba-random
