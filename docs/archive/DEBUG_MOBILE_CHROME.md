# How to Debug Web App on Android Chrome

## Method 1: USB Debugging (Recommended - Full DevTools Access)

### Step 1: Enable USB Debugging on Android Device

1. **On your Android phone**:
   - Go to **Settings** → **About phone**
   - Tap **Build number** 7 times (you'll see "You are now a developer!")
   - Go back to **Settings** → **System** → **Developer options**
   - Enable **USB debugging**
   - Enable **Stay awake** (optional, keeps screen on while charging)

### Step 2: Connect Phone to Computer

1. **Connect your Android phone to your computer** via USB cable
2. **On your phone**, you'll see a popup: "Allow USB debugging?"
   - Check **"Always allow from this computer"**
   - Tap **"Allow"**

### Step 3: Open Chrome DevTools on Your Computer

1. **On your computer**, open **Chrome browser** (desktop Chrome, not mobile)
2. **Type in the address bar**: `chrome://inspect`
3. You should see your Android device listed under **"Remote devices"**
4. Under your device, you'll see all open Chrome tabs, including your web app

### Step 4: Inspect Your Web App

1. **Find your web app** in the list (it will show the URL, e.g., `https://oral-check-assist.web.app`)
2. Click **"inspect"** next to your web app
3. **A new DevTools window opens** on your computer showing:
   - Console (for error messages)
   - Network tab (for loading issues)
   - Application tab (for storage, service workers)
   - Sources tab (for debugging)

### Step 5: View Console Logs

1. In the DevTools window, click the **"Console"** tab
2. You'll see all `console.log()` messages and errors from your web app
3. Look for:
   - `✅ ONNX Runtime Web WASM initialized successfully`
   - `❌ ONNX Runtime Web WASM initialization failed`
   - `✅ [BinaryEnsemble] Loaded binary_ensemble_mode_1`
   - `❌ [BinaryEnsemble] Failed to load`

---

## Method 2: Remote Debugging via WiFi (No USB Cable Needed)

### Step 1: Enable USB Debugging (Same as Method 1)

### Step 2: Connect via WiFi

1. **On your computer**, open Chrome and go to `chrome://inspect`
2. Click **"Port forwarding..."** button
3. Check **"Enable port forwarding"**
4. **On your Android phone**, go to **Settings** → **Developer options** → **Wireless debugging**
5. Enable **Wireless debugging**
6. Note the IP address and port shown
7. **On your computer**, in Chrome DevTools, add the IP:port

**Note**: This is more complex. Method 1 (USB) is easier for first-time debugging.

---

## Method 3: Simple Console Logging (Easiest - No Setup)

If you can't connect via USB, you can still see console logs directly on your phone:

### Step 1: Use Chrome's Built-in Console

1. **On your Android phone**, open Chrome
2. Open your web app: `https://oral-check-assist.web.app`
3. **Tap the address bar** and type: `javascript:console.log('test')`
4. This won't show you the console, but...

### Step 2: Use a Console Viewer App

1. Install **"Console for Chrome"** or similar app from Play Store
2. Or use **Chrome's remote debugging** (Method 1) - it's the best way

---

## Quick Visual Guide

```
┌─────────────────────────────────────────┐
│  Your Computer (Desktop Chrome)         │
│                                          │
│  1. Open Chrome                         │
│  2. Type: chrome://inspect              │
│  3. See your phone listed               │
│  4. Click "inspect" next to your app    │
│  5. DevTools opens → Console tab        │
└─────────────────────────────────────────┘
              ↕ USB Cable
┌─────────────────────────────────────────┐
│  Your Android Phone                    │
│                                          │
│  1. USB debugging enabled               │
│  2. Web app open in Chrome              │
│  3. Connected to computer               │
└─────────────────────────────────────────┘
```

---

## What You're Looking For in Console

### ✅ Good Signs:
```
✅ ONNX Runtime Web library loaded successfully
✅ ONNX Runtime Web WASM initialized successfully
✅ ONNX Runtime Web configured for mobile compatibility
🔄 [BinaryEnsemble] Loading binary models (lazy)...
✅ [BinaryEnsemble] Loaded binary_ensemble_mode_1
✅ [BinaryEnsemble] Loaded binary_ensemble_mode_2
✅ [BinaryEnsemble] Loaded binary_ensemble_mode_3
```

### ❌ Bad Signs (These indicate the problem):
```
❌ ONNX Runtime Web WASM initialization failed: [error message]
Failed to fetch dynamically imported module: ort-wasm-simd-threaded.mjs
⏱️ [BinaryEnsemble] Timeout loading binary_ensemble_mode_1 (60s)
❌ [BinaryEnsemble] Failed to load binary_ensemble_mode_1: [error]
```

---

## Troubleshooting

### "No devices found" in chrome://inspect

1. **Check USB connection**: Unplug and replug USB cable
2. **Check USB debugging**: Settings → Developer options → USB debugging enabled
3. **Try different USB cable**: Some cables are charge-only
4. **Try different USB port**: Some ports don't support data transfer
5. **Install USB drivers**: Windows may need Android USB drivers

### "inspect" button is grayed out

1. **Check Chrome version**: Update Chrome to latest version
2. **Check Android version**: Older Android versions may not support remote debugging
3. **Try closing and reopening** the web app on your phone

### DevTools opens but console is empty

1. **Refresh the web app** on your phone (pull down to refresh)
2. **Check the Console tab** is selected in DevTools
3. **Try interacting with the app** (take a photo, click analyze) to trigger logs

---

## Alternative: Use Chrome's "Inspect" Feature (Simpler)

If you have Chrome Canary or want to try a different approach:

1. **On your Android phone**, open Chrome
2. Open your web app
3. **Tap the 3-dot menu** (top right)
4. Look for **"Inspect"** or **"Remote debugging"** option
5. This may open DevTools directly (if supported)

**Note**: This feature may not be available in all Chrome versions. Method 1 (USB + chrome://inspect) is the most reliable.

---

## Summary

**Easiest way**:
1. Enable USB debugging on Android
2. Connect phone to computer via USB
3. On computer Chrome, go to `chrome://inspect`
4. Click "inspect" next to your web app
5. View Console tab for error messages

That's it! The DevTools window on your computer will show everything happening in your web app on your phone.
