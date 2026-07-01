//
//  CareBridgeWidgetBundle.swift
//  CareBridgeWidget
//
//  Created by Ishaan Desai on 6/30/26.
//

import WidgetKit
import SwiftUI

@main
struct CareBridgeWidgetBundle: WidgetBundle {
    var body: some Widget {
        CareBridgeWidget()
        CareBridgeWidgetControl()
        CareBridgeWidgetLiveActivity()
    }
}
