# OnPlan Brand Kit

A production-oriented brand kit for the OnPlan iOS nutrition and daily-plan app.

## Primary concept

A layered progress ring with a confident checkmark. The ring represents protein progress, hydration, and daily completion without using generic leaf, apple, or medical imagery.

## Included

- App icon styles: full color, light, dark, outline, monochrome
- Alternate app icons: progress ring, plate, today sheet, ring only
- Logos: horizontal, stacked, symbol, app square, dark and white wordmarks
- Brand icons: protein goal, hydration, workout, followed plan, ketosis, weight, notes, saved meals, notifications
- Apple: Xcode AppIcon.appiconset, iPhone sizes, iPad sizes, macOS PNG/ICO/ICNS where supported
- Android: mipmap launcher icons, adaptive foreground/background, Play Store icon and feature graphic
- Marketing: hero, app-store promo, feature cards, social headers/posts/story, splash screen
- Colors: JSON, CSS, Swift tokens, ASE palette, brand guide PDF
- Figma-ready: importable SVG sources

## Important production notes

1. The SVG wordmarks use the font stack `Avenir Next, Inter, Helvetica Neue, Arial, sans-serif`. No font files are bundled. Before a public launch, select and license a final typeface, then outline the wordmark in Figma or Illustrator.
2. iOS icons are opaque and include no transparent corners. Xcode applies the platform mask.
3. The `Figma_Ready` folder contains editable SVGs. A native `.fig` file is not included because Figma's proprietary file format cannot be reliably authored outside Figma; importing these SVGs preserves editable vector layers.
4. These assets are newly created for this kit, but name and trademark clearance still require a proper search before public release.

## Suggested Swift display name

```yaml
PRODUCT_DISPLAY_NAME: OnPlan
```

## Brand colors

- Deep Navy: #071426
- Slate: #1E293B
- Blue: #3B82F6
- Cyan: #18D6E6
- Green: #22C55E
- Lime: #98EC39
- Muted Gray: #64748B
- Light: #F8FAFC

## Tagline

**Stay on plan. One day at a time.**
