# Release Checklist

- [ ] Choose a license before publishing publicly.
- [ ] Run `./scripts/build-mac-app.sh`.
- [ ] Open `dist/HTML报告编辑器.app` and smoke test:
  - [ ] import HTML
  - [ ] load a built-in template
  - [ ] create a page
  - [ ] insert text and image
  - [ ] duplicate and move components across modules
  - [ ] adjust layer order
  - [ ] export HTML
- [ ] Add screenshots or a short GIF to the README.
- [ ] Create a GitHub repository named `html-report-editor`.
- [ ] Push source only, not the built `.app`.
- [ ] Attach a zipped `.app` or `.dmg` to a GitHub Release.
