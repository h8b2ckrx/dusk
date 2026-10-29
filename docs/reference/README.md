# Reference stylesheets

`yaru-24.04-gnome-shell-dark.css` and `yaru-24.04-gnome-shell-light.css` are Ubuntu 24.04's GNOME
Shell stylesheets (Yaru, default accent), compiled from the `ubuntu/yaru` source at tag
`24.04.3-0ubuntu1` with:

```bash
tools/yaru-2404-shell.sh OUTDIR
```

dusk's Shell pop-up colors follow them (design decision 22). They're kept here so the tests need
no network. They're Yaru's work, by the Yaru team, under GPL-3.0 and CC-BY-SA-4.0; dusk keeps them
unchanged, for reference.
