import Combine
import RealityKit
import SwiftUI
import UIKit

/// Runs the 3D world: RealityKit in non-AR mode (works on iOS 13+, so no iOS 18 gate is
/// needed), a per-frame game loop, player movement with collisions and jumping, a
/// third-person or first-person camera, NPCs, billboards and the Community Park.
@MainActor
final class ExplorerScene {
    let arView: ARView
    private let world = AnchorEntity(world: .zero)
    private let camera = PerspectiveCamera()
    private let player: AvatarEntity
    private var npcs: [(npc: ExplorerNPC, avatar: AvatarEntity, tag: ModelEntity)] = []
    private var billboards: [(slot: BillboardSlot, entity: ModelEntity)] = []
    private var parkEntity = Entity()
    private var parkStage: ParkStage?
    private var colliders: [Collider] = []
    private var baseColliders: [Collider] = []
    private var updates: Cancellable?

    private weak var viewModel: ExplorerViewModel?
    private weak var model: AppModel?
    private let reduceMotion: Bool

    // Player state
    private var position = SIMD3<Float>(0, 0, 2)
    private var velocityY: Float = 0
    private var facing: Float = 0
    private var cameraYaw: Float = 0
    private var cameraPitch: Float = 0.32
    private var lookVersion = -1
    private var worldVersion = -1
    private var time: Float = 0
    private var tourIndex = 0
    private var tourStuck: Float = 0
    private let tour: [SIMD2<Float>]?

    static let walkSpeed: Float = 5
    static let radius: Float = 0.35
    static let interactRange: Float = 2.8

    init(viewModel: ExplorerViewModel, model: AppModel, reduceMotion: Bool) {
        self.viewModel = viewModel
        self.model = model
        self.reduceMotion = reduceMotion
        arView = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        arView.environment.background = .color(UIColor(hex: 0xA8D4F5))
        arView.renderOptions = [.disableMotionBlur, .disableDepthOfField, .disableHDR, .disableGroundingShadows]
        player = AvatarEntity(look: viewModel.currentLook, cosmetic: viewModel.cosmetic)
        #if DEBUG
        tour = ProcessInfo.processInfo.arguments.contains("-NovaExplorerTour")
            ? [SIMD2(0, 2), SIMD2(0, 12), SIMD2(0, 22), SIMD2(0, 32), SIMD2(10, 34), SIMD2(20, 23), SIMD2(28, 24), SIMD2(28, 36),
               SIMD2(28, 43), SIMD2(10, 52), SIMD2(-12, 40), SIMD2(-20, 36), SIMD2(-28, 36), SIMD2(-26, 52), SIMD2(-8, 58),
               SIMD2(0, 60), SIMD2(0, 69)]
            : nil
        #else
        tour = nil
        #endif
        if let start = ProcessInfo.processInfo.arguments.firstIndex(of: "-NovaExplorerSpot").flatMap({ i -> ExplorerZone? in
            let args = ProcessInfo.processInfo.arguments
            return i + 1 < args.count ? ExplorerZone(rawValue: args[i + 1]) : nil
        }) {
            position = SIMD3(start.spawn.x, 0, start.spawn.y)
        }
        setUpWorld()
        updates = arView.scene.subscribe(to: SceneEvents.Update.self) { [weak self] event in
            MainActor.assumeIsolated { self?.tick(Float(min(event.deltaTime, 1.0 / 20))) }
        }
    }

    func stop() {
        updates?.cancel()
        updates = nil
    }

    // MARK: Setup

    private func setUpWorld() {
        arView.scene.addAnchor(world)

        let sun = DirectionalLight()
        sun.light.intensity = 2_400
        sun.orientation = simd_quatf(angle: -.pi / 3, axis: [1, 0.35, 0])
        world.addChild(sun)
        let fill = DirectionalLight()
        fill.light.intensity = 900
        fill.orientation = simd_quatf(angle: .pi * 0.8, axis: [0.3, 1, 0.2])
        world.addChild(fill)

        let built = ManchesterWorld.build()
        world.addChild(built.root)
        baseColliders = built.colliders
        colliders = baseColliders

        for slot in built.billboards {
            let entity = ModelEntity(mesh: .generatePlane(width: slot.size.x, height: slot.size.y), materials: [UnlitMaterial(color: .white)])
            entity.position = slot.position
            entity.orientation = simd_quatf(angle: slot.yaw, axis: [0, 1, 0])
            // Planes are one-sided, so add a back face that reads correctly from behind.
            let back = ModelEntity(mesh: .generatePlane(width: slot.size.x, height: slot.size.y), materials: [UnlitMaterial(color: .white)])
            back.orientation = simd_quatf(angle: .pi, axis: [0, 1, 0])
            back.position.z = -0.02
            entity.addChild(back)
            world.addChild(entity)
            billboards.append((slot, entity))
        }

        for npc in ExplorerWorld.npcs {
            let avatar = AvatarEntity(look: npc.look, cosmetic: npc.activity == .stylist ? "scarf" : nil)
            avatar.root.position = [npc.position.x, 0, npc.position.y]
            avatar.root.orientation = simd_quatf(angle: .pi, axis: [0, 1, 0])
            world.addChild(avatar.root)
            let tag = ModelEntity(mesh: .generatePlane(width: 1.8, height: 0.5),
                                  materials: [ViewTexture.material(NameTag(name: npc.name, role: npc.role, isStylist: npc.activity == .stylist))])
            tag.position = [npc.position.x, 2.75, npc.position.y]
            world.addChild(tag)
            npcs.append((npc, avatar, tag))
        }

        world.addChild(player.root)
        world.addChild(parkEntity)
        camera.camera.fieldOfViewInDegrees = 62
        world.addChild(camera)
    }

    // MARK: Game loop

    private func tick(_ dt: Float) {
        guard let viewModel, let model else { return }
        time += dt

        if viewModel.lookVersion != lookVersion {
            lookVersion = viewModel.lookVersion
            player.update(look: viewModel.stylistOpen ? viewModel.previewLook : viewModel.currentLook, cosmetic: viewModel.cosmetic)
        }
        if viewModel.worldVersion != worldVersion {
            worldVersion = viewModel.worldVersion
            refreshWorld(model: model, viewModel: viewModel)
        }
        if let target = viewModel.teleport {
            position = SIMD3(target.x, 0, target.y)
            viewModel.teleport = nil
        }
        if let emote = viewModel.emoteRequest {
            player.play(emote)
            viewModel.emoteRequest = nil
        }

        // Camera drag (right side of the screen)
        let drag = viewModel.cameraDrag
        if drag != .zero {
            cameraYaw -= drag.x * 0.008
            cameraPitch = min(1.1, max(-0.2, cameraPitch + drag.y * 0.005))
            viewModel.cameraDrag = .zero
        }

        // Movement, relative to where the camera faces. Frozen while Remi is styling you.
        var input = viewModel.stylistOpen || viewModel.panel != nil ? SIMD2<Float>.zero : viewModel.joystick
        if let tour, viewModel.isLoaded, !viewModel.stylistOpen {
            let target = tour[min(tourIndex, tour.count - 1)]
            let delta = target - SIMD2(position.x, position.z)
            if simd_length(delta) < 0.6 || tourStuck > 1.5 {
                if tourIndex < tour.count - 1 { tourIndex += 1 }
                tourStuck = 0
            } else {
                let dir = simd_normalize(delta)
                // Convert the world direction into joystick space for the current camera.
                let forward = SIMD2(-sin(cameraYaw), -cos(cameraYaw)), right = SIMD2(cos(cameraYaw), -sin(cameraYaw))
                input = SIMD2(simd_dot(dir, right), simd_dot(dir, forward))
                cameraYaw += (atan2(-dir.x, -dir.y) - cameraYaw).remainder(dividingBy: 2 * .pi) * min(1, dt * 1.5)
            }
        }
        let forward = SIMD3<Float>(-sin(cameraYaw), 0, -cos(cameraYaw))
        let right = SIMD3<Float>(cos(cameraYaw), 0, -sin(cameraYaw))
        let move = forward * input.y + right * input.x
        let speed = min(1, simd_length(input))
        if speed > 0.05 {
            let step = simd_normalize(move) * Self.walkSpeed * speed * dt
            let next = resolve(SIMD2(position.x + step.x, position.z + step.z), y: position.y)
            tourStuck = simd_distance(next, SIMD2(position.x, position.z)) < Self.walkSpeed * speed * dt * 0.3 ? tourStuck + dt : 0
            position.x = next.x
            position.z = next.y
            facing = atan2(-move.x, -move.z)
        }
        if viewModel.jumpRequested {
            if position.y <= 0.001 { velocityY = 5.5 }
            viewModel.jumpRequested = false
        }
        velocityY -= 14 * dt
        position.y = max(0, position.y + velocityY * dt)
        if position.y == 0 { velocityY = 0 }

        player.root.position = position
        player.root.orientation = simd_quatf(angle: facing, axis: [0, 1, 0])
        player.animate(dt: dt, speed: speed, reduceMotion: reduceMotion)
        player.root.isEnabled = viewModel.thirdPerson

        updateCamera(thirdPerson: viewModel.thirdPerson, styling: viewModel.stylistOpen)
        updateNPCs(dt: dt)

        // Who's nearby?
        let here = SIMD2(position.x, position.z)
        let npc = npcs.map(\.npc).filter { simd_distance($0.position, here) < Self.interactRange }
            .min { simd_distance($0.position, here) < simd_distance($1.position, here) }
        let board = billboards.first { simd_distance(SIMD2($0.slot.position.x, $0.slot.position.z), here) < 4.5 }?.slot.kind
        viewModel.sceneUpdated(zone: ExplorerZone.at(here), npc: npc, billboard: board)
    }

    private func updateCamera(thirdPerson: Bool, styling: Bool) {
        let head = position + SIMD3(0, 1.65, 0)
        let forward = SIMD3<Float>(-sin(cameraYaw), 0, -cos(cameraYaw))
        if styling {
            // Face the player for the stylist, framed above Remi's panel.
            player.root.isEnabled = true
            let front = SIMD3<Float>(-sin(facing), 0, -cos(facing))
            camera.look(at: position + SIMD3(0, 0.55, 0), from: position + front * 4.6 + SIMD3(0, 1.7, 0), relativeTo: nil)
            return
        }
        if thirdPerson {
            let distance: Float = 6.5
            let back = SIMD3<Float>(sin(cameraYaw) * cos(cameraPitch), sin(cameraPitch), cos(cameraYaw) * cos(cameraPitch)) * distance
            var eye = head + back
            eye.y = max(0.6, min(eye.y, 10))
            camera.look(at: head, from: eye, relativeTo: nil)
        } else {
            let target = head + forward * 5 + SIMD3(0, -sin(cameraPitch - 0.3) * 4, 0)
            camera.look(at: target, from: head + forward * 0.25, relativeTo: nil)
        }
    }

    private func updateNPCs(dt: Float) {
        let eye = camera.position(relativeTo: nil)
        let here = SIMD2(position.x, position.z)
        for (npc, avatar, tag) in npcs {
            // Face the player when they're close, otherwise idle.
            let toPlayer = here - npc.position
            if simd_length(toPlayer) < 6 {
                avatar.root.orientation = simd_quatf(angle: atan2(-toPlayer.x, -toPlayer.y), axis: [0, 1, 0])
            }
            avatar.root.position.y = reduceMotion ? 0 : max(0, sin(time * 2 + npc.position.x) * 0.03)
            // Name tags turn to face the camera.
            let dx = eye.x - tag.position.x, dz = eye.z - tag.position.z
            tag.orientation = simd_quatf(angle: atan2(dx, dz), axis: [0, 1, 0])
        }
    }

    /// Slides the player along walls: pushes the circle out of any overlapping box.
    private func resolve(_ p: SIMD2<Float>, y: Float) -> SIMD2<Float> {
        var p = p
        let r = Self.radius
        let b = ManchesterWorld.bounds
        p.x = min(b.maxX - r, max(b.minX + r, p.x))
        p.y = min(b.maxZ - r, max(b.minZ + r, p.y))
        for c in colliders {
            let cx = min(max(p.x, c.minX), c.maxX), cz = min(max(p.y, c.minZ), c.maxZ)
            let d = SIMD2(p.x - cx, p.y - cz)
            let dist = simd_length(d)
            if dist < r {
                if dist > 0.0001 {
                    p += d / dist * (r - dist)
                } else {
                    // Centre is inside the box: push out on the shortest side.
                    let pushes: [(Float, SIMD2<Float>)] = [(p.x - c.minX + r, SIMD2(-1, 0)), (c.maxX - p.x + r, SIMD2(1, 0)),
                                                           (p.y - c.minZ + r, SIMD2(0, -1)), (c.maxZ - p.y + r, SIMD2(0, 1))]
                    if let best = pushes.min(by: { $0.0 < $1.0 }) { p += best.1 * best.0 }
                }
            }
        }
        return p
    }

    // MARK: Billboards and park

    private func refreshWorld(model: AppModel, viewModel: ExplorerViewModel) {
        let stage = model.park?.stage ?? .emptyLot
        if stage != parkStage {
            parkStage = stage
            parkEntity.removeFromParent()
            parkEntity = ManchesterWorld.parkEntity(stage: stage)
            world.addChild(parkEntity)
            colliders = baseColliders + ManchesterWorld.parkColliders(stage: stage)
        }
        for (slot, entity) in billboards {
            let content = BillboardContent(kind: slot.kind, model: model, nextQuest: viewModel.nextQuest(model: model))
            let material = ViewTexture.material(BillboardView(content: content).frame(width: CGFloat(slot.size.x) * 80, height: CGFloat(slot.size.y) * 80))
            entity.model?.materials = [material]
            (entity.children.first as? ModelEntity)?.model?.materials = [material]
        }
    }
}

/// The 3D view in SwiftUI.
struct ExplorerSceneView: UIViewRepresentable {
    let viewModel: ExplorerViewModel
    let model: AppModel
    let reduceMotion: Bool

    final class Coordinator { var scene: ExplorerScene? }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> ARView {
        let scene = ExplorerScene(viewModel: viewModel, model: model, reduceMotion: reduceMotion)
        context.coordinator.scene = scene
        scene.arView.accessibilityLabel = "Nova Explorer 3D view of Manchester"
        return scene.arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        coordinator.scene?.stop()
        coordinator.scene = nil
    }
}

/// Floating name above an NPC (rendered to a texture).
private struct NameTag: View {
    let name: String
    let role: String
    let isStylist: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: isStylist ? "sparkles" : "bubble.left.fill")
                Text(name).font(.system(size: 16, weight: .bold))
            }
            Text(role).font(.system(size: 11, weight: .medium)).opacity(0.85)
        }
        .foregroundStyle(.white)
        .frame(width: 180, height: 50)
        .background(Color(red: 0.37, green: 0.06, blue: 0.69).opacity(0.92), in: RoundedRectangle(cornerRadius: 12))
    }
}
