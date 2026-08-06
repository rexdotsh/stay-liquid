import UIKit

enum TabsBarBadge: Decodable {
    case number(Int)
    case dot

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Int.self), value >= 0 {
            self = .number(value)
            return
        }
        if let value = try? container.decode(String.self), value == "dot" {
            self = .dot
            return
        }
        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Badge must be a non-negative integer or 'dot'"
        )
    }
}

struct TabsBarItem: Decodable {
    let id: String
    let title: String?
    let systemIcon: String
    var badge: TabsBarBadge?
}

final class TabsBarOverlay: UIViewController, UITabBarDelegate {
    var onSelected: ((String) -> Void)?
    var onContentHeightChange: ((CGFloat) -> Void)?

    var contentHeight: CGFloat {
        traitCollection.verticalSizeClass == .compact ? 32 : 49
    }

    private let tabBar = UITabBar()
    private var items: [TabsBarItem] = []
    private var idToIndex: [String: Int] = [:]

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        tabBar.delegate = self
        tabBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tabBar)
        NSLayoutConstraint.activate([
            tabBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabBar.topAnchor.constraint(equalTo: view.topAnchor),
            tabBar.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.verticalSizeClass != traitCollection.verticalSizeClass {
            onContentHeightChange?(contentHeight)
        }
    }

    func update(
        items: [TabsBarItem],
        initialId: String?,
        visible: Bool,
        selectedColor: UIColor?,
        unselectedColor: UIColor?
    ) {
        self.items = items
        idToIndex = Dictionary(
            uniqueKeysWithValues: items.enumerated().map { ($0.element.id, $0.offset) }
        )

        tabBar.tintColor = selectedColor
        tabBar.unselectedItemTintColor = unselectedColor
        tabBar.items = items.enumerated().map { index, model in
            let item = UITabBarItem(
                title: model.title,
                image: UIImage(systemName: model.systemIcon),
                tag: index
            )
            applyBadge(model.badge, to: item)
            return item
        }

        let selectedIndex = initialId.flatMap { idToIndex[$0] } ?? 0
        tabBar.selectedItem = tabBar.items?[selectedIndex]
        view.isHidden = !visible
    }

    @discardableResult
    func select(id: String) -> Bool {
        guard let index = idToIndex[id], let item = tabBar.items?[index] else {
            return false
        }
        tabBar.selectedItem = item
        return true
    }

    @discardableResult
    func setBadge(id: String, value: TabsBarBadge?) -> Bool {
        guard let index = idToIndex[id], let item = tabBar.items?[index] else {
            return false
        }
        items[index].badge = value
        applyBadge(value, to: item)
        return true
    }

    func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        guard items.indices.contains(item.tag) else { return }
        onSelected?(items[item.tag].id)
    }

    private func applyBadge(_ badge: TabsBarBadge?, to item: UITabBarItem) {
        switch badge {
        case .number(let value):
            item.badgeValue = value > 0 ? String(value) : nil
        case .dot:
            item.badgeValue = "\u{2022}"
        case nil:
            item.badgeValue = nil
        }
    }
}
