# Requirements Document

## Introduction

本需求为源坛客户端增加「查看用户」能力：用户点击他人头像后进入该用户的个人中心页，展示公开资料（用户 ID、等级、用户组、人气、关注、粉丝、帖子数量、回帖数量、积分、星币）以及该用户发表的主题列表。点击自己的头像则切换到「我的」Tab。本页与「我的」页分离：「我的」继续承载登录用户的设置与自动化，「个人中心」只展示他人 UID 的公开资料与主题列表。

## Glossary

- **System**：源坛 Flutter 客户端（`ycoo_client`）
- **用户头像**：帖子卡片作者行、帖子详情楼主行、帖子详情回帖行中的圆形头像控件
- **目标用户**：被点击头像所对应的论坛用户，由 UID 唯一标识
- **个人中心页**：展示目标用户公开资料与帖子列表的独立页面（与「我的」页分离）
- **用户 ID**：Discuz UID，正整数
- **等级**：站点个人资料中的等级文案；站点未给出独立等级时，客户端展示用户组名称作为等级
- **用户组**：Discuz 用户组名称（如「大会员」）
- **人气**：目标用户空间访问量（与站点 `space.views` 同源）
- **关注**：目标用户关注人数（`space.following`）
- **粉丝**：目标用户粉丝人数（`space.follower`）
- **帖子数量**：目标用户主题数（`space.threads`）
- **回帖数量**：目标用户回帖数，等于帖子总数减去主题数（`space.posts - space.threads`）；差值为负时按 0 展示
- **积分**：目标用户总积分（`space.credits`）
- **星币**：目标用户星币（按积分类型名称映射的 extcredits）
- **帖子列表**：目标用户发表的主题列表，每条含标题、发布时间、回复数、查看数
- **当前登录用户**：客户端已登录且 Cookie 有效的账号

## Requirements

### Requirement 1: 从头像进入个人中心

**User Story:** AS 浏览帖子的用户, I want 点击用户头像打开该用户的个人中心, so that 我可以查看该用户的公开资料与发帖

#### Acceptance Criteria

1. WHEN 用户点击帖子列表卡片作者行的头像，且该头像对应 UID 为正整数，且该 UID 与当前登录用户 UID 不同，the System SHALL 打开该 UID 的个人中心页
2. WHEN 用户点击帖子详情楼主行的头像，且该头像对应 UID 为正整数，且该 UID 与当前登录用户 UID 不同，the System SHALL 打开该 UID 的个人中心页
3. WHEN 用户点击帖子详情回帖行的头像，且该头像对应 UID 为正整数，且该 UID 与当前登录用户 UID 不同，the System SHALL 打开该 UID 的个人中心页
4. WHEN 用户点击头像对应的 UID 缺失或小于等于 0，the System SHALL 保持当前页面并提示「无法打开该用户资料」
5. WHEN 用户点击头像对应的 UID 等于当前登录用户 UID，the System SHALL 切换到底部导航的「我的」页
6. WHEN 用户点击他人头像进入个人中心，the System SHALL 保持原列表或详情页在导航栈中，以便返回

### Requirement 2: 展示目标用户公开资料

**User Story:** AS 浏览用户的用户, I want 在个人中心看到该用户的标识与社区数据, so that 我能判断该用户的身份与活跃程度

#### Acceptance Criteria

1. WHEN 个人中心页完成资料加载，the System SHALL 在资料区展示目标用户的头像、用户名、用户 ID、等级、用户组、人气、关注、粉丝、帖子数量、回帖数量、积分、星币
2. WHEN 某一资料字段值为空，the System SHALL 对该字段展示占位符「—」
3. WHILE 个人中心页可见，the System SHALL 将资料数字按千分位格式展示（例如 `2,021`）
4. WHEN 用户下拉个人中心页，the System SHALL 重新加载目标用户资料与帖子列表第一页

### Requirement 3: 展示目标用户帖子列表

**User Story:** AS 浏览用户的用户, I want 在个人中心看到该用户发表的主题列表, so that 我可以继续阅读该用户的帖子

#### Acceptance Criteria

1. WHEN 个人中心页完成帖子列表第一页加载，the System SHALL 在资料区下方展示目标用户发表的主题列表
2. WHEN 用户点击帖子列表中的一条主题，the System SHALL 打开该主题的帖子详情页
3. WHEN 帖子列表仍有后续页，且用户滚动到列表底部，the System SHALL 加载下一页并追加到现有列表
4. WHEN 目标用户没有已发表主题，the System SHALL 在列表区展示空态「该用户还没有发表主题」
5. WHEN 帖子列表项渲染完成，the System SHALL 展示主题标题、发布时间、回复数与查看数

### Requirement 4: 加载、失败与无权限

**User Story:** AS 浏览用户的用户, I want 在资料不可用时得到明确反馈, so that 我知道当前无法查看该用户

#### Acceptance Criteria

1. WHILE 个人中心页正在加载资料，the System SHALL 展示加载指示
2. IF 目标用户资料请求失败，the System SHALL 展示错误文案与「重试」操作
3. IF 站点返回该用户不存在或空间不可见，the System SHALL 展示「该用户不存在或空间不可见」
4. IF 帖子列表请求失败且资料已展示，the System SHALL 保留资料区并在列表区展示错误文案与「重试」操作

### Requirement 5: 与现有「我的」页共存

**User Story:** AS 登录用户, I want 「我的」页继续只服务自己的设置, so that 查看他人不会打乱设置入口

#### Acceptance Criteria

1. WHEN 用户通过底部导航打开「我的」，the System SHALL 继续展示当前登录用户的资料卡、自动功能、外观与账号设置
2. WHEN 用户从个人中心页返回，the System SHALL 恢复进入个人中心前的页面状态
3. WHEN 个人中心页展示目标用户资料，the System SHALL 隐藏自动签到、自动回复、外观与退出登录入口
4. WHEN 用户点击自己的头像进入「我的」，the System SHALL 关闭当前帖子详情或个人中心之上的二级路由后再展示「我的」页
