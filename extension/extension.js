// dusk is a stylesheet: GNOME Shell loads stylesheet-dark.css or
// stylesheet-light.css from this folder while the extension is enabled.
//
// The one exception (owner-approved, design §6): Shell 50 sets a 12px gap
// between modal dialog buttons in code, which CSS can't change. This makes
// the dialog's button row honour the stylesheet's `spacing` instead, so the
// value stays in src/_tokens.scss. If a future Shell renames the method,
// nothing is patched and dialogs stay stock.
import Clutter from 'gi://Clutter';
import {Extension, InjectionManager} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Dialog from 'resource:///org/gnome/shell/ui/dialog.js';

export default class DuskExtension extends Extension {
    enable() {
        this._injections = new InjectionManager();

        const proto = Dialog.Dialog?.prototype;
        if (typeof proto?._createDialog !== 'function')
            return;

        this._injections.overrideMethod(proto, '_createDialog', original => function (...args) {
            original.call(this, ...args);

            const row = this.buttonLayout;
            if (!(row?.layout_manager instanceof Clutter.BoxLayout))
                return;

            row.connect('style-changed', () => {
                const [found, spacing] = row.get_theme_node().lookup_length('spacing', false);
                if (found)
                    row.layout_manager.spacing = spacing;
            });
        });
    }

    disable() {
        this._injections.clear();
        this._injections = null;
    }
}
