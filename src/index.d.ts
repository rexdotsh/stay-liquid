import type { PluginListenerHandle } from '@capacitor/core';

export type BadgeValue = number | 'dot' | null;

export interface TabItem {
  /** Stable identifier used to synchronize the tab with application routing. */
  id: string;
  title?: string;
  /** SF Symbol displayed by the native tab bar. */
  systemIcon: string;
  badge?: BadgeValue;
}

export interface TabsBarConfigureOptions {
  items: TabItem[];
  initialId?: string;
  /** Whether to show the tab bar after configuration. Defaults to true. */
  visible?: boolean;
  /** Selected icon color as #RGB, #RRGGBB, #RRGGBBAA, rgb(), or rgba(). */
  selectedIconColor?: string;
  /** Unselected icon color in the same formats as selectedIconColor. */
  unselectedIconColor?: string;
}

export interface SelectOptions {
  id: string;
}

export interface SetBadgeOptions {
  id: string;
  /** A non-negative integer, a dot, or null to clear the badge. */
  value: BadgeValue;
}

export interface SafeAreaInsets {
  top: number;
  bottom: number;
  left: number;
  right: number;
}

export interface SelectedEvent {
  id: string;
}

export interface TabsBarPlugin {
  configure(options: TabsBarConfigureOptions): Promise<void>;
  show(): Promise<void>;
  hide(): Promise<void>;
  select(options: SelectOptions): Promise<void>;
  setBadge(options: SetBadgeOptions): Promise<void>;
  getSafeAreaInsets(): Promise<SafeAreaInsets>;
  addListener(
    eventName: 'selected',
    listenerFunc: (event: SelectedEvent) => void,
  ): Promise<PluginListenerHandle>;
}

export declare const TabsBar: TabsBarPlugin;
