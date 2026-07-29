# Testing the PWA on a Real Mobile Device

Your goal is **real-world mobile use** (phone browser), not desktop. Here’s how to test that without optimizing for laptop.

---

## 1. Best option: Same Wi‑Fi + web server (no deploy, no domain)

Use your phone’s browser and your laptop’s web server so the PWA runs in a real mobile environment.

### On your Mac/laptop

```bash
# From project root
flutter run -d web-server --web-hostname 0.0.0.0
```

Flutter will print a URL like `http://0.0.0.0:xxxxx` or `http://localhost:xxxxx`.

### Find your laptop’s IP

```bash
# macOS
ipconfig getifaddr en0
# or
ifconfig | grep "inet " | grep -v 127.0.0.1
```

Example: `192.168.1.42`.

### On your phone

1. Connect the phone to the **same Wi‑Fi** as the laptop.
2. In the phone’s browser (Chrome or Safari), open:
   ```text
   http://<YOUR_LAPTOP_IP>:<PORT>
   ```
   Example: `http://192.168.1.42:8080` (use the port Flutter showed).

3. Use the app: camera, gallery, and analysis run in the real mobile browser.

### If the phone can’t connect

- Confirm phone and laptop are on the same Wi‑Fi.
- Temporarily allow the app port through the laptop firewall if needed (e.g. macOS: System Settings → Network → Firewall).
- Try `--web-port 8080` so the port is fixed:
  ```bash
  flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080
  ```
  Then open `http://<LAPTOP_IP>:8080` on the phone.

---

## 2. Deploy once, then test on mobile (closest to production)

If you want a stable URL and HTTPS (e.g. for camera on some networks):

1. Deploy to Firebase Hosting once (see `PWA_QUICK_START.md`).
2. You get a URL like `https://your-project-id.web.app` (no custom domain needed).
3. On your phone, open that URL in Chrome or Safari.
4. Optional: use “Add to Home Screen” so it behaves like an app.

This is the most realistic “real world” test: real mobile browser, real camera, real PWA install.

---

## 3. What to test on the phone

- **Camera**: Take a photo in the app and run analysis.
- **Gallery**: Pick an image from the device and run analysis.
- **Lazy loading**: First run may show “Loading detailed models…”; later runs should not.
- **Portrait / landscape**: Rotate and confirm layout is usable.
- **Add to Home Screen** (optional): From the browser menu, “Add to Home Screen”, then open from the home screen icon.

---

## 4. Don’t rely only on desktop Chrome

- **Chrome DevTools device mode** (responsive/mobile view) only simulates viewport and touch; it does **not** use the phone’s camera or real mobile browser behavior.
- For real-world mobile behavior, test on a **real device** using either:
  - Same Wi‑Fi + `flutter run -d web-server --web-hostname 0.0.0.0`, or  
  - The deployed Firebase Hosting URL on the phone.

---

## 5. Quick reference

| Goal                         | Command / step |
|-----------------------------|----------------|
| Test on phone, no deploy    | `flutter run -d web-server --web-hostname 0.0.0.0` → open `http://<LAPTOP_IP>:<PORT>` on phone |
| Fixed port                  | Add `--web-port 8080` and use port 8080 on phone |
| Production-like test        | Deploy to Firebase once → open `https://….web.app` on phone |
| Desktop-only quick check    | `flutter run -d chrome` (not representative of mobile) |

No domain or Firebase deploy is required for real mobile testing; only for a stable, shareable HTTPS URL.
