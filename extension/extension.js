// dusk is a stylesheet: GNOME Shell loads stylesheet-dark.css or
// stylesheet-light.css from this folder while the extension is enabled.
//
// Two owner-approved exceptions (design §2, §4.16, §4.20), each making Shell
// honour a CSS value it otherwise sets in code, so the values stay in
// src/_tokens.scss:
//
// 1. Shell clips the overview's workspace wallpaper at 30px. It follows the
//    stylesheet's border-radius on .workspace-background instead.
// 2. Shell picks the size of app icons in code (64px on most screens). The
//    main app grid, and the app results in search, use the stylesheet's
//    -dusk-app-icon-size instead.
//
// (A third, for the 24.04-style dialogs' button gaps, went with them;
// decision 23.) disable() gives everything back to Shell. If a future Shell
// renames what a patch relies on, that patch is skipped: the stylesheet
// still applies, but that one value stays Shell's (the workspace wallpaper
// its 30px corners, app icons Shell's size).
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
        this._searchIcons = new Map();
        try {
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

        // Search's app results back to the size Shell makes them at.
        for (const [result, handlerId] of this._searchIcons) {
            result.disconnect(handlerId);
            result.icon.setIconSize(Main.defaultIconSize);
        }
        this._searchIcons = null;
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
    // at its default size; give each the app grid's size as it's made. Only
    // when the app grid's own size applied (it holds the stylesheet's value).
    _patchSearchIcons() {
        const proto = AppDisplay.AppSearchProvider?.prototype;
        if (typeof proto?.createResultObject !== 'function' || !this._appGrid)
            return;

        const adopt = result => this._adoptSearchIcon(result);
        this._injections.overrideMethod(proto, 'createResultObject', original => function (...args) {
            const result = original.call(this, ...args);
            adopt(result);
            return result;
        });
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
