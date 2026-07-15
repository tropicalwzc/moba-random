# MOBA 分组助手（SwiftUI）

这是 `moba-random.html` 的原生 SwiftUI 版本，支持 iPhone 和 iPad，最低系统版本为 iOS/iPadOS 18.0。

## iOS
[App store链接](https://apps.apple.com/cn/app/%E9%9A%8F%E6%9C%BA%E6%88%BF%E5%88%86%E7%BB%84%E5%8A%A9%E6%89%8B/id6790402359)

## Android
[Github下载](https://github.com/tropicalwzc/moba-random/releases/download/1.0/moba-random_1.01.apk)

[百度网盘链接](https://pan.baidu.com/s/1IQLXuHYsIjNuMb8pMzM14w?pwd=sd8n)

## 保留的逻辑

- 自定义角色池解析与本地持久化
- 毫秒时间戳种子和 Mulberry32 随机算法
- 上一局角色权重降为普通角色的 1/10
- 默认模式下同一分路的两组角色不重复
- 可选镜像模式，允许两组独立抽到同一角色
- 根据分路数量动态生成并洗牌玩家编号
- 点按结果中的角色可在同一分路随机更换，并高亮标记已更换角色
- 自动保存最近 100 局历史记录；同一局内的角色更换会同步更新记录
- 与网页版一致的复制结果文本格式
