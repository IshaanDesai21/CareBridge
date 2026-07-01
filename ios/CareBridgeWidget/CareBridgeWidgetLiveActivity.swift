//
//  CareBridgeWidgetLiveActivity.swift
//  CareBridgeWidget
//
//  Created by Ishaan Desai on 6/30/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct CareBridgeWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct CareBridgeWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CareBridgeWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension CareBridgeWidgetAttributes {
    fileprivate static var preview: CareBridgeWidgetAttributes {
        CareBridgeWidgetAttributes(name: "World")
    }
}

extension CareBridgeWidgetAttributes.ContentState {
    fileprivate static var smiley: CareBridgeWidgetAttributes.ContentState {
        CareBridgeWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: CareBridgeWidgetAttributes.ContentState {
         CareBridgeWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: CareBridgeWidgetAttributes.preview) {
   CareBridgeWidgetLiveActivity()
} contentStates: {
    CareBridgeWidgetAttributes.ContentState.smiley
    CareBridgeWidgetAttributes.ContentState.starEyes
}
