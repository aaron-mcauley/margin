import UIKit

final class UnderlineHoldGestureRecognizer: UIGestureRecognizer {

    private var holdTimer: Timer?
    var onHoldRecognized: (() -> Void)?
    private var minX: CGFloat = 0
    private var maxX: CGFloat = 0
    private var minY: CGFloat = 0
    private var maxY: CGFloat = 0
    private let holdDuration: TimeInterval = 2.0
    private let minimumUnderlineWidth: CGFloat = 100
    private let maximumUnderlineHeight: CGFloat = 40


    override func touchesBegan(
        _ touches: Set<UITouch>,
        with event: UIEvent
    ) {
        guard let touch = touches.first,
              touch.type == .pencil else {
            state = .failed
            return
        }
        
        let point = touch.location(in: view)

        minX = point.x
        maxX = point.x
        minY = point.y
        maxY = point.y
    }


    override func touchesMoved(
        _ touches: Set<UITouch>,
        with event: UIEvent
    ) {
        guard let touch = touches.first else { return }

        let point = touch.location(in: view)

        minX = min(minX, point.x)
        maxX = max(maxX, point.x)
        minY = min(minY, point.y)
        maxY = max(maxY, point.y)

        let width = maxX - minX
        let height = maxY - minY

        // Every time the Pencil moves, restart the timer.
        cancelHoldTimer()

        // Only begin the 2-second countdown once
        // the stroke looks like an underline.
        if width > minimumUnderlineWidth &&
           height < maximumUnderlineHeight {

            startHoldTimer()
        }
    }


    override func touchesEnded(
        _ touches: Set<UITouch>,
        with event: UIEvent
    ) {
        cancelHoldTimer()

        if state == .possible {
            state = .failed
        }
    }


    override func touchesCancelled(
        _ touches: Set<UITouch>,
        with event: UIEvent
    ) {
        cancelHoldTimer()
        state = .cancelled
    }


    override func reset() {
        cancelHoldTimer()
    }


    private func startHoldTimer() {
        let timer = Timer(
            timeInterval: holdDuration,
            repeats: false
        ) { [weak self] _ in

            guard let self else { return }

            print("2 SECOND UNDERLINE HOLD DETECTED")
            
            self.onHoldRecognized?()
            self.state = .recognized
        }

        holdTimer = timer

        RunLoop.main.add(
            timer,
            forMode: .common
        )
    }

    private func cancelHoldTimer() {
        holdTimer?.invalidate()
        holdTimer = nil
    }
}
