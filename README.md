# LibrarySeatWidget

macOS 菜单栏小组件，用来显示西浦图书馆预约系统里 `SIP Campus` 的剩余座位数量。

## 运行

如果你在终端里运行，先进入项目目录：

```bash
cd /Users/Admin/Documents/library
swift run LibrarySeatWidget
```

也可以生成可双击启动的应用：

```bash
chmod +x Scripts/build_app.sh
Scripts/build_app.sh
open dist/LibrarySeatWidget.app
```

如果想把应用放到桌面：

```bash
Scripts/install_to_desktop.sh
```

首次启动会打开预约系统登录窗口：

```text
https://seatbookings.xjtlu.edu.cn/#/ic/home
```

在窗口里完成学校统一登录后，应用会读取页面中 `SIP Campus` 的楼层座位信息，并把菜单栏标题更新为类似 `SIP 93`。之后应用每 1 分钟自动刷新一次。

## 功能

- 菜单栏显示 SIP Campus 当前剩余座位总数。
- 点开菜单显示各楼层 `Free / Total`。
- 支持手动刷新、重新登录、退出。
- 不保存账号密码，不自动预约座位，不发送通知。

## 说明

应用通过本机 WebKit WebView 保持登录态。登录失效或读取不到数据时，菜单栏会显示 `SIP --`，可以从菜单里选择“重新登录”。
