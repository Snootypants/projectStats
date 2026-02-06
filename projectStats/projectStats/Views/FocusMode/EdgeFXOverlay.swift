// EdgeFXOverlay.swift
import Cocoa
import QuartzCore

final class EdgeFXOverlay: NSView {

    enum Mode {
        case fire
        case smoke
        case cubes
    }

    private let root = CALayer()
    private let topEmitter = CAEmitterLayer()
    private let bottomEmitter = CAEmitterLayer()
    private let leftEmitter = CAEmitterLayer()
    private let rightEmitter = CAEmitterLayer()
    private var cubeLayers: [CALayer] = []
    private var cubeTimer: Timer?
    private var currentMode: Mode = .fire
    private(set) var intensity: CGFloat = 1.0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true
        layer = root
        root.masksToBounds = false
        root.backgroundColor = NSColor.clear.cgColor
        root.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0

        [topEmitter, bottomEmitter, leftEmitter, rightEmitter].forEach {
            setupEmitter($0)
            root.addSublayer($0)
        }

        translatesAutoresizingMaskIntoConstraints = false
    }

    override var isOpaque: Bool { false }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        root.frame = bounds
        layoutEmitters()
        CATransaction.commit()
    }

    private func setupEmitter(_ e: CAEmitterLayer) {
        e.emitterMode = .outline
        e.renderMode = .additive
        e.masksToBounds = false
        e.birthRate = 0
    }

    private func layoutEmitters() {
        let b = bounds
        topEmitter.emitterShape = .line
        topEmitter.emitterPosition = CGPoint(x: b.midX, y: b.maxY)
        topEmitter.emitterSize = CGSize(width: b.width, height: 1)

        bottomEmitter.emitterShape = .line
        bottomEmitter.emitterPosition = CGPoint(x: b.midX, y: b.minY)
        bottomEmitter.emitterSize = CGSize(width: b.width, height: 1)

        leftEmitter.emitterShape = .line
        leftEmitter.emitterPosition = CGPoint(x: b.minX, y: b.midY)
        leftEmitter.emitterSize = CGSize(width: 1, height: b.height)

        rightEmitter.emitterShape = .line
        rightEmitter.emitterPosition = CGPoint(x: b.maxX, y: b.midY)
        rightEmitter.emitterSize = CGSize(width: 1, height: b.height)
    }

    func set(mode: Mode, intensity: CGFloat = 1.0) {
        self.currentMode = mode
        self.intensity = max(0.0, min(intensity, 5.0))
        stopAll()
        switch mode {
        case .fire: startFire()
        case .smoke: startSmoke()
        case .cubes: startCubes()
        }
    }

    func stopAll() {
        [topEmitter, bottomEmitter, leftEmitter, rightEmitter].forEach {
            $0.birthRate = 0
            $0.emitterCells = nil
        }
        cubeTimer?.invalidate()
        cubeTimer = nil
        cubeLayers.forEach { $0.removeFromSuperlayer() }
        cubeLayers.removeAll()
    }

    // MARK: - Fire

    private func startFire() {
        let sparkImg = SpriteFactory.circleSprite(diameter: 18, softEdge: true, alpha: 1.0)
        let emberImg = SpriteFactory.circleSprite(diameter: 10, softEdge: true, alpha: 1.0)

        let sparks = CAEmitterCell()
        sparks.contents = sparkImg
        sparks.birthRate = Float(30.0 * intensity)
        sparks.lifetime = 0.6
        sparks.lifetimeRange = 0.35
        sparks.velocity = 160.0 * intensity
        sparks.velocityRange = CGFloat(60)
        sparks.emissionRange = .pi * 2
        sparks.scale = 0.05
        sparks.scaleRange = 0.08
        sparks.alphaSpeed = -2.8
        sparks.yAcceleration = 40.0 * intensity
        sparks.color = NSColor(calibratedRed: 1.0, green: 0.85, blue: 0.35, alpha: 1.0).cgColor

        let embers = CAEmitterCell()
        embers.contents = emberImg
        embers.birthRate = Float(80.0 * intensity)
        embers.lifetime = 1.2
        embers.lifetimeRange = 0.5
        embers.velocity = 90.0 * intensity
        embers.velocityRange = 25
        embers.emissionRange = .pi * 2
        embers.scale = 0.06
        embers.scaleRange = 0.10
        embers.alphaSpeed = -1.6
        embers.yAcceleration = 25.0 * intensity
        embers.spin = 2.5
        embers.spinRange = 6
        embers.color = NSColor(calibratedRed: 1.0, green: 0.45, blue: 0.12, alpha: 1.0).cgColor

        configureEdgeEmitters(
            cells: [embers, sparks],
            topVector: CGVector(dx: 0, dy: -1),
            bottomVector: CGVector(dx: 0, dy: 1),
            leftVector: CGVector(dx: 1, dy: 0),
            rightVector: CGVector(dx: -1, dy: 0),
            baseSpeed: 1.0
        )
        startEmitterPulse()
    }

    // MARK: - Smoke

    private func startSmoke() {
        let smokeImg = SpriteFactory.circleSprite(diameter: 48, softEdge: true, alpha: 0.75)

        let smoke = CAEmitterCell()
        smoke.contents = smokeImg
        smoke.birthRate = Float(18.0 * intensity)
        smoke.lifetime = 2.8
        smoke.lifetimeRange = 1.0
        smoke.velocity = 40.0 * intensity
        smoke.velocityRange = 15
        smoke.emissionRange = .pi * 2
        smoke.scale = 0.12
        smoke.scaleRange = 0.18
        smoke.alphaSpeed = -0.35
        smoke.spin = 0.6
        smoke.spinRange = 1.4
        smoke.yAcceleration = 8.0 * intensity
        smoke.color = NSColor(calibratedWhite: 0.9, alpha: 0.75).cgColor

        configureEdgeEmitters(
            cells: [smoke],
            topVector: CGVector(dx: 0, dy: -1),
            bottomVector: CGVector(dx: 0, dy: 1),
            leftVector: CGVector(dx: 1, dy: 0),
            rightVector: CGVector(dx: -1, dy: 0),
            baseSpeed: 0.7
        )
        startEmitterPulse()
    }

    // MARK: - Cubes

    private func startCubes() {
        let b = bounds
        guard b.width > 40, b.height > 40 else { return }

        let cubeCount = Int(140 * intensity)
        let sprite = SpriteFactory.squareSprite(size: 14, alpha: 1.0)

        for i in 0..<cubeCount {
            let cube = CALayer()
            cube.contents = sprite
            cube.contentsScale = root.contentsScale
            cube.bounds = CGRect(x: 0, y: 0, width: 10, height: 10)
            cube.opacity = Float.random(in: 0.25...0.85)
            cube.position = perimeterPoint(index: i, total: cubeCount, in: b, inset: 8)
            root.addSublayer(cube)
            cubeLayers.append(cube)
            applyCubeJiggle(cube)
        }

        cubeTimer = Timer.scheduledTimer(withTimeInterval: 0.9, repeats: true) { [weak self] _ in
            guard let self else { return }
            for cube in self.cubeLayers.shuffled().prefix(max(8, Int(18 * self.intensity))) {
                self.applyCubeJiggle(cube, burst: true)
            }
        }
    }

    // MARK: - Helpers

    private func configureEdgeEmitters(cells: [CAEmitterCell], topVector: CGVector, bottomVector: CGVector, leftVector: CGVector, rightVector: CGVector, baseSpeed: CGFloat) {
        func cellsWithDirection(_ v: CGVector) -> [CAEmitterCell] {
            cells.map { src in
                let c = src.copy() as! CAEmitterCell
                c.emissionLongitude = atan2(v.dy, v.dx)
                c.emissionRange = .pi / 2
                c.velocity = c.velocity * baseSpeed
                return c
            }
        }
        topEmitter.emitterCells = cellsWithDirection(topVector)
        bottomEmitter.emitterCells = cellsWithDirection(bottomVector)
        leftEmitter.emitterCells = cellsWithDirection(leftVector)
        rightEmitter.emitterCells = cellsWithDirection(rightVector)
        [topEmitter, bottomEmitter, leftEmitter, rightEmitter].forEach { $0.birthRate = 1 }
    }

    private func startEmitterPulse() {
        let pulse = CABasicAnimation(keyPath: "birthRate")
        pulse.fromValue = 0.8
        pulse.toValue = 1.15
        pulse.duration = 0.45
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        [topEmitter, bottomEmitter, leftEmitter, rightEmitter].forEach {
            $0.removeAnimation(forKey: "pulse")
            $0.add(pulse, forKey: "pulse")
        }
    }

    private func perimeterPoint(index: Int, total: Int, in rect: CGRect, inset: CGFloat) -> CGPoint {
        let w = rect.width - inset * 2
        let h = rect.height - inset * 2
        let perimeter = 2 * (w + h)
        guard perimeter > 0 else { return CGPoint(x: rect.midX, y: rect.midY) }
        let t = (CGFloat(index) / CGFloat(max(total, 1))) * perimeter
        let x0 = rect.minX + inset, y0 = rect.minY + inset
        let x1 = rect.maxX - inset, y1 = rect.maxY - inset
        var p: CGPoint
        switch t {
        case 0..<w: p = CGPoint(x: x0 + t, y: y1)
        case w..<(w + h): p = CGPoint(x: x1, y: y1 - (t - w))
        case (w + h)..<(2*w + h): p = CGPoint(x: x1 - (t - (w + h)), y: y0)
        default: p = CGPoint(x: x0, y: y0 + (t - (2*w + h)))
        }
        p.x += .random(in: -15...15)
        p.y += .random(in: -15...15)
        return p
    }

    private func applyCubeJiggle(_ cube: CALayer, burst: Bool = false) {
        let dx = CGFloat.random(in: burst ? -25...25 : -10...10)
        let dy = CGFloat.random(in: burst ? -25...25 : -10...10)

        let pos = CASpringAnimation(keyPath: "position")
        pos.damping = burst ? 7 : 10
        pos.mass = 1; pos.stiffness = burst ? 220 : 120
        pos.initialVelocity = burst ? 2.5 : 1.2
        pos.duration = pos.settlingDuration
        pos.fromValue = cube.position
        pos.toValue = CGPoint(x: cube.position.x + dx, y: cube.position.y + dy)
        cube.position = CGPoint(x: cube.position.x + dx, y: cube.position.y + dy)

        let rot = CASpringAnimation(keyPath: "transform.rotation.z")
        rot.damping = burst ? 8 : 11; rot.mass = 1; rot.stiffness = burst ? 180 : 95
        rot.initialVelocity = burst ? 2 : 1; rot.duration = rot.settlingDuration
        rot.fromValue = 0; rot.toValue = CGFloat.random(in: burst ? -0.9...0.9 : -0.25...0.25)

        let scale = CASpringAnimation(keyPath: "transform.scale")
        scale.damping = burst ? 7 : 10; scale.mass = 1; scale.stiffness = burst ? 220 : 120
        scale.initialVelocity = burst ? 2 : 1; scale.duration = scale.settlingDuration
        scale.fromValue = 1; scale.toValue = CGFloat.random(in: burst ? 0.65...1.35 : 0.85...1.15)

        ["pos", "rot", "scale"].forEach { cube.removeAnimation(forKey: $0) }
        cube.add(pos, forKey: "pos")
        cube.add(rot, forKey: "rot")
        cube.add(scale, forKey: "scale")
    }
}

// MARK: - SpriteFactory

enum SpriteFactory {
    static func circleSprite(diameter: CGFloat, softEdge: Bool, alpha: CGFloat) -> CGImage {
        let size = CGSize(width: diameter, height: diameter)
        let img = NSImage(size: size, flipped: false) { rect in
            NSColor.clear.setFill(); rect.fill()
            let path = NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1))
            if softEdge {
                NSGradient(colors: [
                    NSColor(white: 1.0, alpha: alpha),
                    NSColor(white: 1.0, alpha: 0)
                ])!.draw(in: path, relativeCenterPosition: .zero)
            } else {
                NSColor(white: 1.0, alpha: alpha).setFill(); path.fill()
            }
            return true
        }
        return img.cgImageRepresentation()
    }

    static func squareSprite(size: CGFloat, alpha: CGFloat) -> CGImage {
        let s = CGSize(width: size, height: size)
        let img = NSImage(size: s, flipped: false) { rect in
            NSColor.clear.setFill(); rect.fill()
            let path = NSBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), xRadius: 2, yRadius: 2)
            NSColor(white: 1.0, alpha: alpha).setFill(); path.fill()
            return true
        }
        return img.cgImageRepresentation()
    }
}

private extension NSImage {
    func cgImageRepresentation() -> CGImage {
        var rect = CGRect(origin: .zero, size: size)
        return cgImage(forProposedRect: &rect, context: nil, hints: nil)
            ?? NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width),
                                pixelsHigh: Int(size.height), bitsPerSample: 8,
                                samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
                .cgImage!
    }
}
