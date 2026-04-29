# nanobrain.app

Static landing page for nanobrain. Plain HTML + CSS, zero JS dependencies.

## Deploy (Cloudflare Pages)

The site lives at [nanobrain.app](https://nanobrain.app), served from Cloudflare Pages.

To deploy:

1. **Connect Cloudflare Pages to this repo**
   - Cloudflare dashboard → Pages → Create application → Connect to Git → `siddsdixit/nanobrain`
   - Production branch: `main`
   - Build command: *(leave blank)*
   - Build output directory: `site`
   - Root directory: *(leave blank)*

2. **Bind the apex domain**
   - Pages project → Custom domains → Add custom domain → `nanobrain.app`
   - Cloudflare auto-creates the necessary CNAME (the domain is already on Cloudflare DNS)

3. **Confirm `www` redirect** (optional)
   - Pages → Custom domains → Add `www.nanobrain.app` → set as redirect to apex

Subsequent commits to `main` auto-deploy. No CI required.

## Files

- `index.html` — the page
- `styles.css` — the look (coral on warm charcoal)
- `demo.gif` — the hero CLI demo
- `_redirects` — Cloudflare Pages redirect rules

## Local preview

Just open `index.html` in a browser. There's no build step.

For a real local server (relative paths work better):

```bash
cd site
python3 -m http.server 8000
# open http://localhost:8000
```
