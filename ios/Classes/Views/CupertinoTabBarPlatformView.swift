import Flutter
import UIKit

final class CupertinoTabBarPlatformView: NSObject, FlutterPlatformView, UITabBarDelegate {

  private let channel: FlutterMethodChannel
  private let container: UIView

  private var tabBar: UITabBar?
  private var tabBarLeft: UITabBar?
  private var tabBarRight: UITabBar?

  private var isSplit: Bool = false
  private var rightCountVal: Int = 1
  private var currentLabels: [String] = []
  private var currentSymbols: [String] = []
  private var leftInsetVal: CGFloat = 0
  private var rightInsetVal: CGFloat = 0
  private var splitSpacingVal: CGFloat = 8

  // Locale direction
  private var isRTL: Bool = false

  // Style state (needed for rebuilds)
  private var isDarkVal: Bool = false
  private var tintVal: UIColor? = nil
  private var bgVal: UIColor? = nil

  // Dim overlay to match Flutter modal barrier (legacy fields kept but unused now)
  private var dimView: UIView?
  private var dimOverlay: UIView?
  private var dimBlurView: UIVisualEffectView?
  private var dimTintView: UIView?
  private var blurAnimator: UIViewPropertyAnimator?

  // Dedicated container to hide the native view
  private var dimContainer: UIView?
  private var dimTopStrip: UIView?

  init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    self.channel = FlutterMethodChannel(
      name: "CupertinoNativeTabBar_\(viewId)",
      binaryMessenger: messenger
    )
    self.container = UIView(frame: frame)

    var labels: [String] = []
    var symbols: [String] = []
    var selectedIndex: Int = 0
    var isDark: Bool = false
    var tint: UIColor? = nil
    var bg: UIColor? = nil
    var split: Bool = false
    var rightCount: Int = 1
    var rtlArg: Bool = false
    var leftInset: CGFloat = 0
    var rightInset: CGFloat = 0

    if let dict = args as? [String: Any] {
      labels = (dict["labels"] as? [String]) ?? []
      symbols = (dict["sfSymbols"] as? [String]) ?? []
      if let v = dict["selectedIndex"] as? NSNumber { selectedIndex = v.intValue }
      if let v = dict["isDark"] as? NSNumber { isDark = v.boolValue }
      if let v = dict["isRTL"] as? NSNumber { rtlArg = v.boolValue }

      if let style = dict["style"] as? [String: Any] {
        if let n = style["tint"] as? NSNumber { tint = Self.colorFromARGB(n.intValue) }
        if let n = style["backgroundColor"] as? NSNumber { bg = Self.colorFromARGB(n.intValue) }
      }

      if let s = dict["split"] as? NSNumber { split = s.boolValue }
      if let rc = dict["rightCount"] as? NSNumber { rightCount = rc.intValue }
      if let sp = dict["splitSpacing"] as? NSNumber { splitSpacingVal = CGFloat(truncating: sp) }

      // optional (if you ever pass them)
      if let li = dict["leftInset"] as? NSNumber { leftInset = CGFloat(truncating: li) }
      if let ri = dict["rightInset"] as? NSNumber { rightInset = CGFloat(truncating: ri) }
    }

    super.init()

    // Store state
    self.isDarkVal = isDark
    self.tintVal = tint
    self.bgVal = bg
    self.isRTL = rtlArg
    self.isSplit = split
    self.rightCountVal = rightCount
    self.currentLabels = labels
    self.currentSymbols = symbols
    self.leftInsetVal = leftInset
    self.rightInsetVal = rightInset

    // Container (keep opaque to avoid bleed artifacts)
    let resolvedBG = resolveBackgroundColor(bg: bg, isDark: isDark)
    container.isOpaque = true
    container.backgroundColor = resolvedBG
    container.clipsToBounds = true
    if #available(iOS 13.0, *) { container.overrideUserInterfaceStyle = isDark ? .dark : .light }
    applySemanticDirection()

    // Build initial bars
    rebuildBars(selectedIndex: selectedIndex)

    // Channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }

      switch call.method {

      case "getIntrinsicSize":
        if let bar = self.tabBar ?? self.tabBarLeft ?? self.tabBarRight {
          let size = bar.sizeThatFits(
            CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
          )
          result(["width": Double(size.width), "height": Double(size.height)])
        } else {
          result(["width": Double(self.container.bounds.width), "height": 50.0])
        }

      case "setModalDimmed":
        let args = call.arguments as? [String: Any]
        let dimmed = (args?["dimmed"] as? NSNumber)?.boolValue ?? false

        let colorInt = (args?["color"] as? NSNumber)?.intValue
        let color = colorInt != nil
        ? Self.colorFromARGB(colorInt!)
        : UIColor.red // default to solid black for maximum coverage

        let blurSigma = (args?["blurSigma"] as? NSNumber)?.doubleValue ?? 0.0

        self.setDimmed(dimmed, color: color, blurSigma: blurSigma)
        result(nil)

      case "setItems":
        guard let args = call.arguments as? [String: Any] else {
          result(FlutterError(code: "bad_args", message: "Missing items", details: nil))
          return
        }
        self.currentLabels = (args["labels"] as? [String]) ?? []
        self.currentSymbols = (args["sfSymbols"] as? [String]) ?? []
        let selectedIndex = (args["selectedIndex"] as? NSNumber)?.intValue ?? 0
        self.rebuildBars(selectedIndex: selectedIndex)
        result(nil)

      case "setLayout":
        guard let args = call.arguments as? [String: Any] else {
          result(FlutterError(code: "bad_args", message: "Missing layout", details: nil))
          return
        }

        self.isSplit = (args["split"] as? NSNumber)?.boolValue ?? self.isSplit
        self.rightCountVal = (args["rightCount"] as? NSNumber)?.intValue ?? self.rightCountVal
        if let sp = args["splitSpacing"] as? NSNumber { self.splitSpacingVal = CGFloat(truncating: sp) }

        if let rtl = args["isRTL"] as? NSNumber { self.isRTL = rtl.boolValue; self.applySemanticDirection() }

        let selectedIndex = (args["selectedIndex"] as? NSNumber)?.intValue ?? 0
        self.rebuildBars(selectedIndex: selectedIndex)
        result(nil)

      case "setSelectedIndex":
        guard let args = call.arguments as? [String: Any],
              let idx = (args["index"] as? NSNumber)?.intValue else {
          result(FlutterError(code: "bad_args", message: "Missing index", details: nil))
          return
        }
        self.applySelectedIndex(idx)
        result(nil)

      case "setStyle":
        guard let args = call.arguments as? [String: Any] else {
          result(FlutterError(code: "bad_args", message: "Missing style", details: nil))
          return
        }

        if let n = args["tint"] as? NSNumber { self.tintVal = Self.colorFromARGB(n.intValue) }
        if let n = args["backgroundColor"] as? NSNumber { self.bgVal = Self.colorFromARGB(n.intValue) }
        if let rtl = args["isRTL"] as? NSNumber { self.isRTL = rtl.boolValue }

        let resolvedBG = self.resolveBackgroundColor(bg: self.bgVal, isDark: self.isDarkVal)
        self.container.isOpaque = true
        self.container.backgroundColor = resolvedBG
        self.container.clipsToBounds = true

        self.applySemanticDirection()
        self.applyAppearanceToExistingBars()
        result(nil)

      case "setBrightness":
        guard let args = call.arguments as? [String: Any],
              let isDark = (args["isDark"] as? NSNumber)?.boolValue else {
          result(FlutterError(code: "bad_args", message: "Missing isDark", details: nil))
          return
        }

        self.isDarkVal = isDark
        if #available(iOS 13.0, *) { self.container.overrideUserInterfaceStyle = isDark ? .dark : .light }

        let resolvedBG = self.resolveBackgroundColor(bg: self.bgVal, isDark: self.isDarkVal)
        self.container.isOpaque = true
        self.container.backgroundColor = resolvedBG
        self.container.clipsToBounds = true

        self.applyAppearanceToExistingBars()
        result(nil)

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func view() -> UIView { container }

  // MARK: - UITabBarDelegate

  func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
    // Single bar
    if let single = self.tabBar, single === tabBar, let items = single.items, let idx = items.firstIndex(of: item) {
      channel.invokeMethod("valueChanged", arguments: ["index": idx])
      return
    }
    // Split left
    if let left = tabBarLeft, left === tabBar, let items = left.items, let idx = items.firstIndex(of: item) {
      tabBarRight?.selectedItem = nil
      channel.invokeMethod("valueChanged", arguments: ["index": idx])
      return
    }
    // Split right
    if let right = tabBarRight, right === tabBar, let items = right.items, let idx = items.firstIndex(of: item),
       let left = tabBarLeft, let leftItems = left.items {
      tabBarLeft?.selectedItem = nil
      channel.invokeMethod("valueChanged", arguments: ["index": leftItems.count + idx])
      return
    }
  }

  // MARK: - Dimming

  private func setDimmed(_ dimmed: Bool, color: UIColor, blurSigma: Double) {
    // We ignore blurSigma and do not use blur or tint anymore.
    if !dimmed {
      dimContainer?.removeFromSuperview()
      dimContainer = nil
      dimView = nil
      dimOverlay = nil
      dimBlurView = nil
      dimTintView = nil
      blurAnimator?.stopAnimation(true)
      blurAnimator = nil
      return
    }

    // Build a single solid overlay if needed
    if dimContainer == nil {
      let overlay = UIView()
      overlay.translatesAutoresizingMaskIntoConstraints = false
      overlay.isUserInteractionEnabled = false
      overlay.isOpaque = true
      overlay.clipsToBounds = false

      container.addSubview(overlay)

      // Extend beyond all edges to guarantee no hairline seams
      let extend: CGFloat = 6.0
      NSLayoutConstraint.activate([
        overlay.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: -extend),
        overlay.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: extend),
        overlay.topAnchor.constraint(equalTo: container.topAnchor, constant: -extend),
        overlay.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: extend)
      ])

      dimContainer = overlay
      dimView = overlay
      dimOverlay = overlay

      // Respect semantic direction
      applySemanticDirection()
    }

    // Solid color to hide native view entirely
    dimContainer?.backgroundColor = color
    dimContainer?.isHidden = false
    if let overlay = dimContainer { container.bringSubviewToFront(overlay) }
  }

  // MARK: - Build / Update

  private func rebuildBars(selectedIndex: Int) {
    // Remove old
    tabBar?.removeFromSuperview(); tabBar = nil
    tabBarLeft?.removeFromSuperview(); tabBarLeft = nil
    tabBarRight?.removeFromSuperview(); tabBarRight = nil

    let labels = currentLabels
    let symbols = currentSymbols
    let count = max(labels.count, symbols.count)

    func buildItems(_ range: Range<Int>) -> [UITabBarItem] {
      var items: [UITabBarItem] = []
      for i in range {
        let title = (i < labels.count) ? labels[i] : nil
        let image: UIImage? = (i < symbols.count) ? resolveIcon(symbols[i]) : nil
        items.append(UITabBarItem(title: title, image: image, selectedImage: image))
      }
      return items
    }

    if isSplit && count > rightCountVal {
      let leftEnd = count - rightCountVal

      let left = UITabBar(frame: .zero)
      let right = UITabBar(frame: .zero)
      tabBarLeft = left
      tabBarRight = right

      left.translatesAutoresizingMaskIntoConstraints = false
      right.translatesAutoresizingMaskIntoConstraints = false
      left.delegate = self
      right.delegate = self

      applyBarAppearance(left)
      applyBarAppearance(right)

      left.items = buildItems(0..<leftEnd)
      right.items = buildItems(leftEnd..<count)

      if selectedIndex < leftEnd, let items = left.items {
        left.selectedItem = items[selectedIndex]
        right.selectedItem = nil
      } else if let items = right.items {
        let idx = selectedIndex - leftEnd
        if idx >= 0 && idx < items.count { right.selectedItem = items[idx] }
        left.selectedItem = nil
      }

      container.addSubview(left)
      container.addSubview(right)

      let spacing: CGFloat = splitSpacingVal
      let leftWidth = left.sizeThatFits(.zero).width + leftInsetVal * 2
      let rightWidth = right.sizeThatFits(.zero).width + rightInsetVal * 2
      let total = leftWidth + rightWidth + spacing

      if total > container.bounds.width {
        let rightFraction = CGFloat(rightCountVal) / CGFloat(max(1, count))
        NSLayoutConstraint.activate([
          right.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -rightInsetVal),
          right.topAnchor.constraint(equalTo: container.topAnchor),
          right.bottomAnchor.constraint(equalTo: container.bottomAnchor),
          right.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: rightFraction),

          left.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: leftInsetVal),
          left.trailingAnchor.constraint(equalTo: right.leadingAnchor, constant: -spacing),
          left.topAnchor.constraint(equalTo: container.topAnchor),
          left.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
      } else {
        NSLayoutConstraint.activate([
          right.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -rightInsetVal),
          right.topAnchor.constraint(equalTo: container.topAnchor),
          right.bottomAnchor.constraint(equalTo: container.bottomAnchor),
          right.widthAnchor.constraint(equalToConstant: rightWidth),

          left.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: leftInsetVal),
          left.topAnchor.constraint(equalTo: container.topAnchor),
          left.bottomAnchor.constraint(equalTo: container.bottomAnchor),
          left.widthAnchor.constraint(equalToConstant: leftWidth),

          left.trailingAnchor.constraint(lessThanOrEqualTo: right.leadingAnchor, constant: -spacing),
        ])
      }
    } else {
      let bar = UITabBar(frame: .zero)
      tabBar = bar

      bar.delegate = self
      bar.translatesAutoresizingMaskIntoConstraints = false

      applyBarAppearance(bar)

      bar.items = buildItems(0..<count)
      if selectedIndex >= 0, let items = bar.items, selectedIndex < items.count {
        bar.selectedItem = items[selectedIndex]
      }

      container.addSubview(bar)
      NSLayoutConstraint.activate([
        bar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
        bar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        bar.topAnchor.constraint(equalTo: container.topAnchor),
        bar.bottomAnchor.constraint(equalTo: container.bottomAnchor),
      ])
    }

    applySemanticDirection()

    // Keep overlay (if currently visible) on top
    if let v = dimContainer, v.isHidden == false {
      container.bringSubviewToFront(v)
    }
  }

  private func applySelectedIndex(_ idx: Int) {
    if let bar = tabBar, let items = bar.items, idx >= 0, idx < items.count {
      bar.selectedItem = items[idx]
      return
    }

    if let left = tabBarLeft, let leftItems = left.items {
      if idx < leftItems.count, idx >= 0 {
        left.selectedItem = leftItems[idx]
        tabBarRight?.selectedItem = nil
        return
      }
      if let right = tabBarRight, let rightItems = right.items {
        let ridx = idx - leftItems.count
        if ridx >= 0, ridx < rightItems.count {
          right.selectedItem = rightItems[ridx]
          tabBarLeft?.selectedItem = nil
          return
        }
      }
    }
  }

  private func applyAppearanceToExistingBars() {
    if let bar = tabBar { applyBarAppearance(bar) }
    if let left = tabBarLeft { applyBarAppearance(left) }
    if let right = tabBarRight { applyBarAppearance(right) }
    applySemanticDirection()
    if let v = dimContainer, v.isHidden == false { container.bringSubviewToFront(v) }
  }

  // MARK: - Locale / Appearance

  private func applySemanticDirection() {
    let semantic: UISemanticContentAttribute = isRTL ? .forceRightToLeft : .forceLeftToRight
    container.semanticContentAttribute = semantic
    tabBar?.semanticContentAttribute = semantic
    tabBarLeft?.semanticContentAttribute = semantic
    tabBarRight?.semanticContentAttribute = semantic
    dimContainer?.semanticContentAttribute = semantic
  }

  private func applyBarAppearance(_ bar: UITabBar) {
    let resolvedBG = resolveBackgroundColor(bg: bgVal, isDark: isDarkVal)

    // Opaque always (prevents bleed / mismatch)
    bar.isTranslucent = false
    bar.backgroundColor = resolvedBG
    bar.barTintColor = resolvedBG
    bar.clipsToBounds = true
    bar.layer.masksToBounds = true

    // Remove default shadow/separator
    if #available(iOS 13.0, *) {
      let ap = UITabBarAppearance()
      ap.configureWithOpaqueBackground()
      ap.backgroundColor = resolvedBG
      ap.backgroundEffect = nil
      ap.shadowColor = .clear
      ap.shadowImage = UIImage()

      if let tint = tintVal {
        ap.stackedLayoutAppearance.selected.iconColor = tint
        ap.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: tint]
        let normal = tint.withAlphaComponent(0.6)
        ap.stackedLayoutAppearance.normal.iconColor = normal
        ap.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: normal]
      }

      bar.standardAppearance = ap
      if #available(iOS 15.0, *) { bar.scrollEdgeAppearance = ap }
    } else {
      bar.shadowImage = UIImage()
      bar.backgroundImage = UIImage()
    }

    if #available(iOS 10.0, *), let tint = tintVal {
      bar.tintColor = tint
      bar.unselectedItemTintColor = tint.withAlphaComponent(0.6)
    }

    bar.semanticContentAttribute = isRTL ? .forceRightToLeft : .forceLeftToRight
  }

  // MARK: - Icons

  private func resolveIcon(_ name: String) -> UIImage? {
    // Prefer Runner assets first to avoid SF Symbol collisions
    if let asset = UIImage(named: name) {
      return asset.withRenderingMode(.alwaysTemplate)
    }
    if let sf = UIImage(systemName: name) {
      return sf
    }
    return nil
  }

  // MARK: - Helpers

  private func resolveBackgroundColor(bg: UIColor?, isDark: Bool) -> UIColor {
    if let bg = bg { return bg }
    return isDark ? .black : .white
  }

  private static func colorFromARGB(_ argb: Int) -> UIColor {
    let a = CGFloat((argb >> 24) & 0xFF) / 255.0
    let r = CGFloat((argb >> 16) & 0xFF) / 255.0
    let g = CGFloat((argb >> 8) & 0xFF) / 255.0
    let b = CGFloat(argb & 0xFF) / 255.0
    return UIColor(red: r, green: g, blue: b, alpha: a)
  }
}
