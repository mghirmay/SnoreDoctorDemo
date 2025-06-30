//
//  SessionDetailView.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 30.06.25.
//


// Example: In your parent view where ChartViewContent is used
struct SessionDetailView: View {
    @FetchRequest var soundEvents: FetchedResults<SoundEvent>
    // ... other properties

    init(session: Session) {
        // Configure fetch request for the session's sound events
        _soundEvents = FetchRequest(
            entity: SoundEvent.entity(),
            sortDescriptors: [NSSortDescriptor(keyPath: \SoundEvent.timestamp, ascending: true)],
            predicate: NSPredicate(format: "session == %@", session)
        )
    }

    var body: some View {
        VStack {
            Text("Sound Event Chart")
                .font(.headline)

            ChartViewContent(
                soundEvents: soundEvents,
                markerColor: chartMarkerColor, // <-- Pass the unified function here
                formatTimeInterval: formatTimeInterval // Assuming you have this defined too
            )
            .padding()
            // ... other view content
        }
    }

    // You might also define formatTimeInterval here or similarly centralize it
    func formatTimeInterval(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        let seconds = Int(interval.truncatingRemainder(dividingBy: 60))
        return String(format: "%d:%02d", minutes, seconds)
    }
}