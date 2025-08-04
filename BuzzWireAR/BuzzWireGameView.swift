import SwiftUI
import RealityKit
import ARKit
import Combine

@Observable
class BuzzWireGameState {
    var gameStarted = false
    var gameTime: TimeInterval = 0
    var buzzCount = 0
    var isGameWon = false
    var isGameLost = false
    var ringPosition: SIMD3<Float> = [-0.15, 0.02, 0]
    var ringEntity: Entity?
    var wireEntities: [Entity] = []
    private var gameTimer: Timer?
    private var collisionSubscription: AnyCancellable?
    
    func startGame() {
        gameStarted = true
        gameTime = 0
        buzzCount = 0
        isGameWon = false
        isGameLost = false
        ringPosition = [-0.15, 0.02, 0]
        
        gameTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            self.gameTime += 0.1
        }
        
        setupCollisionDetection()
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
    
    private func setupCollisionDetection() {
        guard let ringEntity = ringEntity else { return }
        
        collisionSubscription = ringEntity.scene?.subscribe(to: CollisionEvents.Began.self) { event in
            if event.entityA == ringEntity || event.entityB == ringEntity {
                DispatchQueue.main.async {
                    self.buzz()
                }
            }
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
            RealityView { content in
                setupBuzzWireGame(content: content, gameState: gameState, soundManager: soundManager, onPlaneDetected: {
                    planeDetected = true
                })
            } update: { content in
                updateGame(content: content, gameState: gameState)
            }
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
                            soundManager.playSuccessSound()
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
    }
    
    private func handleDrag(value: DragGesture.Value) {
        let sensitivity: Float = 0.0003
        let deltaX = Float(value.translation.x) * sensitivity
        let deltaY = -Float(value.translation.y) * sensitivity
        
        var newPosition = gameState.ringPosition
        newPosition.x += deltaX
        newPosition.y += deltaY
        
        newPosition.x = max(-0.16, min(0.16, newPosition.x))
        newPosition.y = max(0.01, min(0.05, newPosition.y))
        
        gameState.moveRing(to: newPosition)
    }
}

func setupBuzzWireGame(content: inout RealityViewContent, gameState: BuzzWireGameState, soundManager: SoundManager, onPlaneDetected: @escaping () -> Void) {
    let anchor = AnchorEntity(.plane(.horizontal, classification: .any, minimumBounds: SIMD2<Float>(0.3, 0.3)))
    
    onPlaneDetected()
    
    let wireContainer = createWirePath()
    gameState.wireEntities = wireContainer.children.compactMap { $0 as? Entity }
    anchor.addChild(wireContainer)
    
    let ringEntity = createRing()
    ringEntity.position = gameState.ringPosition
    gameState.ringEntity = ringEntity
    anchor.addChild(ringEntity)
    
    content.add(anchor)
    
    setupGameSounds(gameState: gameState, soundManager: soundManager)
}

func setupGameSounds(gameState: BuzzWireGameState, soundManager: SoundManager) {
    gameState.ringEntity?.scene?.subscribe(to: CollisionEvents.Began.self) { event in
        if event.entityA == gameState.ringEntity || event.entityB == gameState.ringEntity {
            DispatchQueue.main.async {
                soundManager.playBuzzSound()
            }
        }
    }
}

func updateGame(content: inout RealityViewContent, gameState: BuzzWireGameState) {
    gameState.ringEntity?.position = gameState.ringPosition
}

func createWirePath() -> Entity {
    let wireContainer = Entity()
    
    let wirePoints: [SIMD3<Float>] = [
        [-0.15, 0.01, 0],
        [-0.1, 0.03, 0.02],
        [-0.05, 0.015, -0.015],
        [0, 0.035, 0.01],
        [0.05, 0.02, -0.01],
        [0.1, 0.04, 0.015],
        [0.15, 0.01, 0]
    ]
    
    for i in 0..<(wirePoints.count - 1) {
        let startPoint = wirePoints[i]
        let endPoint = wirePoints[i + 1]
        
        let distance = length(endPoint - startPoint)
        let center = (startPoint + endPoint) / 2
        
        let wireSegment = Entity()
        let mesh = MeshResource.generateCylinder(height: distance, radius: 0.002)
        let material = SimpleMaterial(color: .init(red: 0.8, green: 0.6, blue: 0.2, alpha: 1), roughness: 0.3, isMetallic: true)
        wireSegment.components.set(ModelComponent(mesh: mesh, materials: [material]))
        
        let direction = normalize(endPoint - startPoint)
        let up = SIMD3<Float>(0, 1, 0)
        let right = normalize(cross(up, direction))
        let newUp = cross(direction, right)
        
        let rotationMatrix = float4x4(
            SIMD4<Float>(right.x, right.y, right.z, 0),
            SIMD4<Float>(newUp.x, newUp.y, newUp.z, 0),
            SIMD4<Float>(direction.x, direction.y, direction.z, 0),
            SIMD4<Float>(0, 0, 0, 1)
        )
        
        wireSegment.transform.matrix = rotationMatrix
        wireSegment.position = center
        
        wireSegment.components.set(CollisionComponent(shapes: [.generateCylinder(height: distance, radius: 0.006)]))
        
        wireContainer.addChild(wireSegment)
    }
    
    let startPost = Entity()
    let startMesh = MeshResource.generateCylinder(height: 0.05, radius: 0.003)
    let postMaterial = SimpleMaterial(color: .init(red: 0.2, green: 0.2, blue: 0.2, alpha: 1), roughness: 0.8, isMetallic: false)
    startPost.components.set(ModelComponent(mesh: startMesh, materials: [postMaterial]))
    startPost.position = [-0.15, -0.025, 0]
    wireContainer.addChild(startPost)
    
    let endPost = Entity()
    endPost.components.set(ModelComponent(mesh: startMesh, materials: [postMaterial]))
    endPost.position = [0.15, -0.025, 0]
    wireContainer.addChild(endPost)
    
    return wireContainer
}

func createRing() -> Entity {
    let ring = Entity()
    let mesh = MeshResource.generateTorus(outerRadius: 0.01, innerRadius: 0.007)
    let material = SimpleMaterial(color: .init(red: 0.1, green: 0.5, blue: 0.9, alpha: 1), roughness: 0.2, isMetallic: true)
    ring.components.set(ModelComponent(mesh: mesh, materials: [material]))
    
    ring.components.set(CollisionComponent(shapes: [.generateTorus(outerRadius: 0.01, innerRadius: 0.007)]))
    
    return ring
}

#Preview {
    BuzzWireGameView()
}