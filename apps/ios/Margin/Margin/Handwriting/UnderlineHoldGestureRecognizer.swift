import UIKit

final class UnderlineHoldGestureRecognizer: UIGestureRecognizer {
    
    // MARK: - CALLBACKS
    
    var onHoldRecognized: (() -> Void)?
    var onConfirmed: ((CGRect) -> Void)?
    var onCancelled: (() -> Void)?
    
    // MARK: - TRACKING
    
    private var holdTimer: Timer?
    private var minX: CGFloat = 0
    private var maxX: CGFloat = 0
    private var minY: CGFloat = 0
    private var maxY: CGFloat = 0
    private var longestHoldTime: TimeInterval = 0
    private var timerResetCount: Int = 0
    private var holdAnchorPoint: CGPoint = .zero
    private var holdStartTime: TimeInterval?
    private var lockedPoint: CGPoint = .zero
    private var isUnderlineCandidate = false
    private var isLocked = false
    
    // MARK: - Configuration
    
    private let holdDuration: TimeInterval = 1.25
    private let minimumUnderlineWidth: CGFloat = 100
    private let maximumUnderlineHeight: CGFloat = 40
    
    // Small movement allowed while acquiring the hold.
    private let stationaryTolerance: CGFloat = 5
    
    // Once locked, user must diliberately move this far to cancel
    private let cancellationDistance: CGFloat = 15
    
    // MARK: - Touches
    
    override func touchesBegan(
        
      
        _ touches: Set<UITouch>,
        with event: UIEvent
    )   {
        guard let touch = touches.first, touch.type == .pencil else {
            state = .failed
            return
        }
        
        let point = touch.location(in: view)
        
        minX = point.x
        maxX = point.x
        minY = point.y
        maxY = point.y
        
        holdAnchorPoint = point
        
        print("[UNDERLINE] TOUCH BEGAN")

    }
    
    override func touchesMoved(
        _ touches: Set<UITouch>,
        with event: UIEvent
    )   {
        guard let touch = touches.first else {
            return
        }
        
        let point = touch.location(in: view)
        
        // ALREADY LOCKED
        
        if isLocked {
            let distanceFromLock = distanceBetween(
                point,
                lockedPoint
            )
            
            if distanceFromLock > cancellationDistance {
                
                print(
                    "[UNDERLINE] LOCK CANCELLED | movement:",
                    distanceFromLock
                    )
                cancelLockedGesture()
            }
            
            return
        }
        
        // STILL DRAWING UNDERLINE
        
        minX = min(minX, point.x)
        maxX = max(maxX, point.x)
        minY = min(minY, point.y)
        maxY = max(maxY, point.y)
        
        let width = maxX - minX
        let height = maxY - minY
        
        let looksLikeUnderline = width >= minimumUnderlineWidth && height <= maximumUnderlineHeight
        
        isUnderlineCandidate = looksLikeUnderline
        
        // It isn't underline-shaped yet
        
        if !looksLikeUnderline {
            cancelHoldTimer()
            return
        }
        
        // MARK: Hold Acqusition
        
        // First moment the stroke becomes a valid underline
        if holdTimer == nil {
            holdAnchorPoint = point

            print(
                "[UNDERLINE] HOLD WINDOW STARTED",
                "| width:", width,
                "| height:", height
            )
            
            startHoldTimer()
            return
        }
        
        let movementFromAnchor = distanceBetween(point, holdAnchorPoint)
        
        // User is still drawing.
        // Move the anchor forward and restart the stationary window
        
        if movementFromAnchor > stationaryTolerance {
            print(
                    "[UNDERLINE] HOLD WINDOW RESET",
                    "| movement:", movementFromAnchor
                )
            cancelHoldTimer()
            holdAnchorPoint = point
            startHoldTimer()
        }
    }
    
    override func touchesEnded(
        _ touches: Set<UITouch>,
        with event: UIEvent
    ) {
        cancelHoldTimer()

        let finalWidth = maxX - minX
        let finalHeight = maxY - minY

        let geometryPassed =
            finalWidth >= minimumUnderlineWidth &&
            finalHeight <= maximumUnderlineHeight

        
        // Successfully locked, then Pencil lifted = CONFIRMED.
        if isLocked {

            print(
                "UNDERLINE RESULT: CONFIRMED",
                "| geometry:", geometryPassed ? "PASS" : "FAIL",
                "| width:", finalWidth,
                "| height:", finalHeight,
                "| longest hold:", String(format: "%.2f", longestHoldTime), "sec",
                "| timer cancellations:", timerResetCount

            )

            let underlineBounds = CGRect(
                x: minX,
                y: minY,
                width: finalWidth,
                height: finalHeight
            )

            onConfirmed?(underlineBounds)

            state = .recognized
            return
        }

        // Pencil lifted before gesture locked.
        if state == .possible {

            print(
                "UNDERLINE RESULT: NOT LOCKED",
                "| geometry:", geometryPassed ? "PASS" : "FAIL",
                "| width:", finalWidth,
                "| height:", finalHeight,
                "| longest hold:", String(format: "%.2f", longestHoldTime), "sec",
                "| timer cancellations:", timerResetCount
            )

            state = .failed
        }
    }
    
    override func reset() {
        cancelHoldTimer()
        
        isLocked = false
        isUnderlineCandidate = false
        
        holdStartTime = nil
        longestHoldTime = 0
        timerResetCount = 0
        holdAnchorPoint = .zero
        
        minX = 0
        maxX = 0
        minY = 0
        maxY = 0
        
        lockedPoint = .zero
    }
    
    // MARK: - Hold
    
    private func startHoldTimer() {

        guard holdTimer == nil else {
            return
        }

        holdStartTime = CACurrentMediaTime()
        
        let timer = Timer(
            timeInterval: holdDuration,
            repeats: false
        ) { [weak self] _ in

            guard let self else {
                return
            }
            
            self.longestHoldTime = max(
                self.longestHoldTime,
                self.holdDuration
            )

            self.holdTimer = nil
            self.lockUnderline()
        }

        holdTimer = timer

        RunLoop.main.add(
            timer,
            forMode: .common
        )
    }
    
    private func cancelHoldTimer() {
        
        if holdTimer != nil  {
            let elapsed = holdStartTime.map {
                CACurrentMediaTime() - $0
            } ?? 0
            
            longestHoldTime = max(
                longestHoldTime,
                elapsed
            )
            
            timerResetCount += 1
        }
        holdTimer?.invalidate()
        holdTimer = nil
    }
    
    private func lockUnderline() {
        guard !isLocked else {
            return
        }
        
        isLocked = true
        lockedPoint = holdAnchorPoint
                
        // turn underline blue here
        
        print(
            "[UNDERLINE] LOCKED",
            "| hold:", String(format: "%.2f", longestHoldTime), "sec"
        )
        
        onHoldRecognized?()
        }
    
    private func cancelLockedGesture() {
        guard isLocked else {
            return
        }
                
        isLocked = false
        cancelHoldTimer()
                
        // remove blue uunderline here
        
        onCancelled?()
        
        state = .failed
    }
    
    // MARK: - Helpers
    
    private func distanceBetween(_ first: CGPoint, _ second: CGPoint) -> CGFloat {
        hypot(first.x - second.x, first.y - second.y)
    }
    
    
}
