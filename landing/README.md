# Flux landing page

A static site (plain HTML, CSS and JS, no build step) for the Flux app.

```
landing/
  index.html     content and structure
  styles.css     theme tokens (same black / white / red as the app), layout, light + dark
  main.js        dot lettering, copy/send/paste scene, sticky phone, theme, live download links
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

- Flat black or off-white with hairlines, one red accent, very little decoration.
- Fonts: Doto (round-dot dot-matrix, for headings), Inter and Geist Mono, all open-licensed, from Google Fonts.
- The big FLUX lettering is drawn in the browser from the same 5 by 7 glyph table the app uses.
- The copy / send / paste animation in section 01 is a small SVG timeline in `main.js`.
- The phone in section 02 is sticky and changes screen as you scroll the feature list.
- Respects the visitor's light or dark setting, with an AUTO / LIGHT / DARK button, and honours "reduce motion".
