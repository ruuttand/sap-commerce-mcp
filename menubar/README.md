# SAP Commerce MCP — macOS Menu Bar App

Native macOS menu bar app for managing the SAP Commerce MCP server without touching the terminal.

## Features

- Switch between SAP Commerce projects
- Rebuild the index with one click
- Monitor index stats (last indexed, class count)
- Start/stop the MCP server for dev/testing
- Persists project list and settings across restarts

## Requirements

- macOS 13+
- Xcode command line tools
- [xcodegen](https://github.com/yonaskolb/XcodeGen)

```bash
brew install xcodegen
```

## Build & Install

```bash
cd menubar
xcodegen generate
xcodebuild -project SAPCommerceMCPManager.xcodeproj \
  -scheme SAPCommerceMCPManager \
  -configuration Release \
  -derivedDataPath build \
  build
cp -R build/Build/Products/Release/SAPCommerceMCPManager.app /Applications/
xattr -cr /Applications/SAPCommerceMCPManager.app
rm -rf build
open /Applications/SAPCommerceMCPManager.app
```

## Releasing a New Version

After making code changes:

```bash
cd menubar

# 1. Regenerate the Xcode project if project.yml changed
xcodegen generate

# 2. Build release
xcodebuild -project SAPCommerceMCPManager.xcodeproj \
  -scheme SAPCommerceMCPManager \
  -configuration Release \
  -derivedDataPath build \
  build

# 3. Quit the running app, replace and relaunch
pkill -f SAPCommerceMCPManager || true
cp -R build/Build/Products/Release/SAPCommerceMCPManager.app /Applications/
xattr -cr /Applications/SAPCommerceMCPManager.app
rm -rf build
open /Applications/SAPCommerceMCPManager.app
```

## First-Time Setup

1. Click the icon in the menu bar
2. Open **Settings…** and set:
   - **Ruby path** — e.g. `~/.rbenv/versions/3.4.7/bin/ruby`
   - **Server binary** — e.g. `/path/to/sap-commerce-mcp/bin/sap-commerce-mcp`
3. **Projects → Add Project…** — select your hybris root folder
4. Click **Rebuild Index** to build the initial index

## Data Files

| File | Purpose |
|------|---------|
| `~/.sap-commerce-mcp/app-config.json` | Projects list, active project, paths |
| `~/.sap-commerce-mcp/active-project` | Current project path (read by the server as fallback) |

## Icon

The app icon and menu bar icon SVG sources are in `menubar/icon.svg` and `menubar/menubar-icon.svg`. To regenerate after editing:

```bash
cd menubar

# Requires librsvg: brew install librsvg
for size in 16 32 64 128 256 512 1024; do
  rsvg-convert -w $size -h $size icon.svg -o AppIcon.iconset/icon_${size}x${size}.png
done
iconutil -c icns AppIcon.iconset -o Resources/AppIcon.icns
```

Then rebuild and reinstall.
