# 设置页三个标签布局一致性 Design QA

- source visual truth paths:
  - `/tmp/swiftmenu-audit-01-general.png`
  - `/tmp/swiftmenu-audit-02-menu-order.png`
  - `/tmp/swiftmenu-audit-03-about.png`
- implementation screenshot paths:
  - `/tmp/swiftmenu-layout-after-01-general.png`
  - `/tmp/swiftmenu-layout-after-02-menu-order.png`
  - `/tmp/swiftmenu-layout-after-03-about.png`
- full-view comparison path: `/tmp/swiftmenu-layout-before-after.png`
- focused top-alignment comparison path: `/tmp/swiftmenu-layout-top-alignment.png`
- viewport: 900 × 450 pt（Retina 截图 1800 × 900 px）
- state: macOS 浅色模式；常规、菜单排序、关于分别选中；关于页基础态无悬浮和弹窗

## Full-view comparison evidence

三组相同视口的前后组合对比确认：修改前三页因内容理想高度不同而分别从不同纵向位置开始；修改后三页的第一个主要内容都从同一水平边界和纵向基线开始。窗口尺寸、标签栏、原生控件样式和业务内容保持不变。

## Focused region comparison evidence

顶部聚焦对比确认：常规页品牌栏、菜单排序页标题和关于页品牌栏的左边界一致，顶部基线一致。统一容器提供 20 pt 页面内边距，标签切换时内容不再上下跳动。

## Findings

- 修改前存在 1 个 P2：三个标签页顶部起点约为 10、68、54 pt，页面切换产生明显纵向跳动。
- 修改后无 P0、P1、P2 问题。
- 字体与排版：继续使用 macOS 系统字体，字号、字重、行高和文字层级未改变。
- 间距与布局节奏：三页统一水平 16 pt、顶部 20 pt、底部 16 pt；常规页根级区块间距由 24 pt 收紧为 16 pt，底部按钮完整可见。
- 颜色与视觉令牌：未修改颜色、透明度、分隔线、选中态或控件样式。
- 图片质量与资源一致性：三页继续使用最终科技蓝 AppIcon，没有缩放失真或透明边缘问题。
- 文案与内容：没有新增、删除或改写用户可见文案。

## Comparison history

1. 初始三页截图：确认根视图按理想高度居中导致顶部起点不一致，菜单排序标题还有额外顶部 padding。
2. 第一轮共享 frame：只使用无限 frame 未能让 macOS `TabView` 的三个页面获得相同高度，组合截图仍显示纵向漂移。
3. 第二轮共享容器：使用 `GeometryReader` 固定页面容器为标签页可用尺寸，三个页面顶部对齐。
4. 完整性修复：将常规页根级间距由 24 pt 调整为 16 pt，恢复底部按钮完整显示。
5. 最终截图：常规、菜单排序、关于在同一 900 × 450 pt 视口完成全屏与顶部聚焦对比，原 P2 问题关闭。

## Implementation checklist

- [x] 三页使用同一页面容器和边距令牌。
- [x] 三页首个主要内容顶部与左侧基线一致。
- [x] 常规页底部按钮完整可见。
- [x] 菜单排序列表和底部提示完整可见。
- [x] 关于页三条 CTA 和底部链接完整可见，悬浮交互未改动。
- [x] 同尺寸前后组合对比和顶部聚焦对比通过。
- [x] 24 项核心测试、性能门禁、类型检查和 Release 参数链接检查通过。
- [x] 最终 App 重新构建，签名、ZIP 和 DMG 验收通过。

## Follow-up polish

无需要阻塞交付的后续项。

final result: passed
