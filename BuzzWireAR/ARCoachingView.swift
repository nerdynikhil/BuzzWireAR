import SwiftUI
import ARKit

struct ARCoachingView: View {
    @State private var coachingState: ARCoachingOverlayView.Goal = .horizontalPlane
    @State private var isCoachingActive = true
    
    var body: some View {
        ZStack {
            if isCoachingActive {
                VStack(spacing: 20) {
                    Image(systemName: "viewfinder")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                        .scaleEffect(1.0 + sin(Date().timeIntervalSince1970 * 2) * 0.1)
                    
                    VStack(spacing: 12) {
                        Text("Find a Surface")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Point your device at a flat horizontal surface like a table or floor")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    HStack(spacing: 8) {
                        ForEach(0..<3) { index in
                            Circle()
                                .fill(Color.white.opacity(0.3))
                                .frame(width: 8, height: 8)
                                .scaleEffect(index == Int(Date().timeIntervalSince1970 * 2) % 3 ? 1.5 : 1.0)
                                .animation(.easeInOut(duration: 0.6), value: Date().timeIntervalSince1970)
                        }
                    }
                }
                .padding()
                .background(Color.black.opacity(0.8))
                .cornerRadius(16)
                .padding()
            }
        }
    }
}

struct ARInstructionsOverlay: View {
    let showInstructions: Bool
    
    var body: some View {
        if showInstructions {
            VStack {
                Spacer()
                
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        Image(systemName: "hand.draw")
                            .font(.title2)
                            .foregroundColor(.blue)
                        
                        Text("Drag to move the ring")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    
                    HStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title2)
                            .foregroundColor(.orange)
                        
                        Text("Avoid touching the wire")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    
                    HStack(spacing: 16) {
                        Image(systemName: "target")
                            .font(.title2)
                            .foregroundColor(.green)
                        
                        Text("Reach the end to win")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.8))
                .cornerRadius(12)
                .padding(.bottom, 100)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

struct ARPlaneVisualization: View {
    let planeDetected: Bool
    
    var body: some View {
        if planeDetected {
            VStack {
                Spacer()
                
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                    
                    Text("Surface detected - Ready to play!")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .padding()
                .background(Color.green.opacity(0.8))
                .cornerRadius(8)
                .padding(.bottom, 50)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

#Preview {
    ZStack {
        Color.black
        ARCoachingView()
    }
}