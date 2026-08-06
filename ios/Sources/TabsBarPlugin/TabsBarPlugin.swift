import Capacitor
import UIKit

private struct ConfigureRequest: Decodable {
    let items: [TabsBarItem]
    let initialId: String?
    let visible: Bool?
    let selectedIconColor: String?
    let unselectedIconColor: String?
}

private struct SelectRequest: Decodable {
    let id: String
}

private struct SetBadgeRequest: Decodable {
    let id: String
    let value: BadgeUpdate
}

private enum BadgeUpdate: Decodable {
    case set(TabsBarBadge)
    case clear

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .clear
        } else {
            self = .set(try TabsBarBadge(from: decoder))
        }
    }

    var badge: TabsBarBadge? {
        switch self {
        case .set(let badge):
            return badge
        case .clear:
            return nil
        }
    }
}

@objc(TabsBarPlugin)
public final class TabsBarPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "TabsBarPlugin"
    public let jsName = "TabsBar"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "configure", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "show", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "hide", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "select", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setBadge", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getSafeAreaInsets", returnType: CAPPluginReturnPromise)
    ]

    private var overlay: TabsBarOverlay?

    @objc func configure(_ call: CAPPluginCall) {
        let request: ConfigureRequest
        do {
            request = try call.decode(ConfigureRequest.self)
        } catch {
            call.reject("Invalid tab bar configuration", nil, error)
            return
        }

        if let message = validate(request) {
            call.reject(message)
            return
        }

        let selectedColor = ColorParser.parse(request.selectedIconColor)
        let unselectedColor = ColorParser.parse(request.unselectedIconColor)
        if request.selectedIconColor != nil && selectedColor == nil {
            call.reject("Invalid selectedIconColor")
            return
        }
        if request.unselectedIconColor != nil && unselectedColor == nil {
            call.reject("Invalid unselectedIconColor")
            return
        }

        DispatchQueue.main.async {
            if let item = request.items.first(where: { UIImage(systemName: $0.systemIcon) == nil }) {
                call.reject("Unknown SF Symbol for this iOS version: \(item.systemIcon)")
                return
            }
            guard let overlay = self.ensureOverlay() else {
                call.reject("Unable to attach the tab bar to the Capacitor view")
                return
            }
            overlay.update(
                items: request.items,
                initialId: request.initialId,
                visible: request.visible ?? true,
                selectedColor: selectedColor,
                unselectedColor: unselectedColor
            )
            call.resolve()
        }
    }

    @objc func show(_ call: CAPPluginCall) {
        withOverlay(call) { $0.view.isHidden = false }
    }

    @objc func hide(_ call: CAPPluginCall) {
        withOverlay(call) { $0.view.isHidden = true }
    }

    @objc func select(_ call: CAPPluginCall) {
        let request: SelectRequest
        do {
            request = try call.decode(SelectRequest.self)
        } catch {
            call.reject("A tab id is required", nil, error)
            return
        }

        DispatchQueue.main.async {
            guard let overlay = self.overlay else {
                call.reject("Tab bar is not configured")
                return
            }
            guard overlay.select(id: request.id) else {
                call.reject("Unknown tab id: \(request.id)")
                return
            }
            call.resolve()
        }
    }

    @objc func setBadge(_ call: CAPPluginCall) {
        let request: SetBadgeRequest
        do {
            request = try call.decode(SetBadgeRequest.self)
        } catch {
            call.reject("Invalid badge options", nil, error)
            return
        }

        DispatchQueue.main.async {
            guard let overlay = self.overlay else {
                call.reject("Tab bar is not configured")
                return
            }
            guard overlay.setBadge(id: request.id, value: request.value.badge) else {
                call.reject("Unknown tab id: \(request.id)")
                return
            }
            call.resolve()
        }
    }

    @objc func getSafeAreaInsets(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            guard let view = self.bridge?.viewController?.view else {
                call.reject("Capacitor view is unavailable")
                return
            }
            let insets = view.safeAreaInsets
            call.resolve([
                "top": Double(insets.top),
                "bottom": Double(insets.bottom),
                "left": Double(insets.left),
                "right": Double(insets.right)
            ])
        }
    }

    private func validate(_ request: ConfigureRequest) -> String? {
        guard !request.items.isEmpty else {
            return "At least one tab item is required"
        }
        guard request.items.count <= 5 else {
            return "The native tab bar supports at most five items"
        }

        var ids = Set<String>()
        for item in request.items {
            guard !item.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return "Every tab item must have a non-empty id"
            }
            guard ids.insert(item.id).inserted else {
                return "Duplicate tab id: \(item.id)"
            }
            guard !item.systemIcon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return "Tab \(item.id) must have a systemIcon"
            }
        }

        if let initialId = request.initialId, !ids.contains(initialId) {
            return "Unknown initial tab id: \(initialId)"
        }
        return nil
    }

    private func withOverlay(
        _ call: CAPPluginCall,
        action: @escaping (TabsBarOverlay) -> Void
    ) {
        DispatchQueue.main.async {
            guard let overlay = self.overlay else {
                call.reject("Tab bar is not configured")
                return
            }
            action(overlay)
            call.resolve()
        }
    }

    private func ensureOverlay() -> TabsBarOverlay? {
        if let overlay {
            return overlay
        }
        guard let host = bridge?.viewController else {
            return nil
        }

        let overlay = TabsBarOverlay()
        overlay.onSelected = { [weak self] id in
            self?.notifyListeners("selected", data: ["id": id])
        }

        host.addChild(overlay)
        overlay.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.addSubview(overlay.view)
        let topConstraint = overlay.view.topAnchor.constraint(
            equalTo: host.view.safeAreaLayoutGuide.bottomAnchor,
            constant: -overlay.contentHeight
        )
        overlay.onContentHeightChange = { [weak topConstraint] height in
            topConstraint?.constant = -height
        }
        NSLayoutConstraint.activate([
            overlay.view.leadingAnchor.constraint(equalTo: host.view.leadingAnchor),
            overlay.view.trailingAnchor.constraint(equalTo: host.view.trailingAnchor),
            topConstraint,
            overlay.view.bottomAnchor.constraint(equalTo: host.view.bottomAnchor)
        ])
        overlay.didMove(toParent: host)

        self.overlay = overlay
        return overlay
    }
}

private enum ColorParser {
    static func parse(_ value: String?) -> UIColor? {
        guard let value else {
            return nil
        }
        let color = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if color.hasPrefix("#") {
            return parseHex(String(color.dropFirst()))
        }
        return parseFunctional(color)
    }

    private static func parseHex(_ hex: String) -> UIColor? {
        if hex.count == 3 {
            let values = hex.compactMap { Int(String($0), radix: 16) }
            guard values.count == 3 else { return nil }
            return UIColor(
                red: CGFloat(values[0] * 17) / 255,
                green: CGFloat(values[1] * 17) / 255,
                blue: CGFloat(values[2] * 17) / 255,
                alpha: 1
            )
        }

        guard (hex.count == 6 || hex.count == 8), let value = UInt64(hex, radix: 16) else {
            return nil
        }
        let hasAlpha = hex.count == 8
        let redShift = hasAlpha ? 24 : 16
        let greenShift = hasAlpha ? 16 : 8
        let blueShift = hasAlpha ? 8 : 0
        let alpha = hasAlpha ? CGFloat(value & 0xff) / 255 : 1
        return UIColor(
            red: CGFloat((value >> redShift) & 0xff) / 255,
            green: CGFloat((value >> greenShift) & 0xff) / 255,
            blue: CGFloat((value >> blueShift) & 0xff) / 255,
            alpha: alpha
        )
    }

    private static func parseFunctional(_ value: String) -> UIColor? {
        let lowercased = value.lowercased()
        let prefix: String
        let expectedCount: Int
        if lowercased.hasPrefix("rgba(") {
            prefix = "rgba("
            expectedCount = 4
        } else if lowercased.hasPrefix("rgb(") {
            prefix = "rgb("
            expectedCount = 3
        } else {
            return nil
        }
        guard value.hasSuffix(")") else { return nil }

        let body = value.dropFirst(prefix.count).dropLast()
        let components = body.split(separator: ",", omittingEmptySubsequences: false).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard components.count == expectedCount,
              let red = Double(components[0]),
              let green = Double(components[1]),
              let blue = Double(components[2]) else {
            return nil
        }
        let alpha = expectedCount == 4 ? Double(components[3]) : 1
        guard let alpha,
              (0...255).contains(red),
              (0...255).contains(green),
              (0...255).contains(blue),
              (0...1).contains(alpha) else {
            return nil
        }

        return UIColor(
            red: CGFloat(red) / 255,
            green: CGFloat(green) / 255,
            blue: CGFloat(blue) / 255,
            alpha: CGFloat(alpha)
        )
    }
}
