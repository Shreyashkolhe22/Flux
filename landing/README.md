# Flux landing page

A static site (plain HTML, CSS and JS, no build step) for the Flux app.

```
landing/
  index.html     content and structure
  styles.css     theme tokens (same black / white / red as the app), layout, light + dark
  main.js        dot-matrix lettering, theme switch, scroll reveal, live download links
  constellation.js  animated grid background (pointer-reactive canvas, follows the theme)
  assets/        app screenshots, widget, logo, favicon, social image
  vercel.json    caching and security headers
```

## Preview locally

```
npx serve landing
```

Add `?reveal=off` to the address to show every section at once (handy for screenshots).

## Deploy on Vercel

1. Push this repository to GitHub.
2. In Vercel choose **Add New, Project** and import the repository.
3. Set **Root Directory** to `landing`.
4. Set **Framework Preset** to **Other**. Leave the build command and output directory empty.
5. Click **Deploy**.

Every push to `main` then redeploys the site.

## Download buttons

The buttons read the **latest GitHub release** of `Shreyashkolhe22/Flux` in the browser and point to its
`.exe` and `.apk` files, and show the version and file sizes. Until a release exists they link to the
releases page instead. To publish one, create a release on the Releases page and attach `Flux-Setup-x.y.z.exe`,
`Flux-x.y.z-arm64-v8a.apk` and `Flux-x.y.z-armeabi-v7a.apk` (or run the manual workflow in
`.github/workflows/release.yml`).
The file names only need to contain `.exe`, `arm64` + `.apk`, and `armeabi` + `.apk`.

If the repository is renamed or moved, change `REPO` at the top of `main.js` and the GitHub links in `index.html`.

## After the first deploy

Social previews need absolute URLs. In `index.html` change

```
<meta property="og:image" content="assets/og.png">
```

to your full address, for example `https://your-site.vercel.app/assets/og.png`, and add a
`<link rel="canonical" href="https://your-site.vercel.app/">` line.

## Design notes

- Fonts: Inter and Geist Mono from Google Fonts (both open-licensed).
- The dot-matrix lettering is drawn in the browser from a 5 by 7 glyph table, the same one the app uses,
  so there is no font file for it.
- Respects the visitor's light or dark setting, with a System / Light / Dark switch.
- Honours "reduce motion".
- The background is a canvas grid of connected dots that the cursor pushes away. It is drawn by `constellation.js`,
  uses the page colours (the highlight is the red from the theme; set `ACCENT_OVERRIDE` at the top of the file to change it),
  pauses when the tab is hidden, and shows a still grid if the visitor prefers reduced motion.
