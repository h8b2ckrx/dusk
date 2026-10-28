// Test-only extension for tools/headless-probe.sh; never installed for real.
// In an isolated headless Shell it opens modal dialogs with 1, 2 and 3
// buttons (the 2-button one mimics a polkit prompt: password entry focused,
// default button insensitive), then Shell's own Log Out and Power Off dialog,
// which Shell creates at startup, before any extension is enabled. It records
// their geometry in result.json and saves a screenshot of each to
// $DUSK_PROBE_OUT. Finally it disables dusk@local and reopens Log Out, to
// check Shell's own gap comes back, then writes `done`.
import GLib from 'gi://GLib';
import Gio from 'gi://Gio';
import Shell from 'gi://Shell';
import St from 'gi://St';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Dialog from 'resource:///org/gnome/shell/ui/dialog.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as ModalDialog from 'resource:///org/gnome/shell/ui/modalDialog.js';

const OUT = GLib.getenv('DUSK_PROBE_OUT');

Gio._promisify(Gio.DBusConnection.prototype, 'call');

function write(name, text) {
    GLib.file_set_contents(`${OUT}/${name}`, text);
}

function sleep(ms) {
    return new Promise(resolve => GLib.timeout_add(GLib.PRIORITY_DEFAULT, ms, () => {
        resolve();
        return GLib.SOURCE_REMOVE;
    }));
}

function geometry(actor) {
    const [x, y] = actor.get_transformed_position();
    const [w, h] = actor.get_transformed_size();
    return {x, y, w, h};
}

// End-session dialog types, as gnome-session passes them to Open().
const END_SESSION = {logout: 0, poweroff: 1};

// Record the geometry of a Dialog.Dialog under results[name] and screenshot it.
async function measure(results, name, dialogLayout) {
    const row = dialogLayout.buttonLayout;
    const box = geometry(dialogLayout._dialog);
    results[name] = {
        spacing: row.layout_manager.spacing,
        dialog: box,
        buttons: row.get_children().filter(b => b.visible).map(b => ({
            ...geometry(b),
            pseudo: b.get_style_pseudo_class(),
        })),
    };
    const stream = Gio.File.new_for_path(`${OUT}/dialog-${name}.png`)
        .replace(null, false, Gio.FileCreateFlags.NONE, null);
    await new Shell.Screenshot().screenshot_area(
        box.x - 24, box.y - 24, box.w + 48, box.h + 48, stream);
    stream.close(null);
}

const SCENARIOS = {
    1: {labels: ['Close']},
    2: {labels: ['Cancel', 'Authenticate'], password: true},
    3: {labels: ['Cancel', 'Restart', 'Power Off']},
};

export default class DuskProbe extends Extension {
    enable() {
        // Give Shell (and dusk@local) time to finish starting up.
        GLib.timeout_add(GLib.PRIORITY_DEFAULT, 3000, () => {
            this._run().catch(e => {
                write('error.txt', `${e}\n${e.stack}`);
                write('done', 'error');
            });
            return GLib.SOURCE_REMOVE;
        });
    }

    disable() {}

    async _run() {
        const results = {};
        for (const [n, scenario] of Object.entries(SCENARIOS)) {
            const dialog = new ModalDialog.ModalDialog({destroyOnClose: true});
            dialog.contentLayout.add_child(new Dialog.MessageDialogContent({
                title: 'Authentication Required',
                description: 'Authentication is needed to run `/usr/bin/true` as the super user',
            }));
            const buttons = scenario.labels.map((label, i) => ({
                label,
                action: () => {},
                default: i === scenario.labels.length - 1,
            }));
            dialog.setButtons(buttons);
            if (scenario.password) {
                const entry = new St.PasswordEntry({
                    style_class: 'prompt-dialog-password-entry',
                    hint_text: 'Password',
                    can_focus: true,
                    x_expand: true,
                });
                dialog.contentLayout.add_child(entry);
                dialog.setInitialKeyFocus(entry);
                buttons.at(-1).button.reactive = false;
            }
            dialog.open();
            await sleep(1000);

            await measure(results, n, dialog.dialogLayout);

            dialog.close();
            await sleep(500);
        }

        for (const [name, type] of Object.entries(END_SESSION)) {
            await Gio.DBus.session.call('org.gnome.Shell',
                '/org/gnome/SessionManager/EndSessionDialog',
                'org.gnome.SessionManager.EndSessionDialog', 'Open',
                new GLib.Variant('(uuuao)', [type, 0, 60, []]),
                null, Gio.DBusCallFlags.NONE, -1, null);
            await sleep(1000);
            await measure(results, name, Main.endSessionDialog.dialogLayout);
            Main.endSessionDialog.close();
            await sleep(500);
        }

        await Main.extensionManager.disableExtension('dusk@local');
        await sleep(500);
        await Gio.DBus.session.call('org.gnome.Shell',
            '/org/gnome/SessionManager/EndSessionDialog',
            'org.gnome.SessionManager.EndSessionDialog', 'Open',
            new GLib.Variant('(uuuao)', [END_SESSION.logout, 0, 60, []]),
            null, Gio.DBusCallFlags.NONE, -1, null);
        await sleep(1000);
        await measure(results, 'logout-disabled', Main.endSessionDialog.dialogLayout);
        Main.endSessionDialog.close();

        write('result.json', JSON.stringify(results, null, 1));
        write('done', 'ok');
    }
}
