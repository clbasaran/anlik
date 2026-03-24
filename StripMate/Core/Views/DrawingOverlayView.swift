import SwiftUI
import PencilKit

/// Drawing overlay for photo editing before sending
struct DrawingOverlayView: View {
    let backgroundImage: UIImage
    let onSave: (UIImage) -> Void
    let onCancel: () -> Void
    
    @State private var canvasView = PKCanvasView()
    @State private var selectedColor: Color = .white
    @State private var lineWidth: CGFloat = 4
    @State private var toolType: PKInkingTool.InkType = .pen
    @State private var isErasing = false
    
    private let colors: [Color] = [.white, .red, .yellow, .green, .blue, .purple, .orange]
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Button {
                        onCancel()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel(String(localized: "Çizimi iptal et"))
                    
                    Spacer()
                    
                    Text(String(localized: "çizim"))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    Button {
                        saveDrawing()
                    } label: {
                        Text(String(localized: "tamam"))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 9)
                            .background(Color.white)
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)
                
                // Canvas area
                ZStack {
                    Image(uiImage: backgroundImage)
                        .resizable()
                        .scaledToFit()
                    
                    DrawingCanvas(canvasView: $canvasView, lineWidth: lineWidth, color: UIColor(selectedColor), toolType: toolType, isErasing: isErasing)
                        .allowsHitTesting(true)
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 8)
                
                // Tool bar
                VStack(spacing: 16) {
                    // Color picker
                    HStack(spacing: 8) {
                        ForEach(colors, id: \.self) { color in
                            Circle()
                                .fill(color)
                                .frame(width: selectedColor == color ? 32 : 24, height: selectedColor == color ? 32 : 24)
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.white, lineWidth: selectedColor == color ? 2 : 0)
                                )
                                .frame(width: 44, height: 44)
                                .contentShape(Circle())
                                .onTapGesture {
                                    selectedColor = color
                                    isErasing = false
                                    HapticsManager.playSelection()
                                }
                                .accessibilityLabel(String(localized: "Renk seç"))
                        }
                        
                        Spacer()
                        
                        // Eraser
                        Button {
                            isErasing.toggle()
                            HapticsManager.playImpact(style: .light)
                        } label: {
                            Image(systemName: isErasing ? "eraser.fill" : "eraser")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(isErasing ? .black : .white.opacity(0.6))
                                .frame(width: 44, height: 44)
                                .background(isErasing ? Color.white : Color.white.opacity(0.08))
                                .clipShape(Circle())
                        }
                        .accessibilityLabel(String(localized: "Silgi"))

                        // Undo
                        Button {
                            canvasView.undoManager?.undo()
                            HapticsManager.playImpact(style: .light)
                        } label: {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))
                                .frame(width: 44, height: 44)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Circle())
                        }
                        .accessibilityLabel(String(localized: "Geri al"))
                    }
                    .padding(.horizontal, 20)
                    
                    // Stroke width slider
                    HStack(spacing: 12) {
                        Circle()
                            .fill(.white.opacity(0.3))
                            .frame(width: 8, height: 8)

                        Slider(value: $lineWidth, in: 1...20, step: 1)
                            .tint(.white.opacity(0.5))
                            .accessibilityLabel(String(localized: "Çizgi kalınlığı"))

                        Circle()
                            .fill(.white.opacity(0.3))
                            .frame(width: 20, height: 20)
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 16)
            }
        }
    }
    
    private func saveDrawing() {
        let renderer = UIGraphicsImageRenderer(size: backgroundImage.size)
        let composited = renderer.image { ctx in
            backgroundImage.draw(in: CGRect(origin: .zero, size: backgroundImage.size))
            
            // Scale canvas drawing to image size
            let canvasSize = canvasView.bounds.size
            guard canvasSize.width > 0, canvasSize.height > 0 else { return }
            
            let scaleX = backgroundImage.size.width / canvasSize.width
            let scaleY = backgroundImage.size.height / canvasSize.height
            
            ctx.cgContext.scaleBy(x: scaleX, y: scaleY)
            
            let drawingImage = canvasView.drawing.image(from: canvasView.bounds, scale: UIScreen.current.scale)
            drawingImage.draw(in: canvasView.bounds)
        }
        onSave(composited)
    }
}

/// UIViewRepresentable wrapper for PKCanvasView
struct DrawingCanvas: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    var lineWidth: CGFloat
    var color: UIColor
    var toolType: PKInkingTool.InkType
    var isErasing: Bool
    
    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.drawingPolicy = .anyInput
        updateTool()
        return canvasView
    }
    
    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        updateTool()
    }
    
    private func updateTool() {
        if isErasing {
            canvasView.tool = PKEraserTool(.bitmap)
        } else {
            canvasView.tool = PKInkingTool(toolType, color: color, width: lineWidth)
        }
    }
}
