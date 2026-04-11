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
      HStack(spacing: 12) {
        ProgressView()
          .progressViewStyle(.circular)
          .tint(.cyan)
        Text("LocalSend")
          .font(.headline)
      }
      .padding()
    }
  }

  @ViewBuilder
  private func transferExpanded(context: ActivityViewContext<LiveActivitiesAppAttributes>) -> some View {
    TimelineView(.periodic(from: Date(), by: transferUiPollSeconds)) { _ in
      VStack(spacing: 8) {
        ProgressView()
          .progressViewStyle(.circular)
          .tint(.cyan)
        Text("Transferring...")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
      }
      .padding(.horizontal, 4)
    }
  }

  @ViewBuilder
  private func compactLeading(context: ActivityViewContext<LiveActivitiesAppAttributes>) -> some View {
    TimelineView(.periodic(from: Date(), by: transferUiPollSeconds)) { _ in
      ProgressView()
        .progressViewStyle(.circular)
        .tint(.cyan)
    }
  }

  @ViewBuilder
  private func compactTrailing(context: ActivityViewContext<LiveActivitiesAppAttributes>) -> some View {
    TimelineView(.periodic(from: Date(), by: transferUiPollSeconds)) { _ in
      ProgressView()
        .progressViewStyle(.circular)
        .tint(.cyan)
    }
  }

  @ViewBuilder
  private func minimalRegion(context: ActivityViewContext<LiveActivitiesAppAttributes>) -> some View {
    TimelineView(.periodic(from: Date(), by: transferUiPollSeconds)) { _ in
      ProgressView()
        .progressViewStyle(.circular)
        .tint(.cyan)
    }
  }
}
