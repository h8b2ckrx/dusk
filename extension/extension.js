// dusk is a Shell theme: theme/dusk-dark.css and theme/dusk-light.css in this
// folder, built from dusk's copy of Yaru's source (src/shell-theme).
//
// Three owner-approved exceptions (design §2, §4.16, §4.20; the Shell theme
// design, 2026-10-30), each doing in code what Shell doesn't let a
// stylesheet do:
//
// 1. Shell clips the overview's workspace wallpaper at 30px. It follows the
//    theme's border-radius on .workspace-background instead.
// 2. Shell picks the size of app icons in code (64px on most screens). The
//    main app grid, and the app results in search, use the theme's
//    -dusk-app-icon-size instead.
// 3. Shell builds its theme from a base stylesheet (Yaru, which Ubuntu's
//    session names) and an optional one on top. dusk's theme takes the base
//    slot, with nothing on top, so Yaru isn't loaded. Shell rebuilds its
//    theme itself on dark/light, High Contrast and Shell color-scheme
//    changes, putting Yaru back; dusk puts its own back right away, keeping
//    the other extensions' stylesheets.
//
// disable() gives everything back to Shell. If a future Shell renames what a
// patch relies on, that patch is skipped: that one value stays Shell's (the
// workspace wallpaper its 30px corners, app icons Shell's size).
import St from 'gi://St';
import {Extension, InjectionManager} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Util from 'resource:///org/gnome/shell/misc/util.js';
import * as AppDisplay from 'resource:///org/gnome/shell/ui/appDisplay.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as Workspace from 'resource:///org/gnome/shell/ui/workspace.js';


export default class DuskExtension extends Extension {
    enable() {
        this._injections = new InjectionManager();
        this._backgrounds = new Map();
        this._appGrid = null;
        this._searchGrid = null;
        this._searchIcons = new Map();
        this._themeContext = St.ThemeContext.get_for_stage(global.stage);
        this._themeChangedId = null;
        this._applyingTheme = false;
        try {
            // First: the other two read their values from the theme.
            this._loadTheme();
            this._patchWorkspaceBackgrounds();
            this._patchAppGridIconSize();
            this._patchSearchIcons();
        } catch (e) {
            // Shell never calls disable() after enable() throws: give back
            // whatever was patched already.
            this.disable();
            throw e;
        }
    }

    disable() {
        if (this._themeChangedId) {
            this._themeContext.disconnect(this._themeChangedId);
            this._themeChangedId = null;
        }
        // Shell's own theme again (keeping the extensions' stylesheets).
        Main.loadTheme();

        this._injections.clear();
        this._injections = null;

        // Shell's own method is back; re-run it so its radius returns.
        for (const [background, handlerIds] of this._backgrounds) {
            handlerIds.forEach(id => background.disconnect(id));
            background._updateBorderRadius();
        }
        this._backgrounds = null;

        if (this._appGrid) {
            this._appGrid.grid.disconnect(this._appGrid.handlerId);
            this._setAppGridIconSize(this._appGrid.original);
            this._appGrid = null;
        }

        if (this._searchGrid) {
            this._searchGrid.grid.disconnect(this._searchGrid.handlerId);
            this._searchGrid = null;
        }

        // Search's app results back to the size Shell makes them at.
        for (const [result, handlerId] of this._searchIcons) {
            result.disconnect(handlerId);
            result.icon.setIconSize(Main.defaultIconSize);
        }
        this._searchIcons = null;
    }

    // Exception 3: dusk's theme in the base slot of Shell's theme, and back
    // there whenever Shell rebuilds its theme.
    _loadTheme() {
        this._applyTheme();
        this._themeChangedId = this._themeContext.connect('changed', () => this._applyTheme());
    }

    // dusk's theme file for the current variant.
    _themeFile() {
        return this.dir.get_child('theme').get_child(`dusk-${Main.getStyleVariant()}.css`);
    }

    // Puts dusk's theme in the base slot, alone (nothing on top), keeping the
    // other extensions' stylesheets, unless it's there already. Setting the
    // theme emits `changed` again, which finds it there. Without a built
    // theme file Shell keeps its own (stock Ubuntu, not a blank Shell).
    _applyTheme() {
        if (this._applyingTheme)
            return;
        const file = this._themeFile();
        const current = this._themeContext.get_theme();
        if (current.default_stylesheet?.equal(file) && !current.application_stylesheet)
            return;
        if (!file.query_exists(null)) {
            console.warn(`dusk: ${file.get_path()} is missing; run build.sh`);
            return;
        }
        this._applyingTheme = true;
        try {
            const theme = new St.Theme({default_stylesheet: file});
            for (const stylesheet of current.get_custom_stylesheets())
                theme.load_stylesheet(stylesheet);
            this._themeContext.set_theme(theme);
        } finally {
            this._applyingTheme = false;
        }
    }

    // Exception 1: the overview's workspace wallpaper follows the
    // stylesheet's border-radius. Shell's method still runs first (it also
    // scales the radius from 0 on the desktop to full in the overview); we
    // redo its last step with the stylesheet's radius.
    _patchWorkspaceBackgrounds() {
        const wsProto = Workspace.WorkspaceBackground?.prototype;
        if (typeof wsProto?._updateBorderRadius !== 'function')
            return;

        const track = background => this._track(background);
        this._injections.overrideMethod(wsProto, '_updateBorderRadius', original => function (...args) {
            original.call(this, ...args);
            track(this);
            const content = this._bgManager?.backgroundActor?.content;
            if (!content || !this.get_stage())
                return;
            const radius = this.get_theme_node().get_border_radius(St.Corner.TOPLEFT);
            content.rounded_clip_radius = Util.lerp(0, radius, this._stateAdjustment.value);
        });

        // Workspace backgrounds that already exist.
        this._findBackgrounds(global.stage).forEach(b => b._updateBorderRadius());
    }

    // Re-apply when the stylesheet changes; forget destroyed backgrounds.
    _track(background) {
        if (this._backgrounds.has(background))
            return;
        this._backgrounds.set(background, [
            background.connect('style-changed', () => background._updateBorderRadius()),
            background.connect('destroy', () => this._backgrounds.delete(background)),
        ]);
    }

    // Every workspace background under `actor`.
    _findBackgrounds(actor) {
        const found = actor instanceof Workspace.WorkspaceBackground ? [actor] : [];
        for (const child of actor.get_children())
            found.push(...this._findBackgrounds(child));
        return found;
    }

    // Exception 2: the main app grid's icons follow the stylesheet's
    // -dusk-app-icon-size, through the grid layout's own fixed-icon-size
    // property. Folder grids keep Shell's size.
    _patchAppGridIconSize() {
        const grid = Main.overview._overview?._controls?._appDisplay?._grid;
        const layout = grid?.layout_manager;
        if (!layout || !('fixed_icon_size' in layout) || typeof layout._pageWidth !== 'number')
            return;

        const apply = () => {
            const [found, length] = grid.get_theme_node().lookup_length('-dusk-app-icon-size', false);
            if (!found)
                return;
            const {scaleFactor} = St.ThemeContext.get_for_stage(global.stage);
            this._appGrid.size = Math.round(length / scaleFactor);
            this._setAppGridIconSize(this._appGrid.size);
            for (const result of this._searchIcons.keys())
                result.icon.setIconSize(this._appGrid.size);
        };
        this._appGrid = {
            grid,
            original: layout.fixed_icon_size,
            size: 0,
            handlerId: grid.connect('style-changed', apply),
        };
        if (grid.get_stage())
            apply();
    }

    // The layout only picks its icon size again when its page size changes
    // (it does so just before every allocation), so forget the page size.
    _setAppGridIconSize(size) {
        const {grid} = this._appGrid;
        if (grid.layout_manager.fixed_icon_size === size)
            return;
        grid.layout_manager.fixed_icon_size = size;
        grid.layout_manager._pageWidth = 0;
        grid.queue_relayout();
    }

    // Exception 2, search: app results are app grid icons, which Shell makes
    // at its default size; give each the app grid's size as search shows it.
    // Only when the app grid's own size applied (it holds the stylesheet's
    // value). A signal, not a method patch: Ubuntu Dock takes its own patch of
    // the method that makes them off and back on whenever Do Not Disturb
    // changes, and that takes any patch made after its own with it.
    _patchSearchIcons() {
        const results = Main.overview._overview?._controls?._searchController?._searchResults;
        const provider = results?._providers?.find(p => p instanceof AppDisplay.AppSearchProvider);
        const grid = provider?.display?._grid;
        if (!(grid instanceof St.Widget) || !this._appGrid)
            return;

        this._searchGrid = {
            grid,
            handlerId: grid.connect('child-added', (_grid, result) => this._adoptSearchIcon(result)),
        };
        // Results on screen already.
        grid.get_children().forEach(result => this._adoptSearchIcon(result));
    }

    // Size a search result like the app grid, if it's an app icon; remember
    // it so disable() can give it Shell's size back.
    _adoptSearchIcon(result) {
        if (!(result instanceof AppDisplay.AppIcon) || this._searchIcons.has(result))
            return;
        this._searchIcons.set(result,
            result.connect('destroy', () => this._searchIcons?.delete(result)));
        if (this._appGrid.size)
            result.icon.setIconSize(this._appGrid.size);
    }
}
