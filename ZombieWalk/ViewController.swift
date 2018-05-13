import UIKit

class ViewController: UIViewController {

    @IBOutlet var zombieView: ZombieView!
    @IBOutlet var SmoothingSider: UISlider!
    @IBOutlet var segmentControl: UISegmentedControl!
    
    @IBAction func smoothingSliderChanged(_ sender: UISlider) { zombieView.setSmoothAmount(sender.value) }
    @IBAction func resetButtonPressed(_ sender: Any) { zombieView.reset() }
    @IBAction func segmentChanged(_ sender: UISegmentedControl) {  zombieView.setMode(sender.selectedSegmentIndex) }
    
    override func viewDidLoad() {
        super.viewDidLoad()        
        zombieView.initialize()
    }
    
    override var prefersStatusBarHidden: Bool { return true }
}


