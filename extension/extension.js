// dusk is a stylesheet: GNOME Shell loads stylesheet-dark.css or
// stylesheet-light.css from this folder while the extension is enabled.
//
// The one exception (owner-approved, design §6): Shell 50 sets a 12px gap
// between modal dialog buttons in code, which CSS can't change. This makes
// every dialog's button row honour the stylesheet's `spacing` instead, so the
// value stays in src/_tokens.scss. It covers dialogs created from now on and
// dialogs that already exist: Shell builds its Log Out / Power Off dialog at
// startup, before extensions load. disable() gives every row back its own
// spacing. If a future Shell renames what this relies on, nothing is patched
// and dialogs stay stock.
import Clutter from 'gi://Clutter';
import {Extension, InjectionManager} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Dialog from 'resource:///org/gnome/shell/ui/dialog.js';

const ROW_CLASS = 'modal-dialog-button-box';

export default class DuskExtension extends Extension {
    enable() {
        this._injections = new InjectionManager();
        this._rows = new Map();

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

    disable() {
        this._injections.clear();
        this._injections = null;

        for (const [row, {original, handlerIds}] of this._rows) {
            handlerIds.forEach(id => row.disconnect(id));
            row.layout_manager.spacing = original;
        }
        this._rows = null;
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
}
