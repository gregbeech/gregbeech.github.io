# My Website

Based on [Jekyll](https://jekyllrb.com/) with the [Chirpy](https://github.com/cotes2020/jekyll-theme-chirpy) theme. Built and deployed to [GitHub Pages](https://pages.github.com/) by GitHub Actions (see `.github/workflows/pages-deploy.yml`), with [Cloudflare](https://www.cloudflare.com/) for SSL.

Read it at [https://www.gregbeech.com/](https://www.gregbeech.com/).

## Running locally

```sh
bundle install
bundle exec foreman start
```

## Theme customisations

- `_data/locales/en.yml` sets the copyright notice to "All rights reserved".
- `assets/img/favicons/` replaces the theme's icons with a "GB" icon set.
