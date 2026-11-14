# Website source

The documentation site at `docs/` is generated from here. Edit pages in `pages/`, then rebuild:

```sh
python3 site/build.py        # writes docs/ (standard library only)
python3 site/make_images.py  # only when the logo or social image changes; needs Pillow
```

- `pages/*.html`: one page each. A header of `key: value` lines (title, nav, icon, description, lead) ends at `---`.
  In page text, `{{icon:name}}` inlines an icon from `icons.py`, and `{{app}}`, `{{repo}}`, `{{download}}`,
  `{{site}}` and `{{version}}` expand to the values at the top of `build.py`.
- `assets/`: stylesheet, script, logo and generated images.
- `static/`: copied as is, such as screenshots. Screenshots must not show personal file paths.

The app name, site URL and repository live at the top of `build.py`, so a rename is one edit there.
