# 小米遥控器与千问本地验收

## 范围与运行方式

个人分支 `codex/qianwen-remote`，基于上游 `59260d5501e2d6e932966d2f2988c362b784487c`。
仅桥接遥控器音频和按键，不提供语音识别。

音频：小米遥控器麦克风 → SayAll 解码 → SayAll 虚拟麦克风 → 千问 → 当前输入框。
控制：语音键按下/松开 → 右 Command 按下/松开；普通按键沿用自定义映射。

1. 运行本地安装包，安装 App 与虚拟麦克风。当前包仅用于 Apple 芯片、macOS 14 以上的首次安装；已存在 App 或同名驱动时拒绝覆盖。
2. 打开 `/Applications/SayAll.app`，按系统提示授予蓝牙、输入监控和辅助功能权限。权限需要用户本人确认，不能改写系统权限数据库。
3. 向导选择小米遥控器；短按圆盘中间确定键，验证普通按键链路。
4. 音频输出选择 `SayAll`。首次安装使用此名称；既有驱动可能显示 `MiRemoteV 2ch`。
5. 语音工具选择千问。千问设置中启用语音输入法，快捷键设为右 Command，麦克风选择同一虚拟设备。建议关闭「短按也唤起语音输入」。
6. 在向导测试输入框按住遥控器麦克风键说话，松开后检查文字。不得通过手输或粘贴完成语音门禁。
7. 完成向导后，在按键页启用自定义映射。普通键可选择打开 App、聚焦前台输入框和快捷键；语音键只负责说话。先在空白测试窗口验证，避免确认键触发实际发送。

## 必须进行的实机测试

| 用例 | 通过标准 |
| --- | --- |
| 正常语音 | 第一次按住即触发千问，松开结束，首尾文字完整 |
| 小声输入 | 遥控器靠近嘴部、小声说话能够输入；必要时逐步调增益，避免削波 |
| 音频来源 | 千问明确选择 SayAll；遥控器远近变化影响收音，Mac 麦克风不作为输入 |
| 连续语音 | 连续 5 次短句，每次独立，上一句尾音不会混到下一句 |
| 误碰与恢复 | 极短按后没有残留 Command 或持续录音；断连后重新连接能继续输入 |
| 普通按键 | 在测试窗口核对方向键、返回、自定义打开 App/聚焦输入框动作 |
| 配置事务 | 退出未完成的试验恢复原快捷键；成功后重启仍为右 Command |

## 证据与边界

- macOS 系统蓝牙已识别「小米蓝牙语音遥控器」，电量上报 100%，固件 2671。此证据不等于 BLE 音频接通。
- 千问 5.0.7.276 的可见设置确认右 Command 支持短按或按住说话。
- 本地 App 与虚拟音频驱动已编译；安装包展开后的 App/驱动通过 `codesign --verify --deep --strict`。属于 ad-hoc 个人构建，未经过 Apple 公证，不能声称官方签名发布。
- 中英文、浅色/深色的向导截图通过生产渲染入口生成。截图注入设备状态，仅证明布局，不证明真实权限、连接或声音。
- 自动化：原生 SwiftPM 执行 7 个测试套件、179 项全部通过；最后的配置提示文案调整后，配对与本地化 20 项复验通过，涵盖配对、向导、左右修饰键、释放清理与本地化。原 Xcode 构建系统在同步目录中因 FinderInfo 无法签名测试包，已改用非同步 scratch 的原生构建执行。
- 现场语音、按键结果在本节追加；未执行的项目保留未验收。
- 2026-10-28 本机安装已成功；已安装 App/驱动通过签名完整性检查，CoreAudio 已枚举 `SayAll` 输入设备。
- 现场向导观察到真实语音键按下/松开、收到声音、音频输出正常；随后主界面显示「小米蓝牙遥控器 2」已连接，语音触发键为右 Command，自定义按键开启。未记录或上传用户语音内容。
- 千问可见设置已改为麦克风 `SayAll`、右 Command 按住说话，并关闭「短按也唤起语音输入」。
- 当前完整实机验收：**待完成**。上述连接和声音证据不能替代首尾文字完整、低声输入、连续 5 次、断连恢复及普通按键的逐项验证；工作 Mac 尚未测试。

## 从个人 fork 拉取并安装

仓库：<https://github.com/WShawnMing/sayall-qianwen>。改动位于 `codex/qianwen-remote`；`main` 保留上游基线。原仓库的 Releases 和官网安装包不包含这里的千问向导适配。

此安装流程支持 **Apple 芯片 Mac、macOS 14 及以上**；Intel Mac 需要另行构建与验证。源码构建需要完整 Xcode（Swift 6.2 及以上工具链）、Python 3 和 ripgrep（`rg`）。安装 Xcode 后先启动一次完成组件准备，确认 `xcodebuild -version` 和 `xcrun swift --version` 可用；只有 Command Line Tools 不足以构建音频驱动。已有 Homebrew 时可用 `brew install ripgrep` 安装 `rg`。

在终端执行以下命令。源码放在非 iCloud 同步的 `~/Developer` 下，避免 FinderInfo 元数据导致签名失败；若同名目录已经存在，请先核对现有仓库，不要覆盖。

```sh
mkdir -p "$HOME/Developer"
cd "$HOME/Developer"
git clone --single-branch --branch codex/qianwen-remote \
  https://github.com/WShawnMing/sayall-qianwen.git
cd sayall-qianwen
SAYALL_PRIVATE_PLATFORM_MODE=public CONFIGURATION=debug scripts/build-app.sh
scripts/build-doubao-driver.sh
scripts/build-qianwen-local-pkg.sh
open "dist/Install SayAll Qianwen.pkg"
```

这里使用与本机候选验证一致的 debug 配置。脚本中的 SwiftPM 调用已包含 `--disable-keychain`；仅访问公开依赖，不需要上游私有包或 API Key。构建命令本身不会安装或请求管理员权限，最后一步打开安装器，由用户完成系统授权。

安装包只接受首次安装：如果 `/Applications/SayAll.app` 或 `/Library/Audio/Plug-Ins/HAL/MiRemoteV2ch.driver` 已存在，会拒绝覆盖。当前个人电脑已装好，不要重复运行安装器；需要更新时先保留原安装与配置，再安排单独更新。不要为了通过检查删除现有驱动。

迁移时也可直接把个人电脑构建出的 `dist/Install SayAll Qianwen.pkg` 复制到另一台符合条件的 Mac；目标机无需 Xcode。包采用 ad-hoc 签名、未公证；如果系统阻止打开，由用户核对来源后按 macOS 可见提示处理，不关闭 Gatekeeper。安装会短暂重启音频服务。

安装完成后按本文「范围与运行方式」的步骤重新配对并授权，在千问中明确选择 `SayAll` 麦克风。普通按键在 SayAll 的「按键」页配置；「打开 App」「聚焦输入框」和快捷键可用于当前编程界面，具体项目/线程仍按目标 App 的界面选择，本分支没有实现跨 App 的项目/线程列表同步。

后续在此克隆目录更新源码用 `git pull --ff-only`，再重新构建；该命令不会自动安装或覆盖已运行的 App。

## 复现构建

SwiftPM 必须使用 `--disable-keychain`。建议把 scratch 和产物放在非同步目录，避免 File Provider 的 FinderInfo 影响签名。

```sh
SAYALL_PRIVATE_PLATFORM_MODE=public CONFIGURATION=debug scripts/build-app.sh
scripts/build-doubao-driver.sh
scripts/build-qianwen-local-pkg.sh
swift test --disable-keychain --build-system native --scratch-path /private/tmp/sayall-qianwen-tests --filter 'OnboardingVoicePairingPlanTests|VoiceKeyModeTests|OnboardingFlowTests|LocalizationTests'
```

公开构建不需要上游私有仓库。自用安装器单独打包小米所需 App/驱动，省去上游发布安装器要求的私有 Siri helper。安装会重启系统音频服务以加载驱动。
本分支禁止官方更新替换自身；修改版本图标已替换为原创几何麦克风图形，保留上游代码许可证及第三方声明。
移至工作 Mac 后仍需重新配对、授权和选择千问麦克风；不要复制系统权限状态或把本机测试当作工作 Mac 验收。
