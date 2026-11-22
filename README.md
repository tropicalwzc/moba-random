# MOBA 分组助手

## iOS
[App Store链接](https://apps.apple.com/cn/app/%E9%9A%8F%E6%9C%BA%E6%88%BF%E5%88%86%E7%BB%84%E5%8A%A9%E6%89%8B/id6790402359)

## Android
1. [Github下载](https://github.com/tropicalwzc/moba-random/releases/download/1.2/moba-random_1.2.apk)
或者
2. [百度网盘链接](https://pan.baidu.com/s/5f55dPT_-QQJnCQ8_AMiHTg)

## Windows
[下载html在浏览器运行](https://github.com/tropicalwzc/moba-random/blob/main/moba-random.html)

## 功能介绍

- 自定义角色池解析与本地持久化
- 独立分路权重设置页，自动读取自定义角色与分路
- 每个角色使用合计为 100 的非负整数权重；超过 100 时按比例自动归一化
- 新角色默认在其列表分路为 100、其他分路为 0，角色池变化后自动迁移有效设置
- 每次打开权重设置都会重新扫描当前角色池；角色被移动到其他分路时，该角色权重自动重置为新分路 100
- iPad 权重页使用自适应角色卡片网格，横屏空间足够时每行显示 3 个角色
- iPad 权重输入框采用紧凑尺寸，9.7 英寸横屏下四个标准分路可完整显示；Android 平板按宽度自适应每行 2 或 3 个角色
- iOS 权重页支持从剪切板导入、导出带分路顺序的 JSON；导入后按角色最高权重分路立即重建主页角色池
- 导入生成的主页文本统一使用 `职业：角色A、角色B、角色C` 格式
- 新版本首次启动时，如果没有自定义角色池（或仍是旧版内置默认池），会一次性导入内置的 `default-role-weights-v2.json` 权重预设并刷新主页角色池；已有自定义角色池和权重的升级用户保留原配置，不会被覆盖
- 默认角色池扩展为 34 人（7 射手 / 6 打野 / 8 中路 / 13 战士），内置权重预设同步为同一份名单；新安装和“恢复默认”使用 34 人，升级用户的自定义角色池与权重不会被覆盖，仍是旧版内置默认池的升级用户会升级到 34 人
- Android 1.2 同步支持该一次性预设迁移与剪贴板 JSON 导入/导出；历史记录默认折叠并在生成后保持结果区位置
- 毫秒时间戳种子和 Mulberry32 随机算法
- 可选“降低上一轮角色的抽中概率”；开启后自动读取上一轮结果并与分路权重组合计算，无需手填角色
- 默认模式下角色在整场结果中不重复
- 镜像模式允许角色分别在两组出现，但同一组内不重复
- 根据分路数量动态生成并洗牌玩家编号
- 点按结果中的角色可在同一分路随机更换，并高亮标记已更换角色
- 自动保存最近 100 局历史记录；同一局内的角色更换会同步更新记录
- 与网页版一致的复制结果文本格式

## BO3 全局 BP（iOS）

- 底部新增「BO3」Tab，与「随机」并列；原分组页保持原有行为
- 12 手征召顺序；第 1 局 A 队先手，第 2 局 A/B 全部对调（B 队先禁、先选）；第 3 局可切换为 8 手无 BAN 赛制
- 前序对局已选用角色全局锁定；禁用每局重置；同一局内 BAN/PICK 不重复
- iPhone 竖屏使用紧凑布局：比分栏精简、局数以右上角浮层显示，征召顺序合并进当前手区域，优先保证角色网格高度
- BO3 先胜 2 局；征召完成后判定本局胜者，可重新判定；支持撤销与全局重置
- 系列赛开始时随机分配 1-8 号座位（4/4 分边），并随进度持久化
- 角色池与「随机」页共享；设置页可编辑角色池、队名和第 3 局规则，并显示池健康度
- 内置 131 张角色头像，支持官方名/常用别名、元素色描边和渐变首字兜底
- 系列赛进度自动保存在本机；加载时对非法动作、胜负、座位和未来对局做防御性修复
- App 端本次仅 iOS；参考 HTML `htmls/moba-bo3-draft.html` 已同步第 2 局 A/B 全部对调规则，Android 与 `moba-random.html` 保持现状

## 权重示例

角色 A 设置为“射手 80、中路 20、其他 0”后，会以 `0.8` 加入射手候选权重、以 `0.2` 加入中路候选权重。数值是与同一分路其他角色比较的相对权重，还会受到可选的上一轮自动避让和阵容唯一性约束影响。

若一次编辑后的权重为 `90/20/0/0`，提交输入时会按当前比例自动换算为 `82/18/0/0`，保证仍为整数且总和严格等于 100。

## 验证

```bash
xcodebuild -project MobaRandom.xcodeproj -scheme MobaRandom -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO test
cd MobaRandomAndroid && ./gradlew testDebugUnitTest assembleDebug
node scripts/test_web_weights.js
```

iOS 测试包含 `MobaRandomTests`（分组引擎、分路权重、BO3 规则、存档、预设与头像目录）和 `MobaRandomUITests`（BO3 Tab、开始征召、角色选择、规则/设置/历史 sheet）。
# moba-random
# moba-random
# moba-random
