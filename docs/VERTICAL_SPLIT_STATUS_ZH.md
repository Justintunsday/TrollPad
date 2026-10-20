# TrollPad 上下分屏开发状态

以用户指定的 Justintunsday/TrollPad 为底包，基线提交
`3a841b3aa26d96df2acbcdb129dcfddf69a62b06`。新增模块直接编入 TrollPadSB，
复用原有 Medusa、Dock、设置和应用侧 Hook；不另装一套多任务能力 Hook。

## 已完成的离线开发

- 独立 C 几何：接受宿主坐标下的有效区域（含非零原点），计算上下窗格。
- 支持分隔间隙、最小高度、1/3～2/3 限制、非法输入与横屏退回；失败不改写输出。
- 历史 role=2 允许全宽正请求，role=1 要求小于屏宽；另拒绝负值和非有限值。
  这是旧版证据模型，不代表 iOS16 的角色已确定。
- 设置新增默认关闭的“上下分屏诊断”，读取类、方法完整编码、返回与参数类型、
  是否直接实现、系统版本、编译架构，生成 JSON。不会安装新的布局 Hook。
- GitHub Actions：macOS/Xcode + Theos + iOS16.5 SDK，运行 C 测试、
  构建 Rootless arm64/arm64e 包，保存日志和 SHA256。

## 证据矩阵

| 项目 | 参考证据 | 实现状态 | 缺少的目标设备证据 |
|---|---|---|---|
| 上下角色 | 旧版 ARM64 0x9fb4，role 2 上、role 1 下 | 独立几何和历史守卫模型 | iOS16 实际角色、App Scene、调用链 |
| 拖动范围 | 旧版 0x9cf4–0x9d40 | 约束数学已实现 | 手势到两个 Scene 的真实提交 |
| 刷新 | 旧版 0x9ef0 后调用切换器函数 | 不复制旧刷新机制 | iOS16 scene invalidation 入口 |
| 双 App | TrollPad 原有 Medusa/切换器代码 | 复用底包 | 并存、触控、退出的真机验证 |
| ABI | 旧版 CGRect/CGSize 与整数参数 | 完整分项元数据比较 | iOS16.1.1 签名、arm64e ABI、真实调用路径 |
| 安全区/键盘 | 不可直接使用旧版常数 | 几何接受外部有效区域 | 宿主 bounds、安全区及键盘占用 |

元数据类型匹配不足以证明 Hook 安全。本包未启用新的竖屏布局 Hook；
TrollPad 原有 Hook 仍按底包行为运行。此包不是已经完成的上下双 App 插件。

## 下一步所需的最小真机资料

由用户在有恢复条件的测试设备执行；本次开发不自动 SSH、安装或重启手机。

1. 确认 iOS16.1.1（20B101），记录型号、Dopamine 和 ElleKit 版本。
2. 包加载后在 设置 → TrollPad → 上下分屏研究 打开“上下分屏诊断”。
3. 取回 `/var/mobile/Library/Logs/TrollPad/vertical-runtime.json`。
   实际路径根据 SpringBoard home 生成，并输出在 `[TrollPadVertical]` 日志中。
4. 关闭再打开诊断可刷新报告，无需为此诊断功能额外重启。
5. 记录现有 TrollPad 是否能同时运行两个 App，以及横竖屏和退出行为。

报告只读取元数据，不提供角色实参、调用栈或实时 Scene frame；
这些需要下一阶段受控观察，不能仅凭 JSON 开放布局 Hook。

## 复现构建

```sh
python3 scripts/run_tests.py
export THEOS=/absolute/path/to/theos
gmake clean
gmake package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless
```

Windows 支持 `python scripts/run_tests.py --cc C:\path\zig.exe cc`。
arm64e 使用 macOS/Xcode 构建。保留底包 iOS15 部署下限，研究目标为 iOS16.1.1。
GitHub 输出构建通过也不意味着真机分屏已可用。

参考：[TrollPad 底包](https://github.com/Justintunsday/TrollPad)、
[Theos Rootless 文档](https://theos.dev/docs/rootless)。
商业 DEB、反汇编、历史 ZIP 均不进入此仓库或 Actions 产物。
