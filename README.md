# 仓颉网页版五子棋

这是一个使用华为仓颉语言实现后端的网页版五子棋项目。后端使用 `std.net` 自建轻量 HTTP 服务并托管前端页面，前端提供本地双人、人机对战和局域网联机三种模式。

## 功能

- 本地双人：同一台设备上黑白双方轮流落子。
- 人机对战：玩家执黑，仓颉后端 AI 执白并自动回应。
- 局域网联机：一台设备创建房间，另一台设备在同一局域网访问服务器并输入房间号加入。
- 规则：15x15 棋盘，黑棋先手，无禁手，任意方向连续五枚或更多获胜。

## 目录结构

```text
.
├── cjpm.toml
├── src
│   ├── main.cj       # 程序入口
│   ├── http.cj       # HTTP 服务、API 路由、静态文件托管
│   ├── game.cj       # 棋盘规则、AI、JSON 工具
│   ├── rooms.cj      # 局域网房间状态管理
│   └── game_test.cj  # 单元测试
├── public
│   ├── index.html
│   └── assets
│       ├── app.js
│       └── styles.css
├── PLAN.md
└── REPORT.md
```

## 运行

确认已经安装仓颉 `cjc/cjpm 1.0.5`，在当前目录执行：

```bash
cjpm run
```

启动后访问：

```text
http://localhost:8080
```

局域网联机时，创建房间的电脑保持服务运行，另一台设备访问：

```text
http://创建房间电脑的局域网IP:8080
```

在页面选择“局域网”，一端创建房间，另一端输入房间号加入即可。

## 测试

```bash
cjpm build
cjpm test
```

如果在受限沙箱中运行，`cjpm test` 可能因为仓颉 unittest 运行器需要绑定本地 socket 而报 `Operation not permitted`；在正常终端或允许本地绑定权限后可正常运行。

## API 摘要

- `GET /`：返回游戏页面。
- `GET /assets/...`：返回前端静态资源。
- `POST /api/ai/move`：提交玩家落子并返回 AI 回合后的棋盘。
- `POST /api/rooms`：创建联机房间。
- `POST /api/rooms/{roomId}/join`：加入联机房间。
- `GET /api/rooms/{roomId}`：轮询房间状态。
- `POST /api/rooms/{roomId}/move`：提交联机落子。
- `POST /api/rooms/{roomId}/reset`：重开房间。
