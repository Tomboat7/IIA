# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

IIA (iPad Illustration App) is a personal-use illustration app for iPad. This is a **private tool for the developer's own use only** - not intended for App Store distribution or public release.

**Tech Stack:**
- Platform: iPadOS
- Language: Swift
- UI Framework: SwiftUI
- Drawing Framework: PencilKit (Phase 1) / Metal (future consideration)
- IDE: Xcode

## Core Architecture

### Data Model Structure

- `IllustrationDocument`: Represents the entire canvas state (layer array, canvas size, background color)
- `Layer`: Holds drawing content (image/texture) and state (visibility, opacity, blend mode)
- Undo/Redo: Managed at stroke-level as baseline (may simplify based on implementation cost)

### Drawing Implementation

- **Phase 1**: Use PencilKit for basic drawing functionality - prioritize "works normally" state
- **Future phases**: Consider Metal/Core Graphics replacement for advanced features (layers, blend modes) only when needed
- Prioritize readable code over optimization until performance issues arise

### UI/UX Philosophy

- **Primary orientation**: Landscape (power button on left)
- **Do not change layout when switching to portrait** - keep the same layout orientation
- **Usage assumption**: Hold iPad with one hand, use Apple Pencil with the other
- Minimize UI elements to avoid interfering with drawing
- Support gestures (pinch zoom, pan) where feasible

## Development Workflow

### Building and Running

This project uses Xcode with free provisioning (personal Apple ID):

1. Open project in Xcode
2. Connect iPad and enable Developer Mode if needed
3. Configure signing with personal Apple ID (free provisioning)
4. Select iPad as target device
5. Build and run with ▶ button

**Note**: Free provisioning signatures expire after several days to a week. Rebuild/reinstall from Xcode as needed.

### No Xcode Project Yet

The repository currently contains only documentation (README.md, AGENT.md, Docs/UX_Design.md). The Xcode project has not been created yet.

When creating the project structure, follow this directory layout:

```
ProjectRoot
├─ Sources/
│  ├─ Drawing/
│  │  ├─ CanvasView.swift       // PencilKit/Metal drawing
│  │  ├─ BrushSettings.swift    // Brush settings model
│  │  └─ Layer.swift            // Layer model
│  ├─ UI/
│  │  ├─ ToolbarView.swift      // Toolbar (brush/eraser/color/undo/redo)
│  │  └─ LayerListView.swift    // Layer list UI
│  └─ Models/
│     └─ IllustrationDocument.swift // Overall canvas state
├─ Resources/
│  └─ BrushTextures/            // Brush texture images (planned)
```

## Implementation Guidelines

### What to Prioritize

1. **Drawing feel**: Latency and stroke smoothness are top priority
2. **Start small, grow small**: Implement minimal features first
3. **Simple structure**: Keep code easy to replace/refactor later
4. **Build when needed**: Avoid over-engineering, implement only when required
5. **Fully local**: No external service integration

### What NOT to Do (For Now)

- App Store publication
- Distribution to others (including TestFlight)
- Online gallery or SNS integration
- Localization (multiple languages)
- Monetization (ads, subscriptions, IAP)

These are **explicitly not planned**. Reconsider only if needs change.

## Screen Structure

The app has a simple hierarchy to avoid complexity:

1. **Home Screen**: New/continue/import/export/share/timelapse access
2. **Canvas Screen**: Main drawing interface
3. **Canvas Settings Modal**: Size adjustment, etc.
4. **Export/Share Dialog**
5. **Timelapse Playback Screen**

Navigation flow: Home → Canvas → Various modals/sheets

## Security & Privacy

- Image data stays **local only** (app sandbox or user-specified local directories)
- **No internet communication** by default
- If network features are added later, document destination and content in AGENT.md

## Testing Approach

- Target device: Developer's own iPad only
- Key verification points:
  - Drawing latency on high-resolution canvas
  - Memory usage with 10+ layers
  - Undo/Redo responsiveness
- Manual testing is primary; automated tests added if time permits

## Future Considerations

- Metal-based custom brush engine
- Paper texture presets (rough/smooth)
- Layer masks and clipping layers
- Simple animation (frame-by-frame level)
- PSD-compatible export (if needed)

## Development Philosophy

This is a **personal toy/tool**. Enjoyment comes first. Don't aim for perfection - enjoy gradual improvements. When facing performance issues, open Instruments first.
