import UIKit

final class UnderlineHoldGestureRecognizer: UIGestureRecognizer {
    
    // MARK: - CALLBACKS
    
    var onHoldRecognized: (() -> Void)?
    var onConfirmed: (() -> Void)?
    var onCancelled: (() -> Void)?
    
    // MARK: - TRACKING
    
    private var holdTimer: Timer?
    private var minX: CGFloat = 0
    private var maxX: CGFloat = 0
    private var minY: CGFloat = 0
    private var maxY: CGFloat = 0

    private var lastMovementPoint: CGPoint = .zero
    private var lockedPoint: CGPoint = .zero
    
    private var isLocked = false
    
    // MARK: - Configuration
    
    private let holdDuration: TimeInterval = 2.0
    
    private let minimumUnderlineWidth: CGFloat = 100
    private let maximumUnderlineHeight: CGFloat = 40
    
    // Ignore tiny Apple Pencil / hand jitter
    private let movementTolerance: CGFloat = 6
    
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
        lastMovementPoint = point
        isLocked = false
        
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
            let distance = distanceBetween(
                point,
                lockedPoint
            )
            
            if distance > cancellationDistance {
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
        
        let movement = distanceBetween(
            point,
            lastMovementPoint
        )
        
        // Pencil is still deliberately moving
        if movement > movementTolerance {
            lastMovementPoint = point
            
            cancelHoldTimer()
            
            if width > minimumUnderlineWidth &&
                height < maximumUnderlineHeight {
                
                startHoldTimer()
            }
        }
    }
    
    override func touchesEnded(
        _ touches: Set<UITouch>,
        with event: UIEvent
    )   {
        cancelHoldTimer()
        
        // Locked - Pencil lifted = CONFIRM.
        if isLocked {
            
            onConfirmed?()
            
            state = .recognized
            return
        }
        
        // User lifted before the 2-second lock.
        if state ==  .possible {
            state = .failed
        }
    }
    
    override func reset() {
        cancelHoldTimer()
        
        isLocked = false
        
        minX = 0
        maxX = 0
        minY = 0
        maxY = 0
        
        lastMovementPoint = .zero
        lockedPoint = .zero
    }
    
    // MARK: - Hold
    
    private func startHoldTimer() {
        
        // dont create another timer if one already exist
        guard holdTimer == nil else {
            return
        }
        
        let timer = Timer (
        timeInterval: holdDuration,
        repeats: false
        ) {[weak self] _ in
            
            guard let self else {
                return
            }
            
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
        holdTimer?.invalidate()
        holdTimer = nil
    }
    
    private func lockUnderline() {
        guard !isLocked else {
            return
        }
        
        isLocked = true
        lockedPoint = lastMovementPoint
                
        // turn underline blue here
        
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
