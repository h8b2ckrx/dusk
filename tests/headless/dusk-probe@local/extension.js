// Test-only extension for tools/headless-probe.sh; never installed for real.
// In an isolated headless Shell it first puts the Shell into a few UI states
// (desktop, overview, quick settings open, a quick-toggle menu open, a top bar
// menu with an open submenu and a switch, a notification banner, the date menu
// with calendar and message list, the volume popup, the app grid, an app
// folder, search results, the screenshot UI, the on-screen keyboard, a modal
// dialog, the lock screen and its password prompt) and records every visible actor with the corner
// radii and colors Shell computed for it, in snapshots.json, with a screenshot of each
// state. Then it opens modal dialogs with 1, 2 and 3
// buttons (the 2-button one mimics a polkit prompt: password entry focused,
// default button insensitive), then Shell's own Log Out and Power Off dialog,
// which Shell creates at startup, before any extension is enabled. It records
// their geometry in result.json and saves a screenshot of each to
// $DUSK_PROBE_OUT. Finally it disables dusk@local and reopens Log Out and the
// overview, to check Shell's own values come back, then writes `done`.
import Clutter from 'gi://Clutter';
import GLib from 'gi://GLib';
import GObject from 'gi://GObject';
import Gio from 'gi://Gio';
import Shell from 'gi://Shell';
import St from 'gi://St';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import {ExtensionState} from 'resource:///org/gnome/shell/misc/extensionUtils.js';
import * as AuthPrompt from 'resource:///org/gnome/shell/gdm/authPrompt.js';
import * as AppDisplay from 'resource:///org/gnome/shell/ui/appDisplay.js';
import * as Dialog from 'resource:///org/gnome/shell/ui/dialog.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as Workspace from 'resource:///org/gnome/shell/ui/workspace.js';
import * as MessageTray from 'resource:///org/gnome/shell/ui/messageTray.js';
import * as ModalDialog from 'resource:///org/gnome/shell/ui/modalDialog.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';
import * as QuickSettings from 'resource:///org/gnome/shell/ui/quickSettings.js';
import * as Search from 'resource:///org/gnome/shell/ui/search.js';
import * as UnlockDialog from 'resource:///org/gnome/shell/ui/unlockDialog.js';

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
// A theme node color as [r, g, b, a] (0-255), or null.
function rgba(color) {
    return color ? [color.red, color.green, color.blue, color.alpha] : null;
}

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
            colors: node ? [
                rgba(node.get_background_color()),
                rgba(node.get_foreground_color()),
                rgba(node.get_border_color(St.Side.TOP)),
                rgba(node.get_box_shadow()?.color ?? null),
            ] : null,
        });
        for (const child of actor.get_children())
            walk(child, index);
    };
    walk(global.stage, -1);
    return records;
}

// Shell's theme now: the stylesheet in its base slot (Yaru's, or dusk's while
// dusk runs), the one on top (what User Themes sets), the extensions' ones,
// and dusk's handler for Shell's theme rebuilds (design 2026-10-30).
function themeState() {
    const theme = St.ThemeContext.get_for_stage(global.stage).get_theme();
    const name = file => file ? (file.get_path() ?? file.get_uri()) : null;
    return {
        default: name(theme.default_stylesheet),
        application: name(theme.application_stylesheet),
        custom: theme.get_custom_stylesheets().map(name),
        duskHandler: Main.extensionManager.lookup('dusk@local')?.stateObj?._themeChangedId ?? null,
        variant: Main.getStyleVariant(),
        powerModeIcon: !!Main.panel.statusArea.quickSettings._powerProfiles?.get_parent(),
    };
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

// The overview's workspace backgrounds: the wallpaper's actual clip radius,
// the radius their stylesheet gives them, and the overview state (0 desktop,
// 1 window picker) Shell scales the clip by.
function measureWorkspaces() {
    const found = [];
    const walk = actor => {
        if (actor instanceof Workspace.WorkspaceBackground && actor.mapped) {
            found.push({
                clip: actor._bgManager.backgroundActor.content.rounded_clip_radius,
                css: actor.get_theme_node().get_border_radius(St.Corner.TOPLEFT),
                state: actor._stateAdjustment.value,
            });
        }
        actor.get_children().forEach(walk);
    };
    walk(global.stage);
    return found;
}

// The main app grid's icon size: what its layout uses, what the first app
// icon is drawn at, and the columns per page that size leaves room for.
function measureAppGrid() {
    const grid = Main.overview._overview?._controls?._appDisplay?._grid;
    const first = grid && findActor(grid, a => a instanceof AppDisplay.AppIcon);
    return grid ? {
        layout: grid.layout_manager.icon_size,
        first: first?.icon.iconSize ?? null,
        columns: grid.layout_manager.columns_per_page,
    } : null;
}

// The icons in the search results' grids, by kind: app results (app grid
// icons) and the rest (system actions such as Lock Screen), at the size each
// is drawn.
function measureSearchIcons() {
    const sizes = {apps: [], others: []};
    const walk = actor => {
        if (actor.has_style_class_name?.('grid-search-results') && actor.mapped) {
            for (const child of actor.get_children()) {
                if (child instanceof AppDisplay.AppIcon)
                    sizes.apps.push(child.icon.iconSize);
                else if (child instanceof Search.GridSearchResult)
                    sizes.others.push(child.icon.iconSize);
            }
        }
        actor.get_children().forEach(walk);
    };
    walk(global.stage);
    return sizes;
}

// The top bar clock's pill and the notification indicator (the bell) next to
// it: geometry, corner radius, padding and the icon's drawn size. Screenshots
// the clock button.
async function measureClockIndicator() {
    const button = Main.panel.statusArea.dateMenu;
    const indicator = button?._indicator;
    if (!indicator?.mapped)
        return {unmapped: {visible: indicator?.visible, unseen: indicator?._count}};
    const pill = actor => {
        const node = actor.get_theme_node();
        const content = node.get_content_box(actor.get_allocation_box());
        return {
            ...geometry(actor),
            radius: node.get_border_radius(St.Corner.TOPLEFT),
            background: rgba(node.get_background_color()),
            padding: [St.Side.TOP, St.Side.RIGHT, St.Side.BOTTOM, St.Side.LEFT].map(side => node.get_padding(side)),
            content: {w: content.get_width(), h: content.get_height()},
        };
    };
    const found = {
        panel: geometry(Main.panel),
        clock: pill(button._clockDisplay),
        indicator: {...pill(indicator), iconSize: indicator.get_theme_node().get_length('icon-size')},
    };
    const box = geometry(button);
    const stream = Gio.File.new_for_path(`${OUT}/panel-clock.png`)
        .replace(null, false, Gio.FileCreateFlags.NONE, null);
    await new Shell.Screenshot().screenshot_area(box.x - 8, box.y, box.w + 16, box.h, stream);
    stream.close(null);
    return found;
}

// Search for `apps` then `others` in the overview, measuring the result
// icons after each.
async function searchIcons(apps, others) {
    Main.overview.show();
    await sleep(800);
    Main.overview.searchEntry.set_text(apps);
    await sleep(1500);
    const found = {apps: measureSearchIcons().apps};
    Main.overview.searchEntry.set_text(others);
    await sleep(1500);
    found.others = measureSearchIcons().others;
    Main.overview.searchEntry.set_text('');
    Main.overview.hide();
    await sleep(1000);
    return found;
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
        dialog: {...box, radius: dialogLayout._dialog.get_theme_node().get_border_radius(St.Corner.TOPLEFT)},
        buttons: row.get_children().filter(b => b.visible).map(b => ({
            ...geometry(b),
            pseudo: b.get_style_pseudo_class(),
            radius: b.get_theme_node().get_border_radius(St.Corner.TOPLEFT),
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

// Disabling dusk@local (at the end of the run) makes Shell re-cycle the
// extensions enabled after it, this one included; run only once per Shell.
let started = false;

export default class DuskProbe extends Extension {
    enable() {
        if (started)
            return;
        started = true;
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
        const first = new PopupMenu.PopupMenuItem('First item');
        button.menu.addMenuItem(first);
        const sub = new PopupMenu.PopupSubMenuMenuItem('Submenu');
        sub.menu.addMenuItem(new PopupMenu.PopupMenuItem('Sub item 1'));
        sub.menu.addMenuItem(new PopupMenu.PopupMenuItem('Sub item 2'));
        button.menu.addMenuItem(sub);
        button.menu.addMenuItem(new PopupMenu.PopupSwitchMenuItem('Switch', true));
        button.menu.addMenuItem(new PopupMenu.PopupSwitchMenuItem('Switch off', false));
        // A separator and an item you can't click (St marks both :insensitive),
        // like an app menu's section title or info line.
        button.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
        button.menu.addMenuItem(new PopupMenu.PopupMenuItem('Inactive', {reactive: false}));
        Main.panel.addToStatusArea('dusk-probe', button);

        // A quick toggle with a menu, like Wi-Fi or Bluetooth.
        const indicator = new QuickSettings.SystemIndicator();
        const toggle = new QuickSettings.QuickMenuToggle({title: 'Probe', iconName: 'emblem-system-symbolic'});
        toggle.menu.setHeader('emblem-system-symbolic', 'Probe menu');
        toggle.menu.addMenuItem(new PopupMenu.PopupMenuItem('Menu item'));
        toggle.checked = true; // a checked toggle shows the accent
        indicator.quickSettingsItems.push(toggle);
        Main.panel.statusArea.quickSettings.addExternalIndicator(indicator);

        await take('desktop');

        // Top bar buttons under the pointer (a headless Shell has none).
        const hovered = [Main.panel.statusArea.quickSettings, Main.panel.statusArea.dateMenu];
        hovered.forEach(actor => actor.add_style_pseudo_class('hover'));
        await take('topbar-hover');
        hovered.forEach(actor => actor.remove_style_pseudo_class('hover'));

        Main.overview.show();
        await take('overview');
        this._workspaces = measureWorkspaces();
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
        // An item under the pointer (Shell also selects and focuses it), then
        // pressed. The pointer can't move here, so :hover is set by hand.
        first.add_style_pseudo_class('hover');
        first.active = true;
        await take('menu-item-hover');
        first.add_style_pseudo_class('active');
        await take('menu-item-pressed');
        first.remove_style_pseudo_class('active');
        first.remove_style_pseudo_class('hover');
        first.active = false;
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
        this._appGrid = measureAppGrid();
        const folder = findActor(global.stage, a => a instanceof AppDisplay.FolderIcon);
        if (folder) {
            folder.open();
            await take('app-folder');
        }
        Main.overview.hide();
        await sleep(1000);

        // Search results, typed into the focused search entry.
        Main.overview.show();
        await sleep(800);
        Main.overview.searchEntry.grab_key_focus();
        Main.overview.searchEntry.set_text('set');
        await sleep(1500);
        await take('search');
        Main.overview.searchEntry.set_text('');
        Main.overview.hide();
        await sleep(1000);
        this._search = await searchIcons('set', 'lock');

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

        // A modal dialog with three buttons, like Power Off's.
        const dialog = new ModalDialog.ModalDialog({destroyOnClose: true});
        dialog.contentLayout.add_child(new Dialog.MessageDialogContent({
            title: 'Power Off', description: 'The system will power off automatically.',
        }));
        dialog.setButtons(['Cancel', 'Restart', 'Power Off'].map((label, i) =>
            ({label, action: () => {}, default: i === 2})));
        dialog.open();
        await take('dialog');
        dialog.close();
        await sleep(800);

        // The lock screen, without locking: Shell's lock-screen session mode
        // is what decides whether dusk stays on, and the unlock dialog is
        // built by hand. Locking for real would mark the owner's own login
        // session as locked (this headless Shell runs inside it), and the
        // password prompt would start a real sign-in with GDM, so its begin()
        // is stubbed.
        const begin = AuthPrompt.AuthPrompt.prototype.begin;
        AuthPrompt.AuthPrompt.prototype.begin = () => {};
        Main.sessionMode.pushMode('unlock-dialog');
        await sleep(1000);
        this._lock = {
            duskActive: Main.extensionManager.lookup('dusk@local')?.state === ExtensionState.ACTIVE,
            theme: themeState(),
        };
        const unlock = new UnlockDialog.UnlockDialog(Main.layoutManager.uiGroup);
        unlock.add_constraint(new Clutter.BindConstraint({
            source: global.stage, coordinate: Clutter.BindCoordinate.ALL,
        }));
        unlock.open();
        await take('lock-screen');
        unlock.activate();
        await take('lock-prompt');
        unlock.popModal();
        unlock.destroy();
        Main.sessionMode.popMode('unlock-dialog');
        AuthPrompt.AuthPrompt.prototype.begin = begin;
        await sleep(1000);

        write('snapshots.json', JSON.stringify(snapshots));
    }

    async _run() {
        const themeAtStart = themeState();
        await this._snapshots();
        const results = {theme: {start: themeAtStart}};
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

        // Search results still on screen when dusk is disabled: theirs is the
        // icon size disable() has to give back.
        Main.overview.show();
        await sleep(800);
        Main.overview.searchEntry.set_text('set');
        await sleep(1500);
        await Main.extensionManager.disableExtension('dusk@local');
        await sleep(500);
        results.theme.disabled = themeState();
        results['search-on-screen-disabled'] = measureSearchIcons();
        Main.overview.searchEntry.set_text('');
        Main.overview.hide();
        await sleep(1000);
        await Gio.DBus.session.call('org.gnome.Shell',
            '/org/gnome/SessionManager/EndSessionDialog',
            'org.gnome.SessionManager.EndSessionDialog', 'Open',
            new GLib.Variant('(uuuao)', [END_SESSION.logout, 0, 60, []]),
            null, Gio.DBusCallFlags.NONE, -1, null);
        await sleep(1000);
        await measure(results, 'logout-disabled', Main.endSessionDialog.dialogLayout);
        Main.endSessionDialog.close();

        // The overview workspace corners, with dusk on and after disabling it.
        results['workspace'] = this._workspaces;
        Main.overview.show();
        await sleep(1500);
        results['workspace-disabled'] = measureWorkspaces();
        Main.overview.hide();
        await sleep(800);

        // The app grid's icon size, with dusk on and after disabling it.
        results['lock'] = this._lock;
        results['search'] = this._search;
        results['search-disabled'] = await searchIcons('set', 'lock');
        results['app-grid'] = this._appGrid;
        Main.overview.showApps();
        await sleep(1500);
        results['app-grid-disabled'] = measureAppGrid();
        Main.overview.hide();
        await sleep(800);

        // Shell keeps search results for the whole session: enabling dusk
        // again (an update's reload) has to resize the ones it already has.
        await Main.extensionManager.enableExtension('dusk@local');
        await sleep(500);
        results.theme.reenabled = themeState();
        results['search-reenabled'] = await searchIcons('set', 'lock');

        // Ubuntu Dock (when loaded) takes its own search patch off and puts it
        // back when Do Not Disturb changes. This session's settings only.
        const notifications = new Gio.Settings({schema_id: 'org.gnome.desktop.notifications'});
        notifications.set_boolean('show-banners', false);
        await sleep(500);
        notifications.set_boolean('show-banners', true);
        await sleep(500);
        results['search-after-dnd'] = await searchIcons('set', 'lock');

        // An unseen notification shows the indicator (a bell) next to the
        // clock. Low urgency: no banner, which would count as seeing it.
        const unseen = new MessageTray.Notification({
            source: MessageTray.getSystemSource(),
            title: 'Probe notification',
            body: 'Not seen yet',
            urgency: MessageTray.Urgency.LOW,
        });
        MessageTray.getSystemSource().addNotification(unseen);
        await sleep(1500);
        results['clock-indicator'] = await measureClockIndicator();

        // Shell rebuilds its theme on its own: dark/light, High Contrast, and
        // a stylesheet put on top the way User Themes does, each with a menu
        // open. dusk's theme has to come back each time.
        const desktop = new Gio.Settings({schema_id: 'org.gnome.desktop.interface'});
        const a11y = new Gio.Settings({schema_id: 'org.gnome.desktop.a11y.interface'});
        const scheme = desktop.get_string('color-scheme');
        const switches = {};
        const record = async name => {
            await sleep(800);
            switches[name] = {theme: themeState(), records: snapshotStage()};
        };
        const menu = Main.panel.statusArea.quickSettings.menu;
        menu.open();
        await record('open');
        desktop.set_string('color-scheme', scheme === 'prefer-dark' ? 'prefer-light' : 'prefer-dark');
        await record('scheme-switched');
        desktop.set_string('color-scheme', scheme);
        await record('scheme-back');
        a11y.set_boolean('high-contrast', true);
        await record('high-contrast');
        a11y.set_boolean('high-contrast', false);
        await record('high-contrast-off');
        write('foreign.css', '#panel { background-color: red; }\n');
        Main.setThemeStylesheet(`${OUT}/foreign.css`);
        Main.loadTheme();
        await record('foreign');
        Main.setThemeStylesheet(null);
        Main.loadTheme();
        await record('foreign-gone');
        menu.close();
        write('switches.json', JSON.stringify(switches));

        write('result.json', JSON.stringify(results, null, 1));
        write('done', 'ok');
    }
}
