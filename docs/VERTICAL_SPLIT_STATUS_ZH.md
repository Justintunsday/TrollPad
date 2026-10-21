# TrollPad 上下分屏开发状态

以 Justintunsday/TrollPad 为底包，基线提交 `3a841b3aa26d96df2acbcdb129dcfddf69a62b06`。新增代码编入 TrollPadSB，复用底包的 Medusa、Dock 和应用侧能力。商业 DEB、反汇编、设备隐私报告不进入仓库。

## 已取得的证据

- 独立 C 几何通过 17,560 组窗格测试，涵盖非零原点、间隙、最小高度、1/3～2/3 限制、非法输入和横屏退回。
- vertical1、vertical2 经 GitHub Actions/macOS 编译，通过 Rootless 包检查，包含 arm64 和 arm64e。
- 已经用户授权，通过 SSH 在 iPhone SE 2（iPhone12,8）、iOS 16.1.1（20B101）、Dopamine/ElleKit 上进行受控实验。
- 旧版 `SBMainDisplaySceneLayoutViewController` 在目标系统不存在。实际 Scene 布局入口为 `SBDisplayItemLayoutAttributesCalculator` 的 `frameForLayoutRole:inAppLayout:containerOrientation:windowScene:`。
- 宿主布局另经 `SBSwitcherModifier` 的 `frameForLayoutRole:inAppLayout:withBounds:`。实际目标接收者为 `SBSplitViewRootSwitcherModifier`；它继承此方法。仅改变 Scene 计算器不足以同步宿主。
- 通过原生 Split View UIAction 创建 Calculator + Settings 双 App，实际布局有两个 item、role 1 和 2、spaceConfiguration 4；没有手工构造 scene ID 或持久化布局。
- 临时双 Hook 实验获得两个真实前台 Scene 和宿主一致的竖屏区域：375×332.5，第二窗格 y=334.5。Calculator 客户端 UIWindow 也收到 375×332.5 的 bounds。
- 本项目明确将此设备上观察到的 role 1 映射到上方、role 2 到下方；不沿用旧二进制的上下角色假设。

## vertical3 实现与限制

新增默认关闭的 `TPVerticalSplitEnabled` 设置，启动 SpringBoard 时读取。只允许系统 build 20B101，并完整比对两个方法的 Objective-C 类型编码；不匹配则不安装布局 Hook。宿主 Hook 先给目标子类增加自有方法，避免修改继承的基类方法。两个 Hook 先调用原实现，非主线程、非双 App、非主屏、非竖屏或不匹配的 bounds 均退回。

固定布局使用独立几何模块，间隙 2 pt，最小窗格高度 151 pt，比例 50:50。本次封装的编译、安装和用户触控验证需另行记录；此前临时 Frida 实验成功不等于安装包验证完成。

**尚未完成：** 拖动手势与实时 Scene 提交、键盘占用、旋转与锁屏生命周期、全面的触控路由和退出验证。不能视为完成版 FloatingDockPlus 移植。

一次尝试通过 Frida 创建 Block 调用 `requestTransitionWithBuilder:` 刷新比例导致 SpringBoard EXC_BAD_ACCESS，崩溃提示可能涉及 pointer authentication。确切原因尚未证实。该刷新机制没有进入本源码，不再重复执行。后续应验证原生编译的事务路径及其语义。

## 设置和恢复

- “上下分屏诊断”只输出只读元数据，可关闭再打开刷新，报告为 SpringBoard home 下 `Library/Logs/TrollPad/vertical-runtime.json`。
- “启用上下分屏”默认关闭，修改后重启 SpringBoard；此版本没有比例拖动功能。进入原生双 App Split View 后才改变几何。
- 测试前保留 SSH、安装包和独立定时恢复。用户当前重新安装了 vertical2，以其当前可用状态为测试基线；不得按最初“未安装”状态擅自卸载。
- 恢复时关闭 `com.apple.springboard` 域 `TPVerticalSplitEnabled`，重启 SpringBoard。必要时恢复已验证的 vertical2 包。

## 构建

GitHub Actions 使用 macOS/Xcode、Theos、iOS16.5 SDK 构建，保存日志与 SHA256。Windows 几何测试：

```powershell
python scripts/run_tests.py --cc C:\path\zig.exe cc
```

Rootless 编译：`gmake package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless`。编译成功只代表构建通过，不能替代设备验证。
