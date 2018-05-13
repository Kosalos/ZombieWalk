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
let EDGE:Int = 30001

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

var startPosition = Position()
var endPosition = Position()
var smoothAmount = Int()

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
    
    func reset() {
        startPosition = Position(2,2)
        endPosition = Position(XMAX-3,YMAX-3)
        
        for x in 0 ..< XMAX {
            for y in 0 ..< YMAX {
                baseBoard.cell[x][y] = TERRAIN
            }
        }
        
        func setbaseBoardHeight(_ x:Int, _ y:Int, _ value:Int) {
            if x >= 0 && x < XMAX && y >= 0 && y < YMAX {
                baseBoard.cell[x][y] = value
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
        
        refresh()
    }
    
    // MARK:-
    
    func refresh() {
        applySmooth()
        findEasiestPath()
        setNeedsDisplay()
    }
    
    func setSmoothAmount(_ ratio:Float) {
        smoothAmount = Int(ratio * 10)
        refresh()
    }
    
    func applySmooth() {
        currentBoard = baseBoard
        
        for _ in 0 ..< smoothAmount {
            tempBoard = currentBoard
            
            for x in 1 ..< XMAX - 1 {
                for y in 1 ..< YMAX - 1 {
                    currentBoard.cell[x][y] = (
                        tempBoard.cell[x-1][y-1] + tempBoard.cell[x][y-1] + tempBoard.cell[x+1][y-1] +
                            tempBoard.cell[x-1][y  ] + tempBoard.cell[x][y  ] + tempBoard.cell[x+1][y  ] +
                            tempBoard.cell[x-1][y+1] + tempBoard.cell[x][y+1] + tempBoard.cell[x+1][y+1] ) / 9
                }
            }
        }
        
        for x in 0 ..< XMAX {
            currentBoard.cell[x][0] = EDGE
            currentBoard.cell[x][YMAX-1] = EDGE
        }
        
        for y in 0 ..< YMAX {
            currentBoard.cell[0][y] = EDGE
            currentBoard.cell[XMAX-1][y] = EDGE
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
                if pt.isSame(startPosition) { return EDGE }
                
                let v = tempBoard.cell[pt.x][pt.y]
                if v == EMPTY { return EDGE }
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
        
        if currentBoard.cell[x][y] == EDGE {
            color = .green
        }
        else {
            let v:CGFloat = 1.0 - CGFloat(currentBoard.cell[x][y] - TERRAIN) / CGFloat(MAX_HEIGHT)
            color = UIColor.init(red:v, green:v, blue:v, alpha:1)
            
            if (x == startPosition.x && y == startPosition.y) || (x == endPosition.x && y == endPosition.y) {
                color = .blue
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
            for p in path { drawColoredCell(p.x,p.y,.red) }
            let pt1 = path.first!;  drawColoredCell(pt1.x,pt1.y,.blue)
            let pt2 = path.last!;   drawColoredCell(pt2.x,pt2.y,.blue)
        }
    }
    
    // MARK:-
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let pt = touch.location(in: self)
            
            let x = Int(pt.x / cellSize.width)
            let y = Int(pt.y / cellSize.height)
            if x == 0 || y == 0 || x == XMAX-1 || y == YMAX-1 { return }
            
            let dStart = hypotf( Float(x - startPosition.x), Float(y - startPosition.y))
            let dEnd = hypotf( Float(x - endPosition.x), Float(y - endPosition.y))
            
            if dStart < dEnd {
                startPosition.x = x
                startPosition.y = y
            }
            else {
                endPosition.x = x
                endPosition.y = y
            }
            
            refresh()
        }
    }
}

