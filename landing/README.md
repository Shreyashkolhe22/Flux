# Flux landing page

A static site (plain HTML, CSS and JS, no build step) for the Flux app.

```
landing/
  index.html     content and structure
  styles.css     theme tokens (same black / white / red as the app), layout, light + dark
  main.js        dot-matrix lettering, theme switch, scroll reveal, live download links
  footer.js     halftone wordmark footer (giant dotted word that the pointer parts)
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
- The footer prints the word `flux.` as halftone dots (`footer.js`). Move the pointer over it and the dots part and warm in
  colour; click to send a ring through the word. Settings (word, dot gap, push radius, crop, grain) are at the top of the file.
  Links and text are plain HTML in the `<footer id="footer">` block of `index.html`.
- Built mobile-first friendly: on screens up to 980 px the section links move into a full-screen menu (button at the top right),
  the hero buttons become equal full-width buttons, cards tighten up, and the screenshot strip bleeds to the screen edge.
  Checked for horizontal overflow from 280 to 1280 px wide. Hover effects are switched off on touch screens.
