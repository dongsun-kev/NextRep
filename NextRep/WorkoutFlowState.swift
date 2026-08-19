//
//  WorkoutFlowState.swift
//  NextRep
//
//  Created by DS on 8/19/26.
//



import Foundation

enum WorkoutFlowState: Equatable {
    case ready
    case exercising
    case setCompleted
    case resting
    case exerciseCompleted
    case sessionReview
    case completed
    case interrupted
}
