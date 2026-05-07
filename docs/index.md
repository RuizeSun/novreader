# NovReader 开发文档

此文档位于 `docs/` 目录下，旨在为项目的每个功能模块提供完整、详细的说明。

## 目录 (Table of Contents)

| 模块                                                 | 说明                                                              |
| ---------------------------------------------------- | ----------------------------------------------------------------- |
| [首页 (HomePage)](home_page.md)                      | 展示热门书籍列表，支持下拉加载、刷新以及跳转到详情页              |
| [搜索页 (SearchPage)](search_page.md)                | 关键字搜索小说，展示网格列表                                      |
| [详情页 (SubjectDetailPage)](subject_detail_page.md) | 展示小说的详细信息、评分、标签、人物角色等                        |
| [设置页 (SettingsPage)](settings_page.md)            | 主题色、深色模式切换以及关于信息                                  |
| [登录页 (LoginPage)](login_page.md)                  | Access Token 登录、退出登录                                       |
| [ThemeProvider](theme_provider.md)                   | 主题状态管理、持久化实现                                          |
| [UserProvider](user_provider.md)                     | 登录状态管理、Token 持久化                                        |
| [BangumiService](bangumi_service.md)                 | 与 Bangumi API 的网络交互封装                                     |
| [ApiClient](api_client.md)                           | 基础 HTTP 客户端（封装 `dio`）                                    |
| [TokenHolder](token_holder.md)                       | 全局 Token 存取器                                                 |
| [模型 (Models)](models.md)                           | `Subject`、`User`、`RelatedPerson`、`RelatedCharacter` 等数据结构 |
| [组件 (Widgets)](widgets.md)                         | `SubjectCard`、`SearchBarWidget` 等 UI 组件                       |

每个子文档均包含以下内容：

- **文件概述** – 该文件的职责与在项目中的位置。
- **关键类/函数** – 主要类、方法的签名与作用。
- **页面跳转** – 使用 `Navigator` 的路由调用及目标页面。
- **网络请求** – 调用的 Service 方法、参数、返回值。
- **状态管理** – `Provider`/`Consumer` 的使用方式与数据流向。
- **UI 组件** – 关键 Widget 的属性、回调、交互细节。
- **错误处理 & 加载状态** – `try/catch`、`_isLoading`、`_error` 等状态的处理。
- **示例代码** – 必要时提供简短的使用示例。

文档采用 Markdown 编写，便于在 GitHub、IDE 或文档站点中直接阅读。
