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

private let sharedDefault = UserDefaults(suiteName: "group.org.localsend.localsendApp")!

/// UserDefaults in the app group updates when Flutter pushes progress, but ActivityKit may not
/// re-render the widget when [ContentState] from the plugin is unchanged. Periodic timeline
/// forces fresh reads so Dynamic Island / lock screen show live percentages.
private let transferUiPollSeconds: TimeInterval = 0.5

struct FileTransferLiveActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
      transferLockScreen(context: context)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.center) {
          transferExpanded(context: context)
        }
      } compactLeading: {
        compactLeading(context: context)
      } compactTrailing: {
        compactTrailing(context: context)
      } minimal: {
        minimalRegion(context: context)
      }
    }
  }

  @ViewBuilder
  private func transferLockScreen(context: ActivityViewContext<LiveActivitiesAppAttributes>) -> some View {
    TimelineView(.periodic(from: Date(), by: transferUiPollSeconds)) { _ in
      let title = sharedDefault.string(forKey: context.attributes.prefixedKey("title")) ?? "LocalSend"
      let subtitle = sharedDefault.string(forKey: context.attributes.prefixedKey("subtitle")) ?? ""
      let progress = sharedDefault.double(forKey: context.attributes.prefixedKey("progress"))

      VStack(alignment: .leading, spacing: 6) {
        Text(title)
          .font(.headline)
        if !subtitle.isEmpty {
          Text(subtitle)
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        ProgressView(value: min(max(progress, 0), 1))
      }
      .padding()
    }
  }

  @ViewBuilder
  private func transferExpanded(context: ActivityViewContext<LiveActivitiesAppAttributes>) -> some View {
    TimelineView(.periodic(from: Date(), by: transferUiPollSeconds)) { _ in
      let title = sharedDefault.string(forKey: context.attributes.prefixedKey("title")) ?? "LocalSend"
      let subtitle = sharedDefault.string(forKey: context.attributes.prefixedKey("subtitle")) ?? ""
      let progress = sharedDefault.double(forKey: context.attributes.prefixedKey("progress"))

      VStack(spacing: 4) {
        Text(title)
          .font(.caption.weight(.semibold))
        if !subtitle.isEmpty {
          Text(subtitle)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        ProgressView(value: min(max(progress, 0), 1))
          .tint(.cyan)
      }
      .padding(.horizontal, 4)
    }
  }

  @ViewBuilder
  private func compactLeading(context: ActivityViewContext<LiveActivitiesAppAttributes>) -> some View {
    TimelineView(.periodic(from: Date(), by: transferUiPollSeconds)) { _ in
      let isSend = sharedDefault.integer(forKey: context.attributes.prefixedKey("isSending")) == 1
      Image(systemName: isSend ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
        .foregroundStyle(.cyan)
    }
  }

  @ViewBuilder
  private func compactTrailing(context: ActivityViewContext<LiveActivitiesAppAttributes>) -> some View {
    TimelineView(.periodic(from: Date(), by: transferUiPollSeconds)) { _ in
      let progress = sharedDefault.double(forKey: context.attributes.prefixedKey("progress"))
      Text("\(Int((min(max(progress, 0), 1) * 100).rounded()))%")
        .font(.caption2.weight(.semibold))
        .monospacedDigit()
    }
  }

  @ViewBuilder
  private func minimalRegion(context: ActivityViewContext<LiveActivitiesAppAttributes>) -> some View {
    TimelineView(.periodic(from: Date(), by: transferUiPollSeconds)) { _ in
      let progress = sharedDefault.double(forKey: context.attributes.prefixedKey("progress"))
      Text("\(Int((min(max(progress, 0), 1) * 100).rounded()))")
        .font(.caption2.weight(.bold))
        .monospacedDigit()
    }
  }
}
