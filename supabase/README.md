# 开通 Emma 和 Joey 的云端花园

前端和数据库脚本已经准备好。GitHub Pages 继续托管网页，Supabase 保存账号、学习记录和奖励。数据库尚未创建，因此当前线上仍是本机模式。

## 1. 新建项目

打开 https://supabase.com/dashboard，登录后新建一个项目。项目名可用 `emma-study-garden`，按页面提示设置数据库密码并自己保存；不用把密码发到聊天。可选择距离你们较近的区域。

等待项目创建完成。

## 2. 创建数据库

打开项目的 **SQL Editor → New query**，复制本目录 `setup.sql` 的全部内容，点击 Run。脚本可重复执行，不会清空已有学习记录。

## 3. 创建你们两个账号

进入 **Authentication → Users → Add user / Create user**，分别创建 Emma 和 Joey 的邮箱账号，设置各自的登录密码并确认邮箱状态。密码只在 Supabase 后台和网站登录框中输入。

只用你们两个人的账号即可，网页不开放注册入口。

## 4. 绑定角色

打开 `link-accounts.sql`，将顶部的 `REPLACE_WITH_EMMA_EMAIL` 和 `REPLACE_WITH_JOEY_EMAIL` 改成刚创建的两个账号邮箱。复制到 SQL Editor 运行。

Emma 可记录任务、签到、抽奖、补签、导入本机记录；Joey 可查看、搜索和保存奖励卡。未绑定账号不能读取花园。已经绑定的角色不会被脚本静默替换。

## 5. 提供公开连接配置

在项目设置中找到：

- **Project URL**：形如 `https://你的项目编号.supabase.co`。
- **Publishable key**：通常以 `sb_publishable_` 开头；旧项目也可使用标记为 `anon` 的公开 key。

这两项是网页的公开客户端配置，可以发给我，或填入云环境设置的 `SUPABASE_URL` 与 `SUPABASE_PUBLISHABLE_KEY`。不要使用 `service_role`、`sb_secret_` 或数据库密码：那些是管理员凭证，不能放入网页。

配置齐备后，我会执行构建、发布并验证实际云端同步。为允许这个执行环境验证上线，需要将具体的 `你的项目编号.supabase.co` 和 `joeylqke.github.io` 加入环境网络白名单；浏览器访问网站不依赖此云环境的白名单。

## 6. 发布配置好的页面

在仓库目录执行：

```sh
python3 tools/configure-cloud.py
python3 tools/publish-pages.py
```

配置工具读取上述环境变量，验证只使用公开 key，保存到本机忽略目录 `.garden/cloud-public.json`，构建时注入公开页面。发布工具只上传公开站点，不包含测试工具或数据库管理凭证。

完成后打开 https://joeylqke.github.io/emma-study-garden/。

## 7. 第一次使用与原记录导入

让 Emma 在之前打卡的那台手机浏览器里登录。云端为空且本机有记录时，会出现“导入本机记录”。点一次并确认，之前的学习与抽奖记录就会进入云端。本机原数据保留。不要从 Joey 的浏览器导入之前的测试记录。

Joey 用自己的账号登录，可看到 Emma 的同一份记录。页面每 10 秒同步一次，也可以点击“重新同步”。换手机或电脑时使用同一个账号登录即可。

已有云端记录时，不允许本机记录覆盖它。网络中断时页面会提示尚未确认保存，并暂停新的写入；重新同步会核对原操作，避免重复抽奖。抽奖结果在数据库生成并保存，两个设备不能同时花掉最后一次机会。

云端统一按 `Europe/Berlin` 的日期计算工作日、周末和打卡日，避免两个设备因时区不同产生不同的今日日期。如果你们需要其他时区，可在上线前改 `setup.sql` 的 `garden_today()`，再重新执行。

## 验证情况

已在本地 PostgreSQL 17 验证数据库脚本、账号成员隔离、Joey 只读、任务门槛、周末与补签、抽奖幂等、一次性导入。在浏览器集成验证中，登录服务使用模拟 Auth 传输，数据操作实际经过 PostgreSQL；这不代表新的 Supabase 项目或真实账号已经验证。

开发验证脚本是 `tests/backend.sql` 与 `tests/cloud-browser.cjs`，只用于专门的本地测试容器，不要在云端项目运行这些测试夹具。
