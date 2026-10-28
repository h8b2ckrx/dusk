// dusk ships only a stylesheet. GNOME Shell loads stylesheet-dark.css or
// stylesheet-light.css from this folder while the extension is enabled, so
// there's nothing to do here.
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

export default class DuskExtension extends Extension {
    enable() {}

    disable() {}
}
