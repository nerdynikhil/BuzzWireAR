import SwiftUI
import RealityKit
import ARKit
import Combine
import UIKit

@Observable
class BuzzWireGameState {
    var gameStarted = false
    var gameTime: TimeInterval = 0
    var buzzCount = 0
    var isGameWon = false
    var isGameLost = false
    var ringPosition: SIMD3<Float> = [-0.15, 0.01, 0]
    var ringEntity: Entity?
    var wireEntities: [Entity] = []
    private var gameTimer: Timer?
    private var collisionSubscription: AnyCancellable?
    var collisionSubscriptions: Set<AnyCancellable> = []
    
    func startGame() {
        gameStarted = true
        gameTime = 0
        buzzCount = 0
        isGameWon = false
        isGameLost = false
        ringPosition = [-0.15, 0.01, 0]
        
        gameTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            self.gameTime += 0.1
        }
    }
    
    func buzz() {
        buzzCount += 1
        triggerHapticFeedback()
        
        if buzzCount >= 3 {
            endGame(won: false)
        }
    }
    
    func winGame() {
        endGame(won: true)
    }
    
    private func endGame(won: Bool) {
        isGameWon = won
        isGameLost = !won
        gameStarted = false
        gameTimer?.invalidate()
        gameTimer = nil
        collisionSubscription?.cancel()
        collisionSubscriptions.removeAll()
        
        if won {
            triggerSuccessHapticFeedback()
        }
    }
    
    func setGameCompleteCallback(_ callback: @escaping (Bool) -> Void) {
        // This will be called when game ends to trigger sound
    }
    
    func moveRing(to position: SIMD3<Float>) {
        ringPosition = position
        ringEntity?.position = position
        
        if position.x >= 0.14 && gameStarted {
            winGame()
        }
    }
    
    
    private func triggerHapticFeedback() {
        let impactGenerator = UIImpactFeedbackGenerator(style: .heavy)
        impactGenerator.impactOccurred()
    }
    
    private func triggerSuccessHapticFeedback() {
        let notificationGenerator = UINotificationFeedbackGenerator()
        notificationGenerator.notificationOccurred(.success)
    }
    
    func playBuzzSound() {
        // Will be called from the view
    }
    
    func playSuccessSound() {
        // Will be called from the view
    }
}

struct BuzzWireGameView: View {
    @State private var gameState = BuzzWireGameState()
    @State private var dragOffset: CGSize = .zero
    @StateObject private var soundManager = SoundManager()
    @State private var showInstructions = false
    @State private var planeDetected = false
    
    var body: some View {
        ZStack {
            ARViewContainer(gameState: gameState, soundManager: soundManager, onPlaneDetected: {
                planeDetected = true
            })
            .edgesIgnoringSafeArea(.all)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if gameState.gameStarted {
                            handleDrag(value: value)
                        }
                    }
                    .onEnded { _ in
                        dragOffset = .zero
                    }
            )
            
            if !planeDetected {
                ARCoachingView()
            }
            
            ARInstructionsOverlay(showInstructions: showInstructions)
            ARPlaneVisualization(planeDetected: planeDetected)
            
            VStack {
                HStack {
                    Text("Time: \(String(format: "%.1f", gameState.gameTime))s")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(8)
                    
                    Spacer()
                    
                    Text("Buzzes: \(gameState.buzzCount)/3")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(8)
                }
                .padding()
                
                Spacer()
                
                if !gameState.gameStarted && !gameState.isGameWon && !gameState.isGameLost {
                    VStack(spacing: 16) {
                        Text("🎯 BuzzWire AR")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Guide the ring along the wire without touching it!")
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Start Game") {
                            gameState.startGame()
                            showInstructions = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                showInstructions = false
                            }
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .font(.headline)
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(16)
                }
                
                if gameState.isGameWon {
                    VStack(spacing: 16) {
                        Text("🎉 Victory!")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                        Text("Time: \(String(format: "%.1f", gameState.gameTime))s")
                            .font(.title2)
                            .foregroundColor(.white)
                        Text("Buzzes: \(gameState.buzzCount)")
                            .foregroundColor(.white)
                        Button("Play Again") {
                            gameState.startGame()
                        }
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .font(.headline)
                    }
                    .padding()
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(16)
                }
                
                if gameState.isGameLost {
                    VStack(spacing: 16) {
                        Text("💥 Game Over!")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                        Text("Too many buzzes!")
                            .font(.title2)
                            .foregroundColor(.white)
                        Text("Time: \(String(format: "%.1f", gameState.gameTime))s")
                            .foregroundColor(.white)
                        Button("Try Again") {
                            gameState.startGame()
                        }
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .font(.headline)
                    }
                    .padding()
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(16)
                }
                
                if gameState.gameStarted {
                    Text("Drag to move the ring →")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(8)
                }
            }
        }
        .onChange(of: gameState.isGameWon) { _, isWon in
            if isWon {
                soundManager.playSuccessSound()
            }
        }
    }
    
    private func handleDrag(value: DragGesture.Value) {
        let sensitivity: Float = 0.0003
        let deltaX = Float(value.translation.width) * sensitivity
        let deltaY = -Float(value.translation.height) * sensitivity
        
        var newPosition = gameState.ringPosition
        newPosition.x += deltaX
        newPosition.y += deltaY
        
        newPosition.x = max(-0.16, min(0.16, newPosition.x))
        newPosition.y = max(0.01, min(0.05, newPosition.y))
        
        gameState.moveRing(to: newPosition)
    }
}

struct ARViewContainer: UIViewRepresentable {
    let gameState: BuzzWireGameState
    let soundManager: SoundManager
    let onPlaneDetected: () -> Void
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // Setup AR configuration
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        arView.session.run(config)
        
        // Create anchor that appears immediately in front of camera (no plane detection needed)
        let anchor = AnchorEntity(.camera)
        anchor.position = [0, -0.1, -0.5] // 50cm in front, 10cm below camera
        
        // Add red test cube to verify AR works
        let testCube = Entity()
        testCube.components.set(ModelComponent(
            mesh: MeshResource.generateBox(size: 0.05),
            materials: [SimpleMaterial(color: .red, isMetallic: false)]
        ))
        testCube.position = [0, 0, 0]
        anchor.addChild(testCube)
        
        print("✅ Added test cube")
        
        // Add wire and ring
        let wirePath = createSimpleWire()
        anchor.addChild(wirePath)
        print("✅ Added wire path")
        
        let ring = createSimpleRing()
        ring.position = gameState.ringPosition
        gameState.ringEntity = ring
        anchor.addChild(ring)
        print("✅ Added ring")
        
        // Add anchor to scene
        arView.scene.addAnchor(anchor)
        print("✅ Added anchor to scene")
        
        // Add collision detection back
        arView.scene.subscribe(to: CollisionEvents.Began.self) { event in
            DispatchQueue.main.async {
                gameState.buzz()
                soundManager.playBuzzSound()
                print("🔊 BUZZ! Collision detected")
            }
        }.store(in: &gameState.collisionSubscriptions)
        
        // Notify immediately
        DispatchQueue.main.async {
            onPlaneDetected()
        }
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        gameState.ringEntity?.position = gameState.ringPosition
    }
}

func createSimpleWire() -> Entity {
    let wireContainer = Entity()
    
    // Create twisted wire path that looks more interesting
    let wirePoints: [SIMD3<Float>] = [
        [-0.15, 0.01, 0],
        [-0.08, 0.04, 0.02],
        [0, 0.02, -0.01],
        [0.08, 0.05, 0.01],
        [0.15, 0.01, 0]
    ]
    
    for i in 0..<wirePoints.count {
        let wireSegment = Entity()
        wireSegment.components.set(ModelComponent(
            mesh: MeshResource.generateBox(size: [0.003, 0.003, 0.04]),
            materials: [SimpleMaterial(color: .init(red: 0.8, green: 0.6, blue: 0.2, alpha: 1), roughness: 0.3, isMetallic: true)]
        ))
        wireSegment.position = wirePoints[i]
        
        // Add collision back now that audio is safe
        wireSegment.components.set(CollisionComponent(shapes: [.generateBox(size: [0.01, 0.01, 0.04])]))
        
        wireContainer.addChild(wireSegment)
    }
    
    return wireContainer
}

func createSimpleRing() -> Entity {
    let ring = Entity()
    ring.components.set(ModelComponent(
        mesh: MeshResource.generateBox(size: [0.018, 0.018, 0.003]),  
        materials: [SimpleMaterial(color: .init(red: 0.1, green: 0.5, blue: 0.9, alpha: 1), roughness: 0.2, isMetallic: true)]
    ))
    
    // Add collision back
    ring.components.set(CollisionComponent(shapes: [.generateBox(size: [0.018, 0.018, 0.003])]))
    
    return ring
}

#Preview {
    BuzzWireGameView()
}