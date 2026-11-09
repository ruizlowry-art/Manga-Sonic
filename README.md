<div align="center">
  <img src="assets/icon/app_icon.png" width="150" alt="Manga Sonic">
  <h1>Manga Sonic</h1>
  <p><strong>A lightning-fast, cross-platform manga reader built with Flutter.</strong></p>
  <p>
    <img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter" alt="Flutter">
    <img src="https://img.shields.io/badge/Platform-iOS%20%7C%20Android%20%7C%20Windows-brightgreen" alt="Platform">
    <img src="https://img.shields.io/github/v/release/Daveruiz1233/MangaSonic?include_prereleases" alt="Release">
  </p>
</div>

---

## Features

### ⚡ Blazing Fast Reader
- **Seamless infinite scrolling** — chapters transition continuously in both directions with zero jitter or repositioning
- **Pixel-perfect position restore** — "Continue Reading" returns to the exact page and scroll position where you left off
- **Aggressive image caching** — pages decode fast enough that even rapid scrolling rarely shows blank placeholders
- **Offline-first** — downloaded chapters bypass all networking, rendering directly from local storage

### 📚 Library & Organization
- **Dynamic Hero Section** — Premium "Recently Read" card with automatic accent color extraction from covers
- **Sleek Grid Design** — Minimalist "Title-on-Cover" layout with gradient overlays
- **Automatic Updates** — Background scanning for new chapters with "NEW" badges
- **Smart Deduplication** — Hero Card manga is intelligently removed from the grid to prevent duplication

### 🚀 Advanced Download Manager
- **Hero-Style Overview** — Grouped chapters using premium interactive Hero Cards
- **Granular Control** — Interactive chapter selection with Select-All and cancellation
- **Parallel Threads** — Up to **3 manga concurrently** with **4 chapters each** (12 threads)
- **Persistence** —Survives app restarts and auto-resumes on network recovery

### 🔎 Supported Sources
| Source | Method |
|--------|--------|
| ManhuaTop | HTML scraping |
| AsuraComic | React Server Component (RSC) payload parsing |
| ManhuaPlus | HTML scraping |

### 🎨 Premium UI/UX
- **Ambient Theming** — Adaptive transparent AppBars and palette-based dynamic UI colors
- **Unified Migration** — Consistent source tagging acrossinfo and migration sheets
- **Pure Dark Mode** — High-contrast AMOLED-friendly interface
- **Deep Controls** — Color filters, brightness, and image adjustments in the reader

---

## Screenshots

<div align="center">
  <img src="assets/screenshots/library.png" width="250" alt="Library">
  &nbsp;&nbsp;&nbsp;
  <img src="assets/screenshots/downloads.png" width="250" alt="Downloads">
  &nbsp;&nbsp;&nbsp;
  <img src="assets/screenshots/sources.png" width="250" alt="Sources">
</div>

---

## Getting Started

### Prerequisites
- Flutter SDK (stable channel, 3.x+)
- Targets: **iOS 15+**, **Android 8+**, **Windows 10+**

### Build & Run
```bash
flutter pub get
flutter run
```

### Release Builds
```bash
flutter build apk --release        # Android
flutter build ios --release         # iOS
flutter build windows --release     # Windows
```

---

## Tech Stack

- **Flutter / Dart** — cross-platform UI
- **Hive** — local key-value storage for library, history, and downloads
- **CachedNetworkImage** — disk + memory image caching
- **CustomScrollView** — center-key bi-directional infinite scrolling for the reader

## License

This project is for personal/educational use.
