//
//  Live Activity + Dynamic Island for file transfers (ActivityKit).
//

import ActivityKit
import SwiftUI
import WidgetKit

@main
struct LocalSendLiveActivityBundle: WidgetBundle {
  var body: some Widget {
    FileTransferLiveActivityWidget()
  }
}

struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable {
  public typealias LiveDeliveryData = ContentState

  public struct ContentState: Codable, Hashable {}

  var id = UUID()
}

extension LiveActivitiesAppAttributes {
  func prefixedKey(_ key: String) -> String {
    "\(id)_\(key)"
  }
}

private let sharedDefault = UserDefaults(suiteName: "group.Ilyas")!

private let pollInterval: TimeInterval = 1.0

// MARK: - Read transfer state from shared UserDefaults

private struct TransferData {
  let title: String
  let subtitle: String
  let progress: Double
  let progressPct: Int
  let isSending: Bool

  init(context: ActivityViewContext<LiveActivitiesAppAttributes>) {
    let attrs = context.attributes
    title = sharedDefault.string(forKey: attrs.prefixedKey("title")) ?? "WinDrop"
    subtitle = sharedDefault.string(forKey: attrs.prefixedKey("subtitle")) ?? ""
    let raw = sharedDefault.double(forKey: attrs.prefixedKey("progress"))
    progress = Swift.min(Swift.max(raw, 0), 1)
    let rawPct = sharedDefault.integer(forKey: attrs.prefixedKey("progressPct"))
    progressPct = Swift.min(Swift.max(rawPct, 0), 100)
    isSending = sharedDefault.integer(forKey: attrs.prefixedKey("isSending")) == 1
  }
}

// MARK: - Widget

struct FileTransferLiveActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
      lockScreen(context: context)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.center) {
          expanded(context: context)
        }
      } compactLeading: {
        compactLeading(context: context)
      } compactTrailing: {
        compactTrailing(context: context)
      } minimal: {
        minimal(context: context)
      }
    }
  }

  // MARK: Lock Screen

  @ViewBuilder
  private func lockScreen(context: ActivityViewContext<LiveActivitiesAppAttributes>) -> some View {
    TimelineView(.periodic(from: Date(), by: pollInterval)) { _ in
      let d = TransferData(context: context)
      HStack(spacing: 12) {
        Image(systemName: d.isSending ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
          .font(.title2)
          .foregroundStyle(.cyan)
        VStack(alignment: .leading, spacing: 4) {
          Text(d.title)
            .font(.headline)
          if !d.subtitle.isEmpty {
            Text(d.subtitle)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          ProgressView(value: d.progress)
            .tint(.cyan)
        }
        Text("\(d.progressPct)%")
          .font(.title3.monospacedDigit().weight(.semibold))
          .foregroundStyle(.cyan)
      }
      .padding()
    }
  }

  // MARK: Expanded Island

  @ViewBuilder
  private func expanded(context: ActivityViewContext<LiveActivitiesAppAttributes>) -> some View {
    TimelineView(.periodic(from: Date(), by: pollInterval)) { _ in
      let d = TransferData(context: context)
      VStack(spacing: 6) {
        HStack {
          Image(systemName: d.isSending ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
            .foregroundStyle(.cyan)
          Text(d.isSending ? "Sending..." : "Receiving...")
            .font(.caption.weight(.semibold))
          Spacer()
          Text("\(d.progressPct)%")
            .font(.caption.monospacedDigit().weight(.bold))
            .foregroundStyle(.cyan)
        }
        ProgressView(value: d.progress)
          .tint(.cyan)
        if !d.subtitle.isEmpty {
          Text(d.subtitle)
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }
      .padding(.horizontal, 4)
    }
  }

  // MARK: Compact — leading: icon, trailing: percent

  @ViewBuilder
  private func compactLeading(context: ActivityViewContext<LiveActivitiesAppAttributes>) -> some View {
    TimelineView(.periodic(from: Date(), by: pollInterval)) { _ in
      let d = TransferData(context: context)
      Image(systemName: d.isSending ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
        .foregroundStyle(.cyan)
    }
  }

  @ViewBuilder
  private func compactTrailing(context: ActivityViewContext<LiveActivitiesAppAttributes>) -> some View {
    TimelineView(.periodic(from: Date(), by: pollInterval)) { _ in
      let d = TransferData(context: context)
      Text("\(d.progressPct)%")
        .font(.caption2.monospacedDigit().weight(.bold))
        .foregroundStyle(.cyan)
    }
  }

  // MARK: Minimal (when another app also has an activity)

  @ViewBuilder
  private func minimal(context: ActivityViewContext<LiveActivitiesAppAttributes>) -> some View {
    TimelineView(.periodic(from: Date(), by: pollInterval)) { _ in
      ProgressView()
        .progressViewStyle(.circular)
        .tint(.cyan)
    }
  }
}
