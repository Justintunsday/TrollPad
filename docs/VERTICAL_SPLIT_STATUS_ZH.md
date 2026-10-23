# TrollPad 上下分屏开发状态

以用户指定的 Justintunsday/TrollPad 为底包，基线 `3a841b3aa26d96df2acbcdb129dcfddf69a62b06`。独立新增代码直接编入 TrollPadSB，复用底包 Medusa、Dock、偏好设置及应用侧能力。商业 DEB、反汇编和原始设备报告不进入仓库或 Actions。

## 已取得的真机证据

目标为 iPhone SE 2（iPhone12,8）、iOS 16.1.1（20B101）、Dopamine/ElleKit。已经用户授权通过 SSH 安装、恢复与测试。

- 旧版 `SBMainDisplaySceneLayoutViewController` 在目标系统缺失。实际 Scene 几何入口是 `SBDisplayItemLayoutAttributesCalculator frameForLayoutRole:inAppLayout:containerOrientation:windowScene:`。
- 显示宿主另经 `SBSwitcherModifier frameForLayoutRole:inAppLayout:withBounds:`。实际 Split View 接收者为 `SBSplitViewRootSwitcherModifier`，继承该方法；源码为目标子类先增加自有方法，避免修改整个基类。
- 通过原生 Split View UIAction 建立 Calculator + Settings，实际两个 item、role 1/2、spaceConfiguration 4。不构造 scene ID，不手工改写持久化 AppLayout。
- 本设备明确采用 role 1 上、role 2 下；不把旧版角色映射视作通用常量。
- 原生安装包已取得 Scene 和宿主一致的 375×332.5 上下区域，Calculator 客户端 UIWindow 也收到对应尺寸。用户确认两边显示、触控正常。
- vertical8 的原生事务已成功在 1/3、2/3 间调整两个真实前台 Scene 和宿主：上方 221.5/443.5 pt，下方 443.5/221.5 pt，间隙 2 pt。用户再次确认调整大小后显示、触控仍正常。
- 目前这些证据来自内置 Calculator 与 Settings，不代表所有 App、方向和系统版本都已通过测试。

## 几何和触控区域修正

连续几何通过 17,560 组窗格测试。新增的整数/半点对齐几何通过 20,002 组测试，验证边界、最小高度、间隙、非零原点、非法输入，以及矩形求交后触控条仍精确等于 40 pt。

早期非对齐比例产生 `224.00000000000003` 等坐标尾差，触发 `SBTouchRegionManager` 的内部一致性断言。实际系统比较函数容许的误差极小。对齐后相同方向的原生事务已取得上述真机成功证据。没有屏蔽系统断言或丢弃触控检查。

## 当前源码

- `TPVerticalSplitEnabled`：默认关闭，SpringBoard 启动读取。仅允许 build 20B101，并完整比对关键方法类型编码。
- `TPVerticalDividerEnabled`：默认关闭。vertical9 新增中央拖动把手，预览位置、松手提交；仅把手区域参与 UI hit test，不将窗口设为 key。只有主屏、竖屏、解锁、两个 App 前台且多任务界面关闭时显示。vertical9 曾收到完整开始、移动、结束手势；vertical10 修复逐事件取整丢失慢速位移，已构建安装，但用户仍报告不能跟随。后续读到旧键盘通知标志为真、当前 `UIKeyboardSceneDelegate.showingKeyboard` 为假，把手窗口因此隐藏；尺寸提交接口仍可成功调整到 60%。vertical11 改为查询当前键盘状态，检查两个 getter 的完整类型编码，不再缓存通知布尔值。**此修正及物理拖动仍待安装验证**；键盘弹出、收起及跨 App 的行为也尚未验证完整。
- `TPVerticalPeekEnabled`：默认关闭的过渡预览研究。目标原生第二 App 选择状态已观察到 peekConfiguration 2、spaceConfiguration 4，以及旧的约 45 pt 左侧预览。新增 ABI/ivar 检查后的预览布局 Hook，**尚未完成真机动画验证**。
- `TPHideNativeAffordanceEnabled`：默认关闭，独立于上下分屏开关。按用户要求在全屏、分屏和横竖屏完全隐藏 App 顶部三点按钮；阻止原生创建请求，隐藏已有视图并关闭其交互，同时让专用触控命中路径返回 nil。仅 build 20B101，三个目标 Hook 均检查完整类型编码和类自有方法。关闭开关并重启桌面可恢复。
- `TPVerticalDiagnosticsEnabled`：默认关闭的只读元数据报告，可关闭再打开刷新，位置为 SpringBoard home 下 `Library/Logs/TrollPad/vertical-runtime.json`。
- 原生尺寸事务使用已有活跃 Scene handle 构建实体，由 Apple 编译器生成 ARC Block；不使用手工 Frida Block。研究入口另由 `TPVerticalResizeResearchEnabled` 保护，拖动 UI 启用后可调用同一已验证后端。

所有新功能仍是实验功能；变更功能开关后需重启 SpringBoard。横屏回退原逻辑。尚需完成拖动 UI、过渡动画、键盘、旋转、锁屏、退出，以及更多 App 的生命周期验证。

2026-10-23 继续测试时，设备实际是卸载后仅保留配置记录（`deinstall ok config-files`），已重新安装已校验的 vertical11 并启用测试。用户确认橙色自定义把手可见，但仍无法有效拖动；扩大纵向命中区也未解决。用户指出触控碰到下方 App 的三点按钮并弹出菜单。原生 `hitTestToTopAffordance:window:` 在其 `_SBTopAffordanceView` 已隐藏且禁止交互后仍会返回内部圆点视图，故不能仅靠 `UIView.hidden` 关闭原生命中。

vertical12 完整隐藏功能已通过 Actions `39948203528` 构建、Rootless 双架构检查并安装。全屏 Calculator 及 Calculator + Settings 上下分屏均读到 `_wantsTopAffordance = NO`、`topAffordanceView = nil`、原生命中查询返回 nil。两个分屏 Scene 仍为上方 375×332.5、下方 375×332.5，间隙 2 pt。横屏人工验证尚未完成。

**隐藏三点按钮没有解决拖动问题**，用户仍反馈不跟随；原生分屏状态有窄/宽变化，自定义 pan 未收到该次事件。目前继续隔离 `SBFluidSwitcherGestureManager` 的原生尺寸手势接收路径；不得将隐藏成功或局部研究保护视为拖动修复成功。此前横向位移和手势取消的记录也不足以证明坐标变换错误。

直接投递到自定义窗口上下文的 UIKit 自动拖动已完成开始、纵向移动和结束，比例由 0.5 改为约 0.40255；真实 Scene 更新为上方 267.5 pt、下方 397.5 pt、间隙 2 pt。此测试绕过真实触控路由，只证明自定义手势与原生尺寸事务链路可执行。读取到原生 `SBMainSwitcherWindow._usesWindowServerHitTesting = YES`，旧自定义窗口为 NO。vertical13 据此采用只覆盖 96×36 pt 把手的系统命中窗口，避免让全屏覆盖窗口拦截两个 App；启动前比对该私有 getter 的 `B16@0:8` 编码。

vertical13 已通过 Actions `39950164084`，完成 Rootless 双架构包检查与真机安装。实际窗口大小为 96×36 pt，系统命中开关为 YES，区域外查询返回 nil。自动上拖至约 40:60、下拖至约 60:40 均收到完整 pan；后者两个 Scene 与显示宿主一致为上方 399 pt、下方 266 pt、间隙 2 pt，三点视图和专用命中仍为空。**用户确认 vertical13 真实手指拖动仍不跟随，未修复**。用户也确认此前局部原生尺寸手势接收保护无效；该保护已还原，没有编入 vertical13。继续观察实际输入窗口、命中视图与系统手势，不能把直接 UIKit 合成事件的成功视为物理输入通过。

## 构建与安装

GitHub Actions 使用 macOS/Xcode、Theos、iOS16.5 SDK，先执行 C 测试，再构建 Rootless arm64/arm64e，保存 DEB、日志、工具链版本与 SHA256。PR 分支只跑 pull_request，main 保留 push 构建，避免重复任务。

Rootless 安装脚本使用固定 `/var/jb`，不从 HOME 推导路径。资源链接使用 `ln -sfn`，避免升级时跟随已有目录软链接；修正后的 vertical4 已在手机上连续安装两次成功。原始系统资源不会被改写。

Windows 数学测试：`python scripts/run_tests.py --cc C:\path\zig.exe cc`。

## 仍需保留的风险记录

- Frida 手工构造的过渡 Block 曾出现可能涉及指针认证的崩溃；它没有进入当前实现。
- 一次广泛切换器观察期间出现原生方法缓存路径崩溃，其归因未完全隔离；后续不再使用该基类方法替换作为观察工具。
- 改变全局比例后简单打开、关闭 App Switcher，并不足以保证本系统重新提交两个 Scene 的尺寸。因此当前尺寸提交使用已验证的原生事务，而不是照搬旧刷新调用。
- 固定布局、后端调整尺寸、拖动 UI、动画及生命周期各自是独立验证阶段，不能互相替代成功结论。

## 恢复

安装测试前保留 SSH、旧包和独立定时恢复。当前用户重新安装过 vertical2，不能沿用最初“未安装”的基线擅自卸载。故障时关闭上述布局、分隔条、预览和研究开关后重启 SpringBoard，必要时恢复旧包。完成测试时应核对定时恢复、临时 Frida 服务、端口转发及自动锁屏状态。

动画行为参考和后续路线见 [ANIMATION_APPROACH_ZH.md](ANIMATION_APPROACH_ZH.md)。本项目尚不能宣称完成 FloatingDockPlus 在 iOS16 上的全部移植。
