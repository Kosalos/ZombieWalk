import UIKit

let XMAX = Int(50)
let YMAX = XMAX * 1024 / 768

let EMPTY:Int = 0
let ZOMBIE:Int = 20000
let TARGET:Int = 20001
let TERRAIN:Int = 21000
let MAX_HEIGHT:Int = 100
let MAX_TERRAIN:Int = TERRAIN + MAX_HEIGHT
let PATH:Int = 30000
let WALL:Int = 30001

let MAX_STACK = XMAX * YMAX

struct Position {
    var x = Int(0)
    var y = Int(0)
    
    init() { self.init(0,0) }
    init(_ xx:Int, _ yy:Int) { x = xx; y = yy }
    
    func offset(_ dx:Int, _ dy:Int) -> Position { return Position(x + dx, y + dy) }
    func isSame(_ pt:Position) -> Bool { return x == pt.x && y == pt.y }
}

struct Board {
    var cell = Array(repeating: Array(repeating:Int(), count:YMAX), count:XMAX)
}

struct StackData {
    var pt = Position()
    var value = Int()
    
    init(_ npt:Position, _ nValue:Int) { pt = npt; value = nValue }
}

var stack:[StackData] = []
var path:[Position] = []

var baseBoard = Board()     // true, un-smoothed board
var currentBoard = Board()  // baseBoard after smoothing
var tempBoard = Board()
var illumination = Board()

var startPosition = Position()
var endPosition = Position()
var smoothAmount:Int = 5
var mode:Int = 0

// MARK:-

class ZombieView: UIView {
    var cellSize = CGSize()
    var context:CGContext! = nil
    
    func initialize() {
        cellSize.width = bounds.width / CGFloat(XMAX)
        cellSize.height = bounds.height / CGFloat(YMAX)
        reset()
    }
    
    // MARK:-
    
    func isLegalPosition(_ x:Int, _ y:Int) -> Bool { return x > 0 && x < XMAX-1 &&  y > 0 && y < YMAX-1 }
    
    func reset() {
        func setbaseBoardHeight(_ x:Int, _ y:Int, _ value:Int) {
            if isLegalPosition(x,y) { baseBoard.cell[x][y] = value }
        }

        startPosition = Position(2,2)
        endPosition = Position(XMAX-3,YMAX-3)
        
        for x in 0 ..< XMAX {
            for y in 0 ..< YMAX {
                baseBoard.cell[x][y] = TERRAIN
            }
        }
        
        func iRandom(_ max:Int) -> Int { return Int(arc4random()) % max }
        
        for _ in 0 ..< 500 {
            let x = iRandom(XMAX)
            let y = iRandom(YMAX)
            let height = TERRAIN + iRandom(MAX_HEIGHT)
            
            for m in -6 ... 6 {
                for n in -6 ... 6 {
                    setbaseBoardHeight(x+m,y+n,height)
                }
            }
        }

        for x in 0 ..< XMAX {
            baseBoard.cell[x][0] = WALL
            baseBoard.cell[x][YMAX-1] = WALL
        }

        for y in 0 ..< YMAX {
            baseBoard.cell[0][y] = WALL
            baseBoard.cell[XMAX-1][y] = WALL
        }

        updateIllumination()
        refresh(true)
    }
    
    func setMode(_ nMode:Int) { mode = nMode }
    
    // MARK:-
    
    func refresh(_ reCalcPath:Bool) {
        applySmooth()
        
        if reCalcPath { findEasiestPath() }
        
        setNeedsDisplay()
    }
    
    func setSmoothAmount(_ ratio:Float) {
        smoothAmount = Int(ratio * 10)
        refresh(true)
    }
    
    func applySmooth() {
        currentBoard = baseBoard
        
        for _ in 0 ..< smoothAmount {
            tempBoard = currentBoard
            
            for x in 1 ..< XMAX - 1 {
                for y in 1 ..< YMAX - 1 {
                    if currentBoard.cell[x][y] == WALL { continue }
                    
                    var total:Int = 0
                    var count:Int = 0
                    
                    for dx in -1 ... 1 {
                        for dy in -1 ... 1 {
                            let v = tempBoard.cell[x+dx][y+dy]
                            if v != WALL { total += v; count += 1 }
                        }
                    }
                    
                    if count > 0 { currentBoard.cell[x][y] = total / count }
                }
            }
        }
    }
    
    // MARK:-
    
    var pathFound = Bool()
    
    func findEasiestPath() {
        var lowest:Int = 35000
        var newPosition = Position()
        
        func tryPath(_ pt:Position) {
            func tempValue(_ pt:Position) -> Int {
                if pt.isSame(endPosition) { return -100 }
                if pt.isSame(startPosition) { return WALL }
                
                let v = tempBoard.cell[pt.x][pt.y]
                if v == EMPTY { return WALL }
                return v
            }
            
            let v = tempValue(pt)
            if v < lowest {
                lowest = v
                newPosition = pt
            }
        }
        
        func addToPath(_ pt:Position) {
            if path.count >= XMAX * YMAX { fatalError("can't be right. path not found") }
            path.append(pt)
        }
        
        pathFound = false
        path.removeAll()
        
        for x in 0 ..< XMAX { for y in 0 ..< YMAX { tempBoard.cell[x][y] = EMPTY }}
        
        stack.removeAll()
        pushStack(endPosition,1)
        
        while true {
            processTopOfStack()
            if pathFound { break }
        }
        
        // start at beginning. move to neighboring cell with lowest value
        var currentPosition = startPosition
        var trial:Int = 0
        
        addToPath(currentPosition)
        
        while true {
            tryPath(currentPosition.offset(-1,-1))
            tryPath(currentPosition.offset( 0,-1))
            tryPath(currentPosition.offset(+1,-1))
            tryPath(currentPosition.offset(-1, 0))
            tryPath(currentPosition.offset(+1, 0))
            tryPath(currentPosition.offset(-1,+1))
            tryPath(currentPosition.offset( 0,+1))
            tryPath(currentPosition.offset(+1,+1))
            
            currentPosition = newPosition
            addToPath(currentPosition)
            
            if currentPosition.isSame(endPosition) { break }
            
            trial += 1
            if trial > MAX_STACK { break }
        }
    }
    
    // MARK:-
    
    func pushStack(_ pt:Position, _ value:Int) {  // insert at sorted index
        var i:Int = 0
        while i < stack.count && stack[i].value < value { i += 1 }
        
        stack.insert(StackData(pt,value), at:i)
    }
    
    func processTopOfStack() {
        func addToStackIfUnVisited(_ pt:Position, _ value:Int) {
            func isLegalposition(_ pt:Position) -> Bool { return pt.x >= 0 && pt.x < XMAX && pt.y >= 0 && pt.y < YMAX }
            
            if !isLegalposition(pt) { return }
            
            if !pathFound && (tempBoard.cell[pt.x][pt.y] == EMPTY) {
                let v = value + 1 + currentBoard.cell[pt.x][pt.y] - TERRAIN
                tempBoard.cell[pt.x][pt.y] = v
                pushStack(pt,v)
                
                if pt.isSame(startPosition) { pathFound = true }
            }
        }
        
        if stack.isEmpty {
            pathFound = true
            return
        }
        
        let position = stack[0].pt
        let value = stack[0].value
        
        stack.remove(at: 0)
        
        addToStackIfUnVisited(position.offset(-1,-1),value)
        addToStackIfUnVisited(position.offset( 0,-1),value)
        addToStackIfUnVisited(position.offset(+1,-1),value)
        addToStackIfUnVisited(position.offset(-1, 0),value)
        addToStackIfUnVisited(position.offset(+1, 0),value)
        addToStackIfUnVisited(position.offset(-1,+1),value)
        addToStackIfUnVisited(position.offset( 0,+1),value)
        addToStackIfUnVisited(position.offset(+1,+1),value)
    }
    
    // MARK:-
    
    func drawColoredCell(_ x:Int, _ y:Int, _ color:UIColor) {
        let pt = CGPoint(x:CGFloat(x) * cellSize.width, y:CGFloat(y) * cellSize.height)
        
        color.setFill()
        context.beginPath()
        context.addRect((CGRect(origin:pt, size:cellSize)))
        context.fillPath()
    }
    
    func drawCell(_ x:Int, _ y:Int) {
        var color = UIColor()
        
        if currentBoard.cell[x][y] == WALL {
            color = .brown
        }
        else {
            var v:CGFloat = 1.0 - CGFloat(currentBoard.cell[x][y] - TERRAIN) / CGFloat(MAX_HEIGHT)
            if v < 0 { v = 0 }
            color = UIColor.init(red:v, green:v, blue:v, alpha:1)
            
            if (x == startPosition.x && y == startPosition.y) || (x == endPosition.x && y == endPosition.y) {
                color = .blue
            }
            
            if illumination.cell[x][y] < MAX_ILLUMINATION {
                let ratio = CGFloat(illumination.cell[x][y]) / CGFloat(MAX_ILLUMINATION)
                var r:CGFloat = 0, g:CGFloat = 0, b:CGFloat = 0, a:CGFloat = 0
                color.getRed(&r, green: &g, blue: &b, alpha: &a)
                r *= ratio; if r < 0 { r = 0 }
                g *= ratio; if g < 0 { g = 0 }
                b *= ratio; if b < 0 { b = 0 }
                color = UIColor(red:r, green:g, blue:b, alpha: a)
            }
        }
    
        drawColoredCell(x,y,color)
    }
    
    override func draw(_ rect: CGRect) {
        context =  UIGraphicsGetCurrentContext()!
        
        for x in 0 ..< XMAX {
            for y in 0 ..< YMAX {
                drawCell(x,y)
            }
        }
        
        if path.count > 0 {
//            for p in path { drawColoredCell(p.x,p.y,.red) }
            let pt1 = path.first!;  drawColoredCell(pt1.x,pt1.y,.blue)
//            let pt2 = path.last!;   drawColoredCell(pt2.x,pt2.y,.blue)
        }
    }
    
    // MARK:-
    
    func alterTerrainCell(_ x:Int, _ y:Int, _ delta:Int) {
        func alterBaseBoardHeight(_ x:Int, _ y:Int, _ delta:Int) {
            if isLegalPosition(x,y) && baseBoard.cell[x][y] != WALL {
                var value = baseBoard.cell[x][y] + delta * 10
                
                if value < TERRAIN { value = TERRAIN } else
                    if value > TERRAIN + MAX_HEIGHT { value = TERRAIN + MAX_HEIGHT }
                
                baseBoard.cell[x][y] = value
            }
        }

        for m in -2 ... 2 {
            for n in -2 ... 2 {
                alterBaseBoardHeight(x+m,y+n,delta * 3)
            }
        }
    }

    var oldPt = Position(EMPTY,EMPTY)
    
    func setTerrainCellToWall(_ x:Int, _ y:Int) {
        while true {
            if isLegalPosition(oldPt.x,oldPt.y) { baseBoard.cell[oldPt.x][oldPt.y] = WALL }
            if oldPt.isSame(Position(x,y)) { break }
            
            let dx = x - oldPt.x
            let dy = y - oldPt.y
            if abs(dx) > abs(dy) { oldPt.x += dx > 0 ? 1 : -1 } else { oldPt.y += dy > 0 ? 1 : -1 }
        }
    }

    // MARK:-
    
    let MAX_ILLUMINATION:Int = 100
    
    func lineOfSight(_ pp1:Position,_ p2:Position) -> Bool {
        if pp1.isSame(p2) { return true }
        
        var p1 = pp1            // Bresenham
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        let absDx = abs(dx)
        let absDy = abs(dy)
        let ddx = dx > 0 ? +1 : -1
        let ddy = dy > 0 ? +1 : -1
        var total:Int = 0

        if absDx > absDy {  // X major
            while true {
                p1.x += ddx
                total += absDy
                if total >= absDx { total -= absDx;  p1.y += ddy }
                
                if baseBoard.cell[p1.x][p1.y] == WALL { return false }
                if p1.isSame(p2) { return true }
            }
        }
        else {  // Y major
            while true {
                p1.y += ddy
                total += absDx
                if total >= absDy { total -= absDy;  p1.x += ddx }
                
                if baseBoard.cell[p1.x][p1.y] == WALL { return false }
                if p1.isSame(p2) { return true }
            }
        }
    }
    
    // MARK:-

    func updateIllumination() {
        for x in 1 ..< XMAX-1 {
            for y in 1 ..< YMAX-1 {
                if baseBoard.cell[x][y] == WALL { continue }
                
                illumination.cell[x][y] = 0
                if lineOfSight(startPosition,Position(x,y)) {
                    let dist = hypotf(Float(startPosition.x - x), Float(startPosition.y - y))
                    illumination.cell[x][y] = Int(Float(100) - dist * 10)
                }
            }
        }
    }
    
    // MARK:-
    
    func moveTo(_ start:Position, _ dest:Position) -> Position {  // don't let them walk through walls
        if start.isSame(dest) { return dest }
        
        var start = start
        var lastPos = start
        while true {
            let dx = dest.x - start.x
            let dy = dest.y - start.y
            if abs(dx) > abs(dy) { start.x += dx > 0 ? 1 : -1 } else { start.y += dy > 0 ? 1 : -1 }
            if baseBoard.cell[start.x][start.y] == WALL { return lastPos }
            lastPos = start
            
            if start.isSame(dest) { return start }
        }
    }

    // MARK:-
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let pt = touch.location(in: self)
            
            let x = Int(pt.x / cellSize.width)
            let y = Int(pt.y / cellSize.height)
            if x == 0 || y == 0 || x == XMAX-1 || y == YMAX-1 { return }

            if oldPt.x == EMPTY { oldPt.x = x; oldPt.y = y }
            
            switch mode {
            case 1 : alterTerrainCell(x,y,-1)
            case 2 : alterTerrainCell(x,y,+1)
            case 3 :
                setTerrainCellToWall(x,y)
                updateIllumination()
                
            default :    // move
                let dStart = hypotf( Float(x - startPosition.x), Float(y - startPosition.y))
                let dEnd = hypotf( Float(x - endPosition.x), Float(y - endPosition.y))
                let destination = Position(x,y)
                if dStart < dEnd {
                    startPosition = moveTo(startPosition,destination)
                    updateIllumination()
                }
                else {
                    endPosition = moveTo(endPosition,destination)
                }
            }
            
            refresh(mode == 0)
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesBegan(touches, with:event)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if mode > 0 { refresh(true) }
        oldPt.x = EMPTY
    }
}

