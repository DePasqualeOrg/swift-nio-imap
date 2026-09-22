//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2021 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIOIMAPCore

public struct InvalidIdleState: Error, Hashable {
    public init() {}
}

extension ClientStateMachine {
    struct Idle: Hashable {
        enum State: Hashable {
            case waitingForConfirmation
            case idling
        }

        private var state: State = .waitingForConfirmation

        mutating func sendCommand(_ command: CommandStreamPart) {
            switch self.state {
            case .idling:
                break
            case .waitingForConfirmation:
                preconditionFailure("Invalid state: \(self.state)")
            }

            switch command {
            case .idleDone:
                break
            case .tagged, .append, .continuationResponse:
                preconditionFailure("Invalid command for idle state")
            }
        }

        /// Untagged data is accepted both before and after the server's continuation: a server
        /// flushes pending mailbox notifications when it processes `IDLE`, and some send them
        /// ahead of the `+`. Anything else is out of place in either state.
        mutating func receiveResponse(_ response: Response) throws {
            switch response {
            case .untagged, .fetch:
                break
            case .tagged, .fatal, .authenticationChallenge, .idleStarted:
                switch self.state {
                case .waitingForConfirmation:
                    throw UnexpectedResponse(kind: .idleWaitingForConfirmation)
                case .idling:
                    throw UnexpectedResponse(kind: .idleRunning)
                }
            }
        }

        mutating func receiveContinuationRequest(_: ContinuationRequest) throws {
            switch self.state {
            case .waitingForConfirmation:
                self.state = .idling
            case .idling:
                throw UnexpectedContinuationRequest(kind: .idle)
            }
        }
    }
}
