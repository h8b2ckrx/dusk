// dusk is a stylesheet: GNOME Shell loads stylesheet-dark.css or
// stylesheet-light.css from this folder while the extension is enabled.
//
// Three owner-approved exceptions (design §2, §4.15–16, §4.20), each making
// Shell honour a CSS value it otherwise sets in code, so the values stay in
// src/_tokens.scss:
//
// 1. Shell 50 sets a 12px gap between modal dialog buttons. Every dialog's
//    button row follows the stylesheet's `spacing` instead. It covers dialogs
//    created from now on and dialogs that already exist (Shell builds its
//    Log Out / Power Off dialog at startup, before extensions load).
// 2. Shell clips the overview's workspace wallpaper at 30px. It follows the
//    stylesheet's border-radius on .workspace-background instead.
// 3. Shell picks the app grid's icon size in code (64px on most screens).
//    The main app grid uses the stylesheet's -dusk-app-icon-size instead.
//
// disable() gives everything back to Shell. If a future Shell renames what a
// patch relies on, that patch is skipped: the stylesheet still applies, but
// that one value stays Shell's (dialog buttons keep Shell's 12px gaps, the
// workspace wallpaper its 30px corners, the app grid Shell's icon size).
import Clutter from 'gi://Clutter';
import St from 'gi://St';
import {Extension, InjectionManager} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Util from 'resource:///org/gnome/shell/misc/util.js';
import * as Dialog from 'resource:///org/gnome/shell/ui/dialog.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as Workspace from 'resource:///org/gnome/shell/ui/workspace.js';

const ROW_CLASS = 'modal-dialog-button-box';

export default class DuskExtension extends Extension {
    enable() {
        this._injections = new InjectionManager();
        this._rows = new Map();
        this._backgrounds = new Map();
        this._appGrid = null;
        try {
            this._patchDialogs();
            this._patchWorkspaceBackgrounds();
            this._patchAppGridIconSize();
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

        for (const [row, {original, handlerIds}] of this._rows) {
            handlerIds.forEach(id => row.disconnect(id));
            row.layout_manager.spacing = original;
        }
        this._rows = null;

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
    }

    // Exception 1: dialog button rows follow the stylesheet's `spacing`.
    _patchDialogs() {
        const proto = Dialog.Dialog?.prototype;
        if (typeof proto?._createDialog !== 'function')
            return;

        // Dialogs created from now on.
        const adopt = row => this._adopt(row);
        this._injections.overrideMethod(proto, '_createDialog', original => function (...args) {
            original.call(this, ...args);
            adopt(this.buttonLayout);
        });

        // Dialogs that already exist.
        this._findRows(global.stage).forEach(row => this._adopt(row));
    }

    // Make a dialog button row follow the stylesheet's `spacing`, remembering
    // the spacing Shell gave it.
    _adopt(row) {
        if (!(row?.layout_manager instanceof Clutter.BoxLayout) || this._rows.has(row))
            return;

        const apply = () => {
            const [found, spacing] = row.get_theme_node().lookup_length('spacing', false);
            if (found)
                row.layout_manager.spacing = spacing;
        };
        this._rows.set(row, {
            original: row.layout_manager.spacing,
            handlerIds: [
                row.connect('style-changed', apply),
                row.connect('destroy', () => this._rows.delete(row)),
            ],
        });

        // Already styled rows won't emit style-changed again until something
        // changes, so apply now.
        if (row.get_stage())
            apply();
    }

    // Every dialog button row under `actor`.
    _findRows(actor) {
        const rows = actor.has_style_class_name?.(ROW_CLASS) ? [actor] : [];
        for (const child of actor.get_children())
            rows.push(...this._findRows(child));
        return rows;
    }

    // Exception 2: the overview's workspace wallpaper follows the
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

    // Exception 3: the main app grid's icons follow the stylesheet's
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
            this._setAppGridIconSize(Math.round(length / scaleFactor));
        };
        this._appGrid = {
            grid,
            original: layout.fixed_icon_size,
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
}
