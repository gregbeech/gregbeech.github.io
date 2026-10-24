# My Website

Based on [Jekyll](https://jekyllrb.com/) with the [Chirpy](https://github.com/cotes2020/jekyll-theme-chirpy) theme. Built and deployed to [GitHub Pages](https://pages.github.com/) by GitHub Actions (see `.github/workflows/pages-deploy.yml`), with [Cloudflare](https://www.cloudflare.com/) for SSL.

Read it at [https://www.gregbeech.com/](https://www.gregbeech.com/).

## Running locally

```sh
bundle install
bundle exec foreman start
```

## Theme customisations

- `_layouts/tag.html` shows an optional introduction from `_data/tag_descriptions.yml` on tag pages.
- `_data/locales/en.yml` sets the copyright notice to "All rights reserved".
- `_includes/favicons.html` and `assets/img/favicons/site.webmanifest` match the available icons.
- `assets/css/jekyll-theme-chirpy.scss` holds custom styles.
