# Stay Liquid

Stay Liquid exposes a native iOS `UITabBar` to Capacitor applications. On iOS 26 and later, the bar uses Apple's system Liquid Glass appearance while the application content remains in the Capacitor web view.

The plugin is intentionally iOS-only. Calls made on Android or the web are not implemented, so applications should gate usage with Capacitor's platform APIs.

## Requirements

- Capacitor 8
- iOS 15 or later
- Xcode 26 or later to build and display Liquid Glass on iOS 26

## Installation

The package is currently installed from GitHub:

```sh
npm install github:rexdotsh/stay-liquid
npx cap sync ios
```

Pin a release tag or commit instead of a branch for production applications.

## Usage

```ts
import { Capacitor } from '@capacitor/core';
import { TabsBar } from 'stay-liquid';

if (Capacitor.getPlatform() === 'ios') {
  await TabsBar.configure({
    initialId: 'home',
    items: [
      { id: 'home', title: 'Home', systemIcon: 'house' },
      { id: 'search', title: 'Search', systemIcon: 'magnifyingglass' },
      { id: 'settings', title: 'Settings', systemIcon: 'gear' },
    ],
  });

  const selectionListener = await TabsBar.addListener('selected', ({ id }) => {
    // Synchronize your framework's router here.
    void navigateTo(`/tabs/${id}`);
  });

  // Remove the listener when the owning view is destroyed.
  await selectionListener.remove();
}
```

Hide the framework-provided tab bar while the native bar is active. The exact implementation depends on the framework; in Ionic Angular, a class binding is sufficient:

```html
<ion-tabs [class.native-tabs-active]="useNativeTabs">
  <!-- tab content -->
</ion-tabs>
```

```css
.native-tabs-active ion-tab-bar {
  display: none;
}
```

Keep the native selection synchronized when navigation occurs outside the tab bar:

```ts
await TabsBar.select({ id: 'settings' });
await TabsBar.setBadge({ id: 'settings', value: 3 });
await TabsBar.setBadge({ id: 'settings', value: null });
```

## Configuration

```ts
await TabsBar.configure({
  items: [
    {
      id: 'profile',
      title: 'Profile',
      systemIcon: 'person.crop.circle',
      badge: 'dot',
    },
  ],
  initialId: 'profile',
  visible: true,
  selectedIconColor: '#007AFF',
  unselectedIconColor: 'rgba(142, 142, 147, 0.7)',
});
```

Configure between one and five items. Each item requires a unique `id` and an SF Symbol available on the current iOS version. Configuration rejects duplicate IDs, unknown initial tabs, invalid colors, unavailable symbols, and negative or fractional badge values.

Colors accept `#RGB`, `#RRGGBB`, `#RRGGBBAA`, `rgb()`, and `rgba()` formats. Invalid configuration is rejected rather than silently ignored.

## API

| Method | Description |
| --- | --- |
| `configure(options)` | Creates or updates the native tab bar. |
| `show()` | Shows a configured tab bar. |
| `hide()` | Hides a configured tab bar. |
| `select({ id })` | Selects an existing tab without emitting a user-selection event. |
| `setBadge({ id, value })` | Sets a number, dot, or no badge. |
| `getSafeAreaInsets()` | Returns the host view's current iOS safe-area insets. |
| `addListener('selected', listener)` | Receives native tab selections. |

## Development

```sh
npm run check
```

On macOS with Xcode installed, verify the Swift package with:

```sh
npm run verify:ios
```

## License

MIT. Originally created by [Alistair Heath](https://github.com/alistairheath) and maintained in this fork by [rexdotsh](https://github.com/rexdotsh).
