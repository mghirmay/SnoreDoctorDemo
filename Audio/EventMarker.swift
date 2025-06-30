import SwiftUI
import AVFoundation
import CoreData

// MARK: - EventMarker View
struct EventMarker: View {
    let event: SoundEvent
    let selectedRecordingSession: RecordingSession? // Pass the session
    @ObservedObject var viewModel: AudioPlaybackViewModel // Pass the ViewModel
    let timelineWidth: CGFloat // Pass the width from GeometryReader
    let audioDuration: TimeInterval // ADDED: Pass the audio duration as a direct value

    // Re-declare or pass formatters if needed. For this small helper, re-declaring is fine.
    // If you prefer to avoid duplication, you could pass it or make it static in a common utility.
    static let timeFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()

    var body: some View {
        // Use guard let to unwrap optionals early and cleanly
        guard let timestamp = event.timestamp,
              let actualRecordingStartTime = selectedRecordingSession?.startTime,
              audioDuration > 0 else { // Use audioDuration here
            return AnyView(EmptyView()) // Return EmptyView if essential data is missing
        }

        let relativeTime = timestamp.timeIntervalSince(actualRecordingStartTime)
        // Ensure relativeTime is not negative, though the max(0, ...) in onTapGesture helps too
        let safeRelativeTime = max(0, relativeTime)

        // Calculate position based on the passed timelineWidth
        let position = CGFloat(safeRelativeTime / audioDuration) * timelineWidth

        // Only draw the marker if it's within the visible bounds
        if position >= 0 && position <= timelineWidth {
            return AnyView(
                VStack {
                    Circle()
                        .fill(markerColor(for: event.name))
                        .frame(width: 15, height: 15)
                        .overlay(Circle().stroke(Color.white, lineWidth: 1))
                    Text(event.name ?? "Event")
                        .font(.caption2)
                        .lineLimit(1)
                }
                .offset(x: position - 7.5) // Adjust offset to center the marker
                .onTapGesture {
                    viewModel.seek(to: safeRelativeTime) // Still need viewModel for methods
                    viewModel.play()
                }
            )
        } else {
            return AnyView(EmptyView())
        }
    }

    // Helper function for marker color (can be a method of the struct)

    
     func markerColor(for eventName: String?) -> Color {
         guard let name = eventName else { return .gray } // Default for nil

         switch name {
         case "Snoring": return .red
         case "Snoring (Speech-like)": return .orange
         case "Snoring (Noise)": return .brown
         case "Snoring (Noise/Breathing)": return .purple
         case "Quiet": return .green
         case "Silence": return .teal
         case "Speech": return .blue
         case "Talking": return .indigo
         case "Cough": return .cyan
         case "Noise": return .yellow
         case "Other/Unknown": return .pink
         default: return .gray // VERY IMPORTANT: A fallback color for any unlisted name
         }
     }
}
