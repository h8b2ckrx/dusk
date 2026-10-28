// Test-only extension for tools/headless-probe.sh; never installed for real.
// In an isolated headless Shell it first puts the Shell into a few UI states
// (desktop, overview, quick settings open, a quick-toggle menu open, a top bar
// menu with an open submenu and a switch, a notification banner, the date menu
// with calendar and message list, the volume popup, the app grid, an app
// folder, search results, the screenshot UI, the on-screen keyboard) and records every visible actor with the corner
// radii Shell computed for it, in snapshots.json, with a screenshot of each
// state. Then it opens modal dialogs with 1, 2 and 3
// buttons (the 2-button one mimics a polkit prompt: password entry focused,
// default button insensitive), then Shell's own Log Out and Power Off dialog,
// which Shell creates at startup, before any extension is enabled. It records
// their geometry in result.json and saves a screenshot of each to
// $DUSK_PROBE_OUT. Finally it disables dusk@local and reopens Log Out, to
// check Shell's own gap comes back, then writes `done`.
import GLib from 'gi://GLib';
import GObject from 'gi://GObject';
import Gio from 'gi://Gio';
import Shell from 'gi://Shell';
import St from 'gi://St';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as AppDisplay from 'resource:///org/gnome/shell/ui/appDisplay.js';
import * as Dialog from 'resource:///org/gnome/shell/ui/dialog.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as MessageTray from 'resource:///org/gnome/shell/ui/messageTray.js';
import * as ModalDialog from 'resource:///org/gnome/shell/ui/modalDialog.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';
import * as QuickSettings from 'resource:///org/gnome/shell/ui/quickSettings.js';

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

// GType names of an actor's class and its parents, e.g. StEntry, StWidget…,
// for matching type selectors such as `StEntry`.
function typeNames(actor) {
    const names = [];
    for (let t = actor.constructor.$gtype; t && t.name !== 'GObject'; t = GObject.type_parent(t))
        names.push(t.name);
    return names;
}

// Every mapped actor under the stage as a flat list: parent index, id (actor
// name), style classes, pseudo classes, type names, and for St widgets the
// computed corner radii [top-left, top-right, bottom-right, bottom-left].
function snapshotStage() {
    const records = [];
    const walk = (actor, parent) => {
        if (!actor.mapped)
            return;
        const isWidget = actor instanceof St.Widget;
        const node = isWidget ? actor.get_theme_node() : null;
        const index = records.length;
        records.push({
            parent,
            id: actor.name ?? '',
            classes: isWidget ? (actor.style_class ?? '').split(/\s+/).filter(Boolean) : [],
            pseudo: isWidget ? (actor.get_style_pseudo_class() ?? '').split(/\s+/).filter(Boolean) : [],
            types: typeNames(actor),
            radii: node ? [0, 1, 2, 3].map(corner => node.get_border_radius(corner)) : null,
        });
        for (const child of actor.get_children())
            walk(child, index);
    };
    walk(global.stage, -1);
    return records;
}

// The first actor under `actor` for which `test` is true, or null.
function findActor(actor, test) {
    if (test(actor))
        return actor;
    for (const child of actor.get_children()) {
        const found = findActor(child, test);
        if (found)
            return found;
    }
    return null;
}

async function screenshotScreen(name) {
    const stream = Gio.File.new_for_path(`${OUT}/state-${name}.png`)
        .replace(null, false, Gio.FileCreateFlags.NONE, null);
    await new Shell.Screenshot().screenshot(false, stream);
    stream.close(null);
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

    // UI states whose computed radii the tests check against our stylesheet.
    async _snapshots() {
        const snapshots = {};
        const take = async name => {
            await sleep(800);
            snapshots[name] = snapshotStage();
            await screenshotScreen(name);
        };

        // A top bar button with a menu and a submenu, like an extension adds.
        const button = new PanelMenu.Button(0.5, 'dusk-probe');
        button.add_child(new St.Icon({icon_name: 'emblem-system-symbolic', style_class: 'system-status-icon'}));
        button.menu.addMenuItem(new PopupMenu.PopupMenuItem('First item'));
        const sub = new PopupMenu.PopupSubMenuMenuItem('Submenu');
        sub.menu.addMenuItem(new PopupMenu.PopupMenuItem('Sub item 1'));
        sub.menu.addMenuItem(new PopupMenu.PopupMenuItem('Sub item 2'));
        button.menu.addMenuItem(sub);
        button.menu.addMenuItem(new PopupMenu.PopupSwitchMenuItem('Switch', true));
        Main.panel.addToStatusArea('dusk-probe', button);

        // A quick toggle with a menu, like Wi-Fi or Bluetooth.
        const indicator = new QuickSettings.SystemIndicator();
        const toggle = new QuickSettings.QuickMenuToggle({title: 'Probe', iconName: 'emblem-system-symbolic'});
        toggle.menu.setHeader('emblem-system-symbolic', 'Probe menu');
        toggle.menu.addMenuItem(new PopupMenu.PopupMenuItem('Menu item'));
        indicator.quickSettingsItems.push(toggle);
        Main.panel.statusArea.quickSettings.addExternalIndicator(indicator);

        await take('desktop');

        Main.overview.show();
        await take('overview');
        Main.overview.hide();
        await sleep(800);

        const quickSettings = Main.panel.statusArea.quickSettings.menu;
        quickSettings.open();
        await take('quick-settings');
        toggle.menu.open();
        await take('quick-toggle-menu');
        toggle.menu.close();
        quickSettings.close();
        await sleep(500);

        button.menu.open();
        sub.setSubmenuShown(true);
        await take('panel-menu');
        button.menu.close();
        await sleep(500);

        // A notification with an action button, shown as a banner.
        const source = MessageTray.getSystemSource();
        const notification = new MessageTray.Notification({
            source,
            title: 'Probe notification',
            body: 'A notification with an action button',
        });
        notification.addAction('Action', () => {});
        source.addNotification(notification);
        await take('notification');

        // The date menu: calendar, today button, message list with that notification.
        const dateMenu = Main.panel.statusArea.dateMenu.menu;
        dateMenu.open();
        await take('date-menu');
        dateMenu.close();
        await sleep(500);

        // The volume popup.
        Main.osdWindowManager.showAll(new Gio.ThemedIcon({name: 'audio-volume-high-symbolic'}), null, 0.5, 1);
        await take('osd');
        await sleep(2000);

        // The app grid, then an app folder opened from it.
        Main.overview.showApps();
        await take('app-grid');
        const folder = findActor(global.stage, a => a instanceof AppDisplay.FolderIcon);
        if (folder) {
            folder.open();
            await take('app-folder');
        }
        Main.overview.hide();
        await sleep(1000);

        // Search results.
        Main.overview.show();
        await sleep(800);
        Main.overview.searchEntry.set_text('set');
        await sleep(1500);
        await take('search');
        Main.overview.searchEntry.set_text('');
        Main.overview.hide();
        await sleep(1000);

        // The screenshot UI.
        await Main.screenshotUI.open();
        await take('screenshot-ui');
        Main.screenshotUI.close(true);
        await sleep(800);

        // The on-screen keyboard.
        Main.keyboard.open(Main.layoutManager.primaryIndex);
        await take('keyboard');
        Main.keyboard.close();
        await sleep(800);

        write('snapshots.json', JSON.stringify(snapshots));
    }

    async _run() {
        await this._snapshots();
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
