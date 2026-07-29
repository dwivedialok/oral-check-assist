# Web Icon and PWA Manifest Setup

## Current Status

✅ **Icons exist**: `web/icons/` directory has all required PWA icons
✅ **Manifest configured**: `web/manifest.json` is properly set up for PWA
✅ **Icon generation**: `flutter_launcher_icons` now configured to generate web icons

## Changes Made

### 1. Updated `pubspec.yaml`
- Added `web: true` to `flutter_launcher_icons` configuration
- This will generate web icons from `assets/app_icon.png` when you run:
  ```bash
  flutter pub run flutter_launcher_icons
  ```

### 2. Updated `web/manifest.json`
- ✅ Updated description to use "initial visual check" instead of "screening"
- ✅ Added `scope: "/"` for proper PWA scope
- ✅ Changed `start_url` from "." to "/" (more explicit)
- ✅ Added `categories: ["health", "medical"]` for app store categorization
- ✅ Updated `short_name` to "Oral Check" (shorter for home screen)

### 3. Updated `web/index.html`
- ✅ Updated meta description to match new terminology
- ✅ Updated title to "Oral Check Assist"
- ✅ Added `viewport` meta tag for responsive design
- ✅ Enhanced iOS PWA meta tags
- ✅ Added multiple apple-touch-icon sizes

## Regenerating Icons from app_icon.png

To regenerate web icons from your `assets/app_icon.png`:

```bash
# Generate icons for all platforms (Android, iOS, Web)
flutter pub run flutter_launcher_icons
```

This will:
- Generate Android icons
- Generate iOS icons  
- Generate web icons (192x192, 512x512, maskable versions) in `web/icons/`
- Update `web/manifest.json` if needed

## PWA Manifest Fields Explained

| Field | Value | Purpose |
|-------|-------|---------|
| `name` | "Oral Check Assist" | Full app name shown in install prompt |
| `short_name` | "Oral Check" | Short name for home screen (limited space) |
| `start_url` | "/" | Where PWA starts when launched |
| `scope` | "/" | What URLs the PWA controls |
| `display` | "standalone" | Hides browser UI when installed |
| `background_color` | "#0175C2" | Splash screen background color |
| `theme_color` | "#0175C2" | Browser theme color |
| `orientation` | "portrait-primary" | Preferred orientation |
| `categories` | ["health", "medical"] | App store categorization |

## Icon Requirements

PWA requires these icon sizes:
- **192x192**: Standard icon (required)
- **512x512**: Large icon for splash screen (required)
- **Maskable icons**: Icons that work with adaptive icons (recommended)

All icons are already in `web/icons/` directory.

## Testing PWA

1. **Build for web**:
   ```bash
   flutter build web --release
   ```

2. **Test locally**:
   ```bash
   cd build/web
   python3 -m http.server 8000
   # Visit http://localhost:8000
   ```

3. **Check manifest**:
   - Open DevTools → Application → Manifest
   - Verify all icons load correctly
   - Check for any warnings

4. **Test install**:
   - Chrome: Look for install prompt in address bar
   - Mobile: "Add to Home Screen" option

## Next Steps

1. **Regenerate icons** (if you want to update from app_icon.png):
   ```bash
   flutter pub run flutter_launcher_icons
   ```

2. **Build and test**:
   ```bash
   flutter build web --release
   ```

3. **Deploy to Firebase**:
   ```bash
   firebase deploy --only hosting
   ```

The PWA manifest is now properly configured with updated terminology and all necessary fields for a complete PWA experience!
