# SwiftMenu Logo 设计规范

方案 3 已确认为 SwiftMenu 正式 Logo。核心图形由光标、三行右键菜单和一枚闪光组成，表达“用户需要时才自然出现的 Finder 增强能力”。

## 视觉规范

| 用途 | 色值 |
|------|------|
| 主背景 | `#2F80ED` |
| 光标与菜单 | `#F7FBFF` |
| 闪光强调 | `#35D6E8` |
| 图标外部 | 透明 |

主背景采用明度更高的清透科技蓝，降低原靛蓝色的厚重感；冰白前景维持清晰对比，浅青闪光提供轻盈、清新的层次。

- 使用纯色扁平风格，不使用渐变、阴影、描边、发光或纹理。
- 圆角底板、光标、菜单和闪光的比例以 `assets/logo.svg` 为唯一母版。
- 小尺寸图标不得删除闪光或菜单行，以保持跨尺寸品牌一致性。
- README 使用 `assets/logo.png`；macOS App Icon 使用 `Sources/SwiftMenu/Assets.xcassets/AppIcon.appiconset/` 中的独立尺寸 PNG。

## 母版与导出

- 矢量母版：`assets/logo.svg`，1024 × 1024 viewBox。
- README 位图：`assets/logo.png`，512 × 512，透明圆角外部。
- macOS 图标：16、32、64、128、256、512、1024 像素完整尺寸集。
