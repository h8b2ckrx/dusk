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
  local tool
  for tool in gnome-extensions gsettings; do
    [ "$(command -v "$tool")" = "$REPO/tests/stubs/$tool" ] || fail "$tool stub is not first on PATH"
  done
}

install_dusk() { "$REPO/install.sh" > "$HOME.out" 2>&1; }
uninstall_dusk() { "$REPO/uninstall.sh" > "$HOME.out" 2>&1; }

state_file() { echo "$HOME/.local/state/dusk/install.state"; }
ext_link() { echo "$HOME/.local/share/gnome-shell/extensions/dusk@local"; }

# assert_ext_linked REPO: Shell's dusk@local is a real folder whose files are
# links to REPO/extension's files.
assert_ext_linked() {
  [ -d "$(ext_link)" ] && [ ! -L "$(ext_link)" ] || fail "$(ext_link) is not a real folder"
  local f
  for f in "$1"/extension/*; do
    assert_symlink_to "$(ext_link)/$(basename "$f")" "$f"
  done
}

# copy_repo: a throwaway copy of the repo's working tree, for tests that could
# harm the repo's own files if the code under test is wrong.
copy_repo() {
  local dir; dir=$(mktemp -d)
  (cd "$REPO" && git ls-files -z | xargs -0 cp --parents -t "$dir")
  echo "$dir"
}

# shell_remove DIR: what the Extensions app's Remove does to an extension's
# folder (Shell 50 misc/fileUtils.js recursivelyDeleteDir, replayed with GIO).
shell_remove() {
  python3 - "$1" <<'PY'
import sys
import gi
gi.require_version("Gio", "2.0")
from gi.repository import Gio
def delete_dir(d, delete_parent):
    children = d.enumerate_children("standard::name,standard::type",
                                    Gio.FileQueryInfoFlags.NOFOLLOW_SYMLINKS, None)
    while (info := children.next_file(None)) is not None:
        kind, child = info.get_file_type(), d.get_child(info.get_name())
        if kind in (Gio.FileType.REGULAR, Gio.FileType.SYMBOLIC_LINK):
            child.delete(None)
        elif kind == Gio.FileType.DIRECTORY:
            delete_dir(child, True)
    if delete_parent:
        d.delete(None)
delete_dir(Gio.File.new_for_path(sys.argv[1]), True)
PY
}

test_fresh_install_creates_links_and_state() {
  setup_home
  install_dusk
  assert_symlink_to "$HOME/.config/gtk-4.0/gtk.css" "$REPO/build/gtk4.css"
  assert_symlink_to "$HOME/.config/gtk-3.0/gtk.css" "$REPO/build/gtk3.css"
  assert_ext_linked "$REPO"
  assert_eq "$(grep -c '^link' "$(state_file)")" $((2 + $(ls "$REPO/extension" | wc -l))) "link records"
  assert_contains "$DUSK_STUB_LOG" "gnome-extensions enable dusk@local"
}

# Removing dusk in the Extensions app deletes the links in dusk@local and the
# folder, never the repo's own files.
test_extensions_app_remove_keeps_repo_files() {
  setup_home
  local repo; repo=$(copy_repo)
  "$repo/install.sh" > "$HOME.out" 2>&1
  shell_remove "$(ext_link)" || fail "Remove failed"
  local f
  for f in metadata.json extension.js stylesheet-dark.css; do
    [ -f "$repo/extension/$f" ] && [ ! -L "$repo/extension/$f" ] || fail "Remove deleted the repo's extension/$f"
  done
  assert_missing "$(ext_link)"
}

# An install made before per-file links (dusk@local was one link to the
# repo's folder, commit 107a31e) is converted in place: the repo's files are
# untouched, and uninstall still leaves HOME as it was.
test_install_converts_old_folder_link() {
  setup_home
  local repo; repo=$(copy_repo)
  git -C "$REPO" show 107a31e:install.sh > "$repo/install-old.sh"
  chmod +x "$repo/install-old.sh"
  local before; before=$(cd "$HOME" && find . | sort)
  "$repo/install-old.sh" > "$HOME.out" 2>&1
  [ -L "$(ext_link)" ] || fail "old install did not make a folder link"
  "$repo/install.sh" > "$HOME.out" 2>&1
  assert_ext_linked "$repo"
  local f
  for f in "$repo"/extension/*; do
    [ ! -L "$f" ] || fail "the repo's $(basename "$f") became a link"
  done
  assert_eq "$(find "$repo" "$HOME" -name '*.dusk-backup-*' | wc -l)" 0 "backup files"
  ! grep -qxF "$(printf 'link\t%s' "$(ext_link)")" "$(state_file)" || fail "old folder link still recorded"
  "$repo/uninstall.sh" > "$HOME.out" 2>&1
  assert_eq "$(cd "$HOME" && find . | sort)" "$before" "HOME contents after uninstall"
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
  assert_contains "$HOME.out" "Backed up $HOME/.config/gtk-4.0/gtk.css"
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
  assert_ext_linked "$REPO"
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

# Uninstall and reinstall within one session: Shell already knows the
# extension, so it's enabled again at once, without a log-out.
test_reinstall_in_same_session_enables_without_relogin() {
  setup_home
  install_dusk
  uninstall_dusk
  install_dusk
  assert_contains "$HOME.out" "Extension dusk@local enabled"
  assert_not_contains "$HOME.out" "Log out"
}

# enable can succeed without the extension running (Shell hasn't loaded it):
# the hint follows the real state.
test_inactive_after_enable_prints_relogin_hint() {
  setup_home
  install_dusk
  DUSK_STUB_STATE=INACTIVE install_dusk
  assert_contains "$HOME.out" "Log out and back in once"
  assert_not_contains "$HOME.out" "Extension dusk@local enabled"
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

# A link the user put in place of dusk's since install is theirs: a re-install
# backs it up instead of deleting it, and uninstall puts it back.
test_user_link_replacing_ours_is_kept() {
  setup_home
  install_dusk
  rm "$HOME/.config/gtk-4.0/gtk.css"
  ln -s /etc/hostname "$HOME/.config/gtk-4.0/gtk.css"
  install_dusk
  assert_symlink_to "$HOME/.config/gtk-4.0/gtk.css" "$REPO/build/gtk4.css"
  uninstall_dusk
  assert_symlink_to "$HOME/.config/gtk-4.0/gtk.css" /etc/hostname
}

# Disabling puts dusk@local in Shell's disabled-extensions list (and an
# uninstall without a session would leave it in enabled-extensions):
# uninstall takes it out of both, leaving other extensions alone.
test_uninstall_clears_shell_extension_lists() {
  setup_home
  install_dusk
  gsettings set org.gnome.shell enabled-extensions "['dusk@local', 'mine@x']"
  gsettings set org.gnome.shell disabled-extensions "['other@y', 'dusk@local']"
  uninstall_dusk
  assert_eq "$(gsettings get org.gnome.shell enabled-extensions)" "['mine@x']"
  assert_eq "$(gsettings get org.gnome.shell disabled-extensions)" "['other@y']"
}

# A step that fails doesn't stop the others, and the state file stays so a
# second run finishes the job.
test_uninstall_keeps_going_and_keeps_state_on_failure() {
  setup_home
  mkdir -p "$HOME/.config/gtk-4.0"
  echo old > "$HOME/.config/gtk-4.0/gtk.css"
  install_dusk
  chmod a-w "$HOME/.config/gtk-4.0"
  if uninstall_dusk; then fail "uninstall reported success"; fi
  chmod u+w "$HOME/.config/gtk-4.0"
  assert_missing "$HOME/.config/gtk-3.0/gtk.css"
  [ -f "$(state_file)" ] || fail "state file gone after a failed uninstall"
  uninstall_dusk
  assert_eq "$(cat "$HOME/.config/gtk-4.0/gtk.css")" old "restored gtk.css"
  assert_missing "$(state_file)"
}

# Flatpak overrides changed since install are the user's: uninstall leaves
# the file as it is and says which entries are dusk's.
test_flatpak_overrides_changed_since_install_are_kept() {
  setup_home
  export FLATPAK="$REPO/tests/stubs/flatpak"
  install_dusk
  printf '[Environment]\nMY_OWN=1\n' >> "$HOME/.local/share/flatpak/overrides/global"
  uninstall_dusk
  assert_contains "$HOME/.local/share/flatpak/overrides/global" "MY_OWN=1"
  assert_contains "$HOME.out" "xdg-config/gtk-4.0:ro"
}

# A missing Flatpak backup can't be restored, but the rest is still undone.
test_uninstall_survives_missing_flatpak_backup() {
  setup_home
  export FLATPAK="$REPO/tests/stubs/flatpak"
  mkdir -p "$HOME/.local/share/flatpak/overrides" "$HOME/.config/gtk-4.0"
  printf '[Context]\nshared=network;\n' > "$HOME/.local/share/flatpak/overrides/global"
  echo old > "$HOME/.config/gtk-4.0/gtk.css"
  install_dusk
  rm "$HOME"/.local/share/flatpak/overrides/global.dusk-backup-*
  uninstall_dusk
  assert_eq "$(cat "$HOME/.config/gtk-4.0/gtk.css")" old "restored gtk.css"
  assert_contains "$HOME.out" "xdg-config/gtk-4.0:ro"
  assert_missing "$(state_file)"
}

# A state other than "not loaded yet" (e.g. after a GNOME upgrade) gets its
# own hint, not an endless "log out".
test_out_of_date_extension_gets_its_own_hint() {
  setup_home
  install_dusk
  DUSK_STUB_STATE="OUT OF DATE" install_dusk
  assert_contains "$HOME.out" "OUT OF DATE"
  assert_contains "$HOME.out" "shell-version"
  assert_not_contains "$HOME.out" "Log out"
}
