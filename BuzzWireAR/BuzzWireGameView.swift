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
    var ringPosition: SIMD3<Float> = [-0.1, 0.02, 0]
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
        ringPosition = [-0.1, 0.02, 0]
        
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
        
        if position.x >= 0.09 && gameStarted {
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
        
        newPosition.x = max(-0.12, min(0.12, newPosition.x))
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
        
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        arView.session.run(config)
        
        // Create simple anchor that appears immediately
        let anchor = AnchorEntity(.plane(.horizontal, classification: .any, minimumBounds: SIMD2<Float>(0.2, 0.2)))
        
        // Add a simple test cube first to verify AR is working
        let testCube = Entity()
        let cubeMesh = MeshResource.generateBox(size: 0.05)
        let cubeMaterial = SimpleMaterial(color: .red, isMetallic: false)
        testCube.components.set(ModelComponent(mesh: cubeMesh, materials: [cubeMaterial]))
        testCube.position = [0, 0.025, 0]
        anchor.addChild(testCube)
        
        // Add simple wire path
        let wirePath = createSimpleWire()
        anchor.addChild(wirePath)
        
        // Add simple ring
        let ring = createSimpleRing()
        ring.position = [-0.1, 0.01, 0]
        gameState.ringEntity = ring
        anchor.addChild(ring)
        
        arView.scene.addAnchor(anchor)
        
        // Simple collision detection
        arView.scene.subscribe(to: CollisionEvents.Began.self) { event in
            DispatchQueue.main.async {
                gameState.buzz()
                soundManager.playBuzzSound()
            }
        }.store(in: &gameState.collisionSubscriptions)
        
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
    
    // Create simple straight wire with 3 segments
    let wirePoints: [SIMD3<Float>] = [
        [-0.1, 0.02, 0],
        [0, 0.03, 0],
        [0.1, 0.02, 0]
    ]
    
    for i in 0..<wirePoints.count {
        let wireSegment = Entity()
        let mesh = MeshResource.generateBox(size: [0.002, 0.002, 0.08])
        let material = SimpleMaterial(color: .orange, isMetallic: false)
        wireSegment.components.set(ModelComponent(mesh: mesh, materials: [material]))
        wireSegment.position = wirePoints[i]
        wireSegment.components.set(CollisionComponent(shapes: [.generateBox(size: [0.01, 0.01, 0.08])]))
        
        wireContainer.addChild(wireSegment)
    }
    
    return wireContainer
}

func createSimpleRing() -> Entity {
    let ring = Entity()
    let mesh = MeshResource.generateBox(size: [0.015, 0.015, 0.003])
    let material = SimpleMaterial(color: .blue, isMetallic: false)
    ring.components.set(ModelComponent(mesh: mesh, materials: [material]))
    ring.components.set(CollisionComponent(shapes: [.generateBox(size: [0.015, 0.015, 0.003])]))
    
    return ring
}

#Preview {
    BuzzWireGameView()
}