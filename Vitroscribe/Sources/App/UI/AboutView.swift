import SwiftUI

struct AboutView: View {
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Section with Gradient
            ZStack {
                LinearGradient(colors: [.blue.opacity(0.15), .purple.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .frame(height: 140)
                
                VStack(spacing: 12) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                    
                    Text("Vitroscribe")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    
                    Text("Version \(version)")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.05))
                        .cornerRadius(6)
                }
                .padding(.top, 20)
            }
            
            VStack(spacing: 24) {
                // Message
                VStack(spacing: 12) {
                    Text("Crafted for clarity and focus.")
                        .font(.system(size: 14, weight: .medium, design: .serif))
                        .italic()
                        .foregroundColor(.blue)
                    
                    Text("Vitroscribe keeps your meetings documented locally and privately, so you can stay present in every conversation.")
                        .font(.system(size: 13))
                        .lineSpacing(4)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.primary.opacity(0.8))
                }
                .padding(.horizontal, 30)
                
                Divider()
                    .padding(.horizontal, 60)
                
                // Author Section
                VStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Text("Designed & Developed by")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary.opacity(0.6))
                            .textCase(.uppercase)
                            .tracking(1.5)
                        
                        Text("Nikki Punjabi")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    
                    Button(action: {
                        if let url = URL(string: "https://www.linkedin.com/in/nikkipunjabi/") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "link")
                            Text("Connect on LinkedIn")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color.blue)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 24)
            .padding(.bottom, 30)
            
            Spacer()
            
            Text("© 2026 Vitroscribe • Privacy First Architecture")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary.opacity(0.4))
                .padding(.bottom, 15)
        }
        .frame(width: 380, height: 500)
        .background(VisualEffectView().ignoresSafeArea())
    }
}

struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        AboutView()
    }
}
