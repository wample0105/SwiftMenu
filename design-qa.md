# 设置窗口正方形比例 Design QA

- source visual truth path: `/var/folders/_b/yb2vvpmn76g4jfx70gr542b80000gn/T/codex-clipboard-7457068e-f47f-4808-8c8f-c1fced64ccb9.png`
- implementation screenshot paths:
  - `/tmp/swiftmenu-square-final-01-general.png`
  - `/tmp/swiftmenu-square-final-02-menu-order.png`
  - `/tmp/swiftmenu-square-final-03-about.png`
- full-view comparison path: `/tmp/swiftmenu-square-window-comparison.png`
- three-tab comparison path: `/tmp/swiftmenu-square-three-tabs.png`
- source viewport: 900 × 450 pt（Retina 1800 × 900 px）
- implementation viewport: 500 × 500 pt（Retina 1000 × 1000 px）
- state: macOS 浅色模式；常规、菜单排序、关于分别选中；关于页无悬浮弹窗

## Full-view comparison evidence

组合对比刻意保留不同视口，因为本次目标就是修正窗口比例。参考图约为 2:1，内部内容仍只有约 500 pt 宽，两侧出现大面积无效留白；实现将窗口固定为 500 × 500 pt，内容宽度、双列设置项和标题栏结构保持不变，两侧空白收敛到正常页面边距。

## Focused comparison evidence

三页并排图用于核对窗口轮廓、标签栏、首个内容基线和完整性：三页均为精确 500 × 500 pt；常规页底部按钮、菜单排序六项与提示、关于页 CTA 与底部链接均完整可见。页面没有横向溢出、文字裁切或异常滚动条，因此不需要额外的局部裁切对比。

## Findings

- 修改前存在 1 个 P2：窗口可被拉到约 900 × 450 pt，而内部内容保持固定宽度，造成明显两侧空白与扁平比例。
- 修改后无 P0、P1、P2 问题。
- 字体与排版：系统字体、字号、字重、行高、层级和换行保持不变。
- 间距与布局节奏：窗口由宽屏改为 500 × 500 pt；页面内部 16/20/16 pt 共享边距和分组节奏保持不变。
- 颜色与视觉令牌：科技蓝、灰阶、分隔线、选中态和原生控件颜色没有变化。
- 图片质量与资源一致性：继续使用同一科技蓝 AppIcon，截图无缩放失真或透明边缘问题。
- 文案与内容：三个标签页的用户可见文案没有变化。
- 可访问性：固定尺寸不会缩小现有控件或点击目标；仅凭截图无法验证键盘焦点顺序和 VoiceOver，但本次未修改控件结构。

## Comparison history

1. 初始参考图：900 × 450 pt 窗口出现大面积两侧空白，记录为 P2。
2. 第一轮实现：内容区 500 × 470 pt，实测最终窗口 500 × 522 pt；比例已改善，但菜单排序列表因增高出现空白条纹行，记录为 P2。
3. 第二轮实现：根据实测标题栏高度将内容区调整为 500 × 448 pt，最终窗口精确为 500 × 500 pt；列表设为 208 pt 后出现滚动条，记录为 P2。
4. 最终实现：菜单排序列表高度调整为 224 pt，六项完整显示且没有空白行或滚动条；三页重新截图后所有 P2 关闭。

## Implementation checklist

- [x] 窗口最终尺寸为 500 × 500 pt。
- [x] 窗口不可横向拉宽，绿色缩放按钮禁用。
- [x] 从旧宽屏恢复状态时自动收缩并居中。
- [x] 三个标签页窗口尺寸和内容边界一致。
- [x] 常规页底部按钮完整可见。
- [x] 菜单排序页没有空白行或异常滚动条。
- [x] 关于页 CTA、链接及悬浮入口保持完整。
- [x] 24 项核心测试、性能门禁、类型检查和 Release 参数链接检查通过。
- [x] App、Finder 扩展、ZIP 和 DMG 的签名与产物验收通过。

## Follow-up polish

无需要阻塞交付的后续项。

final result: passed
