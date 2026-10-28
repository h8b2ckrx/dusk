# install.sh / uninstall.sh in a throwaway HOME, with stubbed system tools.

# Fresh fake HOME, stubs first on PATH, no Flatpak unless a test sets FLATPAK.
setup_home() {
  HOME=$(mktemp -d)
  export HOME
  unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME
  DUSK_STUB_LOG=$(mktemp)
  export DUSK_STUB_LOG
  export PATH="$REPO/tests/stubs:$PATH"
  export FLATPAK=dusk-no-flatpak
  # Safety: never reach the real Shell from a test.
  [ "$(command -v gnome-extensions)" = "$REPO/tests/stubs/gnome-extensions" ] \
    || fail "gnome-extensions stub is not first on PATH"
}

install_dusk() { "$REPO/install.sh" > "$HOME.out" 2>&1; }
uninstall_dusk() { "$REPO/uninstall.sh" > "$HOME.out" 2>&1; }

state_file() { echo "$HOME/.local/state/dusk/install.state"; }
ext_link() { echo "$HOME/.local/share/gnome-shell/extensions/dusk@local"; }

test_fresh_install_creates_links_and_state() {
  setup_home
  install_dusk
  assert_symlink_to "$HOME/.config/gtk-4.0/gtk.css" "$REPO/build/gtk4.css"
  assert_symlink_to "$HOME/.config/gtk-3.0/gtk.css" "$REPO/build/gtk3.css"
  assert_symlink_to "$(ext_link)" "$REPO/extension"
  assert_eq "$(grep -c '^link' "$(state_file)")" 3 "link records"
  assert_contains "$DUSK_STUB_LOG" "gnome-extensions enable dusk@local"
}

test_second_install_is_noop() {
  setup_home
  install_dusk
  local before; before=$(cat "$(state_file)")
  install_dusk
  assert_eq "$(cat "$(state_file)")" "$before" "state after second install"
  assert_eq "$(find "$HOME" -name '*.dusk-backup-*' | wc -l)" 0 "backup files"
}

test_existing_gtk_css_backed_up_and_restored() {
  setup_home
  mkdir -p "$HOME/.config/gtk-4.0"
  echo old > "$HOME/.config/gtk-4.0/gtk.css"
  install_dusk
  assert_symlink_to "$HOME/.config/gtk-4.0/gtk.css" "$REPO/build/gtk4.css"
  uninstall_dusk
  [ ! -L "$HOME/.config/gtk-4.0/gtk.css" ] || fail "gtk.css is still a symlink"
  assert_eq "$(cat "$HOME/.config/gtk-4.0/gtk.css")" old "restored gtk.css"
}

test_foreign_symlink_backed_up_and_restored() {
  setup_home
  mkdir -p "$HOME/.config/gtk-3.0"
  ln -s /etc/hostname "$HOME/.config/gtk-3.0/gtk.css"
  install_dusk
  uninstall_dusk
  assert_symlink_to "$HOME/.config/gtk-3.0/gtk.css" /etc/hostname
}

# Uninstall leaves HOME exactly as it was: no stray dirs, links or state.
test_created_dirs_removed() {
  setup_home
  mkdir -p "$HOME/.config/gtk-4.0"
  local before; before=$(cd "$HOME" && find . | sort)
  install_dusk
  [ -d "$HOME/.config/gtk-3.0" ] || fail "install did not create gtk-3.0"
  uninstall_dusk
  assert_eq "$(cd "$HOME" && find . | sort)" "$before" "HOME contents after uninstall"
}

test_uninstall_twice_is_safe() {
  setup_home
  install_dusk
  uninstall_dusk
  uninstall_dusk
  assert_contains "$HOME.out" "dusk is not installed."
  assert_contains "$DUSK_STUB_LOG" "gnome-extensions disable dusk@local"
}

test_install_from_other_cwd() {
  setup_home
  (cd / && "$REPO/install.sh" > /dev/null 2>&1)
  assert_symlink_to "$(ext_link)" "$REPO/extension"
}

test_missing_sassc_fails_cleanly() {
  setup_home
  if SASSC=dusk-no-sassc "$REPO/install.sh" > "$HOME.out" 2>&1; then
    fail "install.sh succeeded without sassc"
  fi
  assert_contains "$HOME.out" "sassc"
  assert_missing "$HOME/.config/gtk-4.0/gtk.css"
  assert_missing "$(ext_link)"
  assert_missing "$(state_file)"
}

test_enable_failure_prints_relogin_hint() {
  setup_home
  DUSK_STUB_ENABLE_FAIL=1 install_dusk
  assert_contains "$HOME.out" "Log out and back in once"
}

test_flatpak_absent_skips_override() {
  setup_home
  install_dusk
  assert_not_contains "$DUSK_STUB_LOG" "flatpak"
}

test_flatpak_present_override_and_restore() {
  setup_home
  export FLATPAK="$REPO/tests/stubs/flatpak"
  local before; before=$(cd "$HOME" && find . | sort)
  install_dusk
  assert_contains "$DUSK_STUB_LOG" "flatpak override --user --filesystem=xdg-config/gtk-4.0:ro --filesystem=xdg-config/gtk-3.0:ro --filesystem=$REPO/build:ro"
  [ -f "$HOME/.local/share/flatpak/overrides/global" ] || fail "no overrides file after install"
  uninstall_dusk
  assert_eq "$(cd "$HOME" && find . | sort)" "$before" "HOME contents after uninstall"
}

# After the repo moves, re-running install replaces its own old links
# (recognised from the state file) instead of backing them up as foreign files.
test_reinstall_after_repo_move_replaces_old_links() {
  setup_home
  install_dusk
  rm "$HOME/.config/gtk-4.0/gtk.css"
  ln -s /old/repo/build/gtk4.css "$HOME/.config/gtk-4.0/gtk.css"
  install_dusk
  assert_symlink_to "$HOME/.config/gtk-4.0/gtk.css" "$REPO/build/gtk4.css"
  assert_eq "$(find "$HOME" -name '*.dusk-backup-*' | wc -l)" 0 "backup files"
}
