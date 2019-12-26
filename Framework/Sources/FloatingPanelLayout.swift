//
//  Created by Shin Yamamoto on 2018/09/27.
//  Copyright © 2018 Shin Yamamoto. All rights reserved.
//

import UIKit

/// FloatingPanelFullScreenLayout
///
/// Use the layout protocol if you configure full, half and tip insets from the superview, not the safe area.
/// It can't be used with FloatingPanelIntrinsicLayout.
public protocol FloatingPanelFullScreenLayout: FloatingPanelLayout { }

public extension FloatingPanelFullScreenLayout {
    var positionReference: FloatingPanelLayoutReference {
        return .fromSuperview
    }
}

/// FloatingPanelIntrinsicLayout
///
/// Use the layout protocol if you want to layout a panel using the intrinsic height.
/// It can't be used with `FloatingPanelFullScreenLayout`.
///
/// - Attention:
///     `insetFor(position:)` must return `nil` for the full position. Because
///     the inset is determined automatically by the intrinsic height.
///     You can customize insets only for the half, tip and hidden positions.
///
/// - Note:
///     By default, the `positionReference` is set to `.fromSafeArea`.
public protocol FloatingPanelIntrinsicLayout: FloatingPanelLayout { }

public extension FloatingPanelIntrinsicLayout {
    var initialPosition: FloatingPanelPosition {
        return .full
    }

    var supportedPositions: Set<FloatingPanelPosition> {
        return [.full]
    }

    func insetFor(position: FloatingPanelPosition) -> CGFloat? {
        return nil
    }

    var positionReference: FloatingPanelLayoutReference {
        return .fromSafeArea
    }
}

public enum FloatingPanelLayoutReference: Int {
    case fromSafeArea = 0
    case fromSuperview = 1
}

public protocol FloatingPanelLayout: class {
    /// Returns the initial position of a floating panel.
    var initialPosition: FloatingPanelPosition { get }

    /// Returns a set of FloatingPanelPosition objects to tell the applicable
    /// positions of the floating panel controller.
    ///
    /// By default, it returns full, half and tip positions.
    var supportedPositions: Set<FloatingPanelPosition> { get }

    /// Return the interaction buffer to the top from the top position. Default is 6.0.
    var topInteractionBuffer: CGFloat { get }

    /// Return the interaction buffer to the bottom from the bottom position. Default is 6.0.
    ///
    /// - Important:
    /// The specified buffer is ignored when `FloatingPanelController.isRemovalInteractionEnabled` is set to true.
    var bottomInteractionBuffer: CGFloat { get }

    /// Returns a CGFloat value to determine a Y coordinate of a floating panel for each position(full, half, tip and hidden).
    ///
    /// Its returning value indicates a different inset for each position.
    /// For full position, a top inset from a safe area in `FloatingPanelController.view`.
    /// For half or tip position, a bottom inset from the safe area.
    /// For hidden position, a bottom inset from `FloatingPanelController.view`.
    /// If a position isn't supported or the default value is used, return nil.
    func insetFor(position: FloatingPanelPosition) -> CGFloat?

    /// Returns X-axis and width layout constraints of the surface view of a floating panel.
    /// You must not include any Y-axis and height layout constraints of the surface view
    /// because their constraints will be configured by the floating panel controller.
    /// By default, the width of a surface view fits a safe area.
    func prepareLayout(surfaceView: UIView, in view: UIView) -> [NSLayoutConstraint]

    /// Returns a CGFloat value to determine the backdrop view's alpha for a position.
    ///
    /// Default is 0.3 at full position, otherwise 0.0.
    func backdropAlphaFor(position: FloatingPanelPosition) -> CGFloat

    var positionReference: FloatingPanelLayoutReference { get }

    var interactiveEdge: FloatingPanelRectEdge { get }
}

public enum FloatingPanelRectEdge: Int {
    case top
    case bottom
}

public extension FloatingPanelLayout {
    var topInteractionBuffer: CGFloat { return 6.0 }
    var bottomInteractionBuffer: CGFloat { return 6.0 }

    var supportedPositions: Set<FloatingPanelPosition> {
        return Set([.full, .half, .tip])
    }

    func prepareLayout(surfaceView: UIView, in view: UIView) -> [NSLayoutConstraint] {
        return [
            surfaceView.leftAnchor.constraint(equalTo: view.sideLayoutGuide.leftAnchor, constant: 0.0),
            surfaceView.rightAnchor.constraint(equalTo: view.sideLayoutGuide.rightAnchor, constant: 0.0),
        ]
    }

    func backdropAlphaFor(position: FloatingPanelPosition) -> CGFloat {
        return position == .full ? 0.3 : 0.0
    }

    var positionReference: FloatingPanelLayoutReference {
        return .fromSafeArea
    }
    var interactiveEdge: FloatingPanelRectEdge {
        return .top
    }
}

public class FloatingPanelDefaultLayout: FloatingPanelLayout {
    public init() { }

    public var initialPosition: FloatingPanelPosition {
        return .half
    }

    public func insetFor(position: FloatingPanelPosition) -> CGFloat? {
        switch position {
        case .full: return 18.0
        case .half: return 262.0
        case .tip: return 69.0
        case .hidden: return nil
        }
    }
}

public class FloatingPanelDefaultLandscapeLayout: FloatingPanelLayout {
    public init() { }

    public var initialPosition: FloatingPanelPosition {
        return .tip
    }
    public var supportedPositions: Set<FloatingPanelPosition> {
        return [.full, .tip]
    }

    public func insetFor(position: FloatingPanelPosition) -> CGFloat? {
        switch position {
        case .full: return 16.0
        case .tip: return 69.0
        default: return nil
        }
    }
}

struct LayoutSegment {
    let lower: FloatingPanelPosition?
    let upper: FloatingPanelPosition?
}

class FloatingPanelLayoutAdapter {
    weak var vc: FloatingPanelController!
    private weak var surfaceView: FloatingPanelSurfaceView!
    private weak var backdropView: FloatingPanelBackdropView!

    var layout: FloatingPanelLayout {
        didSet {
            surfaceView.interactiveEdge = layout.interactiveEdge
            checkLayoutConsistance()
        }
    }

    private var safeAreaInsets: UIEdgeInsets {
        return vc?.layoutInsets ?? .zero
    }

    private var initialConst: CGFloat = 0.0

    private var fixedConstraints: [NSLayoutConstraint] = []
    private var fullConstraints: [NSLayoutConstraint] = []
    private var halfConstraints: [NSLayoutConstraint] = []
    private var tipConstraints: [NSLayoutConstraint] = []
    private var offConstraints: [NSLayoutConstraint] = []
    private var fitToBoundsConstraint: NSLayoutConstraint?

    private(set) var interactiveEdgeConstraint: NSLayoutConstraint?

    private var heightConstraint: NSLayoutConstraint?

    private var fullInset: CGFloat {
        if layout is FloatingPanelIntrinsicLayout {
            return intrinsicHeight
        } else {
            return layout.insetFor(position: .full) ?? 0.0
        }
    }
    private var halfInset: CGFloat {
        return layout.insetFor(position: .half) ?? 0.0
    }
    private var tipInset: CGFloat {
        return layout.insetFor(position: .tip) ?? 0.0
    }
    private var hiddenInset: CGFloat {
        return layout.insetFor(position: .hidden) ?? 0.0
    }

    var supportedPositions: Set<FloatingPanelPosition> {
        return layout.supportedPositions
    }

    var topMostState: FloatingPanelPosition {
        switch layout.interactiveEdge {
        case .top:
            return supportedPositions.sorted(by: { $0.rawValue < $1.rawValue }).first ?? .hidden
        case .bottom:
            return supportedPositions.sorted(by: { $0.rawValue < $1.rawValue }).last ?? .hidden
        }
    }

    var bottomMostState: FloatingPanelPosition {
        switch layout.interactiveEdge {
        case .top:
            return supportedPositions.sorted(by: { $0.rawValue < $1.rawValue }).last ?? .hidden
        case .bottom:
            return supportedPositions.sorted(by: { $0.rawValue < $1.rawValue }).first ?? .hidden
        }
    }

    var topY: CGFloat {
        return positionY(for: topMostState)
    }

    var bottomY: CGFloat {
        return positionY(for: bottomMostState)
    }

    var topMaxY: CGFloat {
        return topY - layout.topInteractionBuffer
    }

    var bottomMaxY: CGFloat {
        return bottomY + layout.bottomInteractionBuffer
    }

    var adjustedContentInsets: UIEdgeInsets {
        switch layout.interactiveEdge {
        case .top:
            return UIEdgeInsets(top: 0.0,
                                left: 0.0,
                                bottom: safeAreaInsets.bottom,
                                right: 0.0)
        case .bottom:
            return UIEdgeInsets(top: safeAreaInsets.top,
                                left: 0.0,
                                bottom: 0.0,
                                right: 0.0)
        }
    }

    func positionY(for pos: FloatingPanelPosition) -> CGFloat {
        let bounds = surfaceView.superview!.bounds
        switch pos {
        case .full:
            switch layout.interactiveEdge {
            case .top:
                if layout is FloatingPanelIntrinsicLayout {
                    return bounds.height - intrinsicHeight
                }
                switch layout.positionReference {
                case .fromSafeArea:
                    return (safeAreaInsets.top + fullInset)
                case .fromSuperview:
                    return fullInset
                }
            case .bottom:
                if layout is FloatingPanelIntrinsicLayout {
                    return intrinsicHeight
                }
                switch layout.positionReference {
                case .fromSafeArea:
                    return bounds.height - (safeAreaInsets.bottom + fullInset)
                case .fromSuperview:
                    return bounds.height - fullInset
                }
            }
        case .half:
            switch layout.interactiveEdge {
            case .top:
                switch layout.positionReference {
                case .fromSafeArea:
                    return bounds.height - (safeAreaInsets.bottom + halfInset)
                case .fromSuperview:
                    return bounds.height - halfInset
                }
            case .bottom:
                switch layout.positionReference {
                case .fromSafeArea:
                    return safeAreaInsets.top + halfInset
                case .fromSuperview:
                    return halfInset
                }
            }
        case .tip:
            switch layout.interactiveEdge {
            case .top:
                switch layout.positionReference {
                case .fromSafeArea:
                    return bounds.height - (safeAreaInsets.bottom + tipInset)
                case .fromSuperview:
                    return bounds.height - tipInset
                }
            case .bottom:
                switch layout.positionReference {
                case .fromSafeArea:
                    return safeAreaInsets.top + tipInset
                case .fromSuperview:
                    return tipInset
                }
            }
        case .hidden:
            switch layout.interactiveEdge {
            case .top:
                return bounds.height - hiddenInset
            case .bottom:
                return hiddenInset
            }

        }
    }

    var intrinsicHeight: CGFloat = 0.0

    init(surfaceView: FloatingPanelSurfaceView, backdropView: FloatingPanelBackdropView, layout: FloatingPanelLayout) {
        self.layout = layout
        self.surfaceView = surfaceView
        self.backdropView = backdropView
    }

    func updateIntrinsicHeight() {
        #if swift(>=4.2)
        let fittingSize = UIView.layoutFittingCompressedSize
        #else
        let fittingSize = UILayoutFittingCompressedSize
        #endif
        var intrinsicHeight = surfaceView.contentView?.systemLayoutSizeFitting(fittingSize).height ?? 0.0
        var safeAreaBottom: CGFloat = 0.0
        if #available(iOS 11.0, *) {
            safeAreaBottom = surfaceView.contentView?.safeAreaInsets.bottom ?? 0.0
            if safeAreaBottom > 0 {
                intrinsicHeight -= safeAreaInsets.bottom
            }
        }
        self.intrinsicHeight = max(intrinsicHeight, 0.0)

        log.debug("Update intrinsic height =", intrinsicHeight,
                  ", surface(height) =", surfaceView.frame.height,
                  ", content(height) =", surfaceView.contentView?.frame.height ?? 0.0,
                  ", content safe area(bottom) =", safeAreaBottom)
    }

    // TODO: Support interactive bottom edge
    func prepareLayout(in vc: FloatingPanelController) {
        self.vc = vc

        NSLayoutConstraint.deactivate(fixedConstraints + fullConstraints + halfConstraints + tipConstraints + offConstraints)
        NSLayoutConstraint.deactivate(constraint: self.heightConstraint)
        self.heightConstraint = nil
        NSLayoutConstraint.deactivate(constraint: self.fitToBoundsConstraint)
        self.fitToBoundsConstraint = nil

        surfaceView.translatesAutoresizingMaskIntoConstraints = false
        backdropView.translatesAutoresizingMaskIntoConstraints = false

        // Fixed constraints of surface and backdrop views
        let surfaceConstraints = layout.prepareLayout(surfaceView: surfaceView, in: vc.view!)
        let backdropConstraints = [
            backdropView.topAnchor.constraint(equalTo: vc.view.topAnchor, constant: 0.0),
            backdropView.leftAnchor.constraint(equalTo: vc.view.leftAnchor,constant: 0.0),
            backdropView.rightAnchor.constraint(equalTo: vc.view.rightAnchor, constant: 0.0),
            backdropView.bottomAnchor.constraint(equalTo: vc.view.bottomAnchor, constant: 0.0),
            ]

        fixedConstraints = surfaceConstraints + backdropConstraints

        let topAnchor: NSLayoutYAxisAnchor = {
            if layout.positionReference == .fromSuperview {
                return vc.view.topAnchor
            } else {
                return vc.layoutGuide.topAnchor
            }
        }()
        let bottomAnchor: NSLayoutYAxisAnchor = {
            if layout.positionReference == .fromSuperview {
                return vc.view.bottomAnchor
            } else {
                return vc.layoutGuide.bottomAnchor
            }
        }()

        switch layout.interactiveEdge {
        case .top:
            if vc.contentMode == .fitToBounds {
                fitToBoundsConstraint = surfaceView.bottomAnchor.constraint(equalTo: vc.view.bottomAnchor,
                                                                            constant: 0.0)
            }

            switch layout {
            case is FloatingPanelIntrinsicLayout:
                // Set up on updateHeight()
                break
            default:
                fullConstraints = [
                    surfaceView.topAnchor.constraint(equalTo: topAnchor,
                                                     constant: fullInset),
                ]
            }

            halfConstraints = [
                surfaceView.topAnchor.constraint(equalTo: bottomAnchor,
                                                 constant: -halfInset),
            ]
            tipConstraints = [
                surfaceView.topAnchor.constraint(equalTo: bottomAnchor,
                                                 constant: -tipInset),
            ]

            offConstraints = [
                surfaceView.topAnchor.constraint(equalTo: vc.view.bottomAnchor,
                                                 constant: -hiddenInset),
            ]
        case .bottom:
            if vc.contentMode == .fitToBounds {
                fitToBoundsConstraint = surfaceView.topAnchor.constraint(equalTo: vc.view.topAnchor,
                                                                         constant: 0.0)
            }

            switch layout {
            case is FloatingPanelIntrinsicLayout:
                // Set up on updateHeight()
                break
            default:
                fullConstraints = [
                    surfaceView.bottomAnchor.constraint(equalTo: bottomAnchor,
                                                     constant: -fullInset),
                ]
            }

            halfConstraints = [
                surfaceView.bottomAnchor.constraint(equalTo: topAnchor,
                                                 constant: halfInset),
            ]
            tipConstraints = [
                surfaceView.bottomAnchor.constraint(equalTo: topAnchor,
                                                 constant: tipInset),
            ]

            offConstraints = [
                surfaceView.bottomAnchor.constraint(equalTo: vc.view.topAnchor,
                                                 constant: hiddenInset),
            ]
        }
    }

    // TODO: Support interactive bottom edge
    func startInteraction(at state: FloatingPanelPosition, offset: CGPoint = .zero) {
        guard self.interactiveEdgeConstraint == nil else { return }
        NSLayoutConstraint.deactivate(fullConstraints + halfConstraints + tipConstraints + offConstraints)

        let edgeConst: NSLayoutConstraint
        switch layout.interactiveEdge {
        case .top:
            switch layout.positionReference {
            case .fromSafeArea:
                initialConst = surfaceView.frame.minY - safeAreaInsets.top + offset.y
                edgeConst = surfaceView.topAnchor.constraint(equalTo: vc.layoutGuide.topAnchor,
                                                             constant: initialConst)
            case .fromSuperview:
                initialConst = surfaceView.frame.minY + offset.y
                edgeConst = surfaceView.topAnchor.constraint(equalTo: vc.view.topAnchor,
                                                             constant: initialConst)
            }
        case .bottom:
            switch layout.positionReference {
            case .fromSafeArea:
                initialConst = surfaceView.frame.maxY - safeAreaInsets.top + offset.y
                edgeConst = surfaceView.bottomAnchor.constraint(equalTo: vc.layoutGuide.topAnchor,
                                                                constant: initialConst)
            case .fromSuperview:
                initialConst = surfaceView.frame.maxY + offset.y
                edgeConst = surfaceView.bottomAnchor.constraint(equalTo: vc.view.topAnchor,
                                                                constant: initialConst)
            }
        }

        NSLayoutConstraint.activate([edgeConst])
        self.interactiveEdgeConstraint = edgeConst
    }

    func endInteraction(at state: FloatingPanelPosition) {
        // Don't deactivate `interactiveTopConstraint` here because it leads to
        // unsatisfiable constraints

        if self.interactiveEdgeConstraint == nil {
            // Actiavate `interactiveTopConstraint` for `fitToBounds` mode.
            // It goes throught this path when the pan gesture state jumps
            // from .begin to .end.
            startInteraction(at: state)
        }
    }

    // The method is separated from prepareLayout(to:) for the rotation support
    // It must be called in FloatingPanelController.traitCollectionDidChange(_:)
    func updateHeight() {
        guard let vc = vc else { return }
        NSLayoutConstraint.deactivate(constraint: heightConstraint)
        heightConstraint = nil

        if layout is FloatingPanelIntrinsicLayout {
            updateIntrinsicHeight()
        }
        defer {
            if layout is FloatingPanelIntrinsicLayout {
                NSLayoutConstraint.deactivate(fullConstraints)
                fullConstraints = [
                    surfaceView.topAnchor.constraint(equalTo: vc.layoutGuide.bottomAnchor,
                                                     constant: -fullInset),
                ]
            }
        }

        guard vc.contentMode != .fitToBounds else { return }

        switch layout.interactiveEdge {
        case .top:
            switch layout {
            case is FloatingPanelIntrinsicLayout:
                heightConstraint = surfaceView.heightAnchor.constraint(equalToConstant: intrinsicHeight + safeAreaInsets.bottom)
            default:
                let const = -(positionY(for: topMostState))
                heightConstraint =  surfaceView.heightAnchor.constraint(equalTo: vc.view.heightAnchor,
                                                                        constant: const)
            }
        case .bottom:
            switch layout {
            case is FloatingPanelIntrinsicLayout:
                heightConstraint = surfaceView.heightAnchor.constraint(equalToConstant: intrinsicHeight + safeAreaInsets.bottom)
            default:
                heightConstraint = surfaceView.heightAnchor.constraint(equalTo: vc.view.heightAnchor,
                                                                       constant: -(safeAreaInsets.bottom + fullInset))
            }
        }
        NSLayoutConstraint.activate(constraint: heightConstraint)

        surfaceView.bottomOverflow = vc.view.bounds.height
    }

    // TODO: Support interactive bottom edge
    func updateInteractiveEdgeConstraint(diff: CGFloat, allowsTopBuffer: Bool, with behavior: FloatingPanelBehavior) {
        defer {
            layoutSurfaceIfNeeded() // MUST be called to update `surfaceView.frame`
        }

        let topMostConst: CGFloat = {
            var ret: CGFloat = 0.0
            switch layout.positionReference {
            case .fromSafeArea:
                ret = topY - safeAreaInsets.top
            case .fromSuperview:
                ret = topY
            }
            return max(ret, 0.0) // The top boundary is equal to the related topAnchor.
        }()
        let bottomMostConst: CGFloat = {
            var ret: CGFloat = 0.0
            let _bottomY = vc.isRemovalInteractionEnabled ? positionY(for: .hidden) : bottomY
            switch layout.positionReference {
            case .fromSafeArea:
                ret = _bottomY - safeAreaInsets.top
            case .fromSuperview:
                ret = _bottomY
            }
            return min(ret, surfaceView.superview!.bounds.height)
        }()
        let minConst = allowsTopBuffer ? topMostConst - layout.topInteractionBuffer : topMostConst
        let maxConst = bottomMostConst + layout.bottomInteractionBuffer

        var const = initialConst + diff

        // Rubberbanding top buffer
        if behavior.allowsRubberBanding(for: .top), const < topMostConst {
            let buffer = topMostConst - const
            const = topMostConst - rubberbandEffect(for: buffer, base: vc.view.bounds.height)
        }

        // Rubberbanding bottom buffer
        if behavior.allowsRubberBanding(for: .bottom), const > bottomMostConst {
            let buffer = const - bottomMostConst
            const = bottomMostConst + rubberbandEffect(for: buffer, base: vc.view.bounds.height)
        }

        interactiveEdgeConstraint?.constant = max(minConst, min(maxConst, const))
    }

    // According to @chpwn's tweet: https://twitter.com/chpwn/status/285540192096497664
    // x = distance from the edge
    // c = constant value, UIScrollView uses 0.55
    // d = dimension, either width or height
    private func rubberbandEffect(for buffer: CGFloat, base: CGFloat) -> CGFloat {
        return (1.0 - (1.0 / ((buffer * 0.55 / base) + 1.0))) * base
    }

    func activateFixedLayout() {
        // Must deactivate `interactiveTopConstraint` here
        NSLayoutConstraint.deactivate(constraint: self.interactiveEdgeConstraint)
        self.interactiveEdgeConstraint = nil

        NSLayoutConstraint.activate(fixedConstraints)

        if vc.contentMode == .fitToBounds {
            NSLayoutConstraint.activate(constraint: self.fitToBoundsConstraint)
        }
    }

    func activateInteractiveLayout(of state: FloatingPanelPosition) {
        defer {
            layoutSurfaceIfNeeded()
            log.debug("activateLayout -- surface.presentation = \(self.surfaceView.presentationFrame) surface.frame = \(self.surfaceView.frame)")
        }

        var state = state

        setBackdropAlpha(of: state)

        if isValid(state) == false {
            state = layout.initialPosition
        }

        NSLayoutConstraint.deactivate(fullConstraints + halfConstraints + tipConstraints + offConstraints)
        switch state {
        case .full:
            NSLayoutConstraint.activate(fullConstraints)
        case .half:
            NSLayoutConstraint.activate(halfConstraints)
        case .tip:
            NSLayoutConstraint.activate(tipConstraints)
        case .hidden:
            NSLayoutConstraint.activate(offConstraints)
        }
    }

    func activateLayout(of state: FloatingPanelPosition) {
        activateFixedLayout()
        activateInteractiveLayout(of: state)
    }

    func isValid(_ state: FloatingPanelPosition) -> Bool {
        return supportedPositions.union([.hidden]).contains(state)
    }

    private func layoutSurfaceIfNeeded() {
        #if !TEST
        guard surfaceView.window != nil else { return }
        #endif
        surfaceView.superview?.layoutIfNeeded()
    }

    private func setBackdropAlpha(of target: FloatingPanelPosition) {
        if target == .hidden {
            self.backdropView.alpha = 0.0
        } else {
            self.backdropView.alpha = layout.backdropAlphaFor(position: target)
        }
    }

    private func checkLayoutConsistance() {
        // Verify layout configurations
        assert(supportedPositions.count > 0)
        assert(supportedPositions.contains(layout.initialPosition),
               "Does not include an initial position (\(layout.initialPosition)) in supportedPositions (\(supportedPositions))")

        if layout is FloatingPanelIntrinsicLayout {
            assert(layout.insetFor(position: .full) == nil, "Return `nil` for full position on FloatingPanelIntrinsicLayout")
        }

        if halfInset > 0 {
            assert(halfInset > tipInset, "Invalid half and tip insets")
        }
        // The verification isn't working on orientation change(portrait -> landscape)
        // of a floating panel in tab bar. Because the `safeAreaInsets.bottom` is
        // updated in delay so that it can be 83.0(not 53.0) even after the surface
        // and the super view's frame is fit to landscape already.
        /*if fullInset > 0 {
            assert(middleY > topY, "Invalid insets { topY: \(topY), middleY: \(middleY) }")
            assert(bottomY > topY, "Invalid insets { topY: \(topY), bottomY: \(bottomY) }")
         }*/
    }

    // TODO: Support interactive bottom edge
    func segument(at posY: CGFloat, forward: Bool) -> LayoutSegment {
        /// ----------------------->Y
        /// --> forward                <-- backward
        /// |-------|===o===|-------|  |-------|-------|===o===|
        /// |-------|-------x=======|  |-------|=======x-------|
        /// |-------|-------|===o===|  |-------|===o===|-------|
        /// pos: o/x, seguement: =
        let sortedPositions = supportedPositions.sorted(by: { $0.rawValue < $1.rawValue })

        let upperIndex: Int?
        if forward {
            #if swift(>=4.2)
            upperIndex = sortedPositions.firstIndex(where: { posY < positionY(for: $0) })
            #else
            upperIndex = sortedPositions.index(where: { posY < positionY(for: $0) })
            #endif
        } else {
            #if swift(>=4.2)
            upperIndex = sortedPositions.firstIndex(where: { posY <= positionY(for: $0) })
            #else
            upperIndex = sortedPositions.index(where: { posY <= positionY(for: $0) })
            #endif
        }

        switch upperIndex {
        case 0:
            return LayoutSegment(lower: nil, upper: sortedPositions.first)
        case let upperIndex?:
            return LayoutSegment(lower: sortedPositions[upperIndex - 1], upper: sortedPositions[upperIndex])
        default:
            return LayoutSegment(lower: sortedPositions[sortedPositions.endIndex - 1], upper: nil)
        }
    }
}
