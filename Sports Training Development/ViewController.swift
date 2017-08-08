//  ViewController.swift
//  AudioDash

//  Created by Cluster 5 Group 3 on 7/23/17.
//  Copyright © 2017 Cluster 5 Group 3. All rights reserved.

import UIKit
import AVFoundation
import CoreMotion

struct defaultKeys {
    static let keyOne = "Highest Accuracy = --"
    static let keyTwo = "Highest Points = --"
}

class ViewController: UIViewController {
    
    @IBOutlet weak var startButtonReceiver: UIButton!
    @IBOutlet weak var difficultyLabel: UILabel!
    @IBOutlet weak var difficultySelectorReceiver: UISegmentedControl!
    @IBOutlet weak var backgroundNoiseLabel: UILabel!
    @IBOutlet weak var backgroundSliderReceiver: UISlider!
    @IBOutlet weak var soundLabel: UILabel!
    @IBOutlet weak var testingSwitchOutlet: UISwitch!   //  "practice mode"
    @IBOutlet weak var accuracyLabel: UILabel!
    @IBOutlet weak var pointsLabel: UILabel!
    @IBOutlet weak var soundSelectorReceiver: UISegmentedControl!
    
    @IBOutlet weak var highPointLabel: UILabel!
    @IBOutlet weak var highScoreLabel: UILabel!
    
    var instructionsAlert: UIAlertController!
    let titleText: String = "Instructions"
    let messageText: String = "1. Choose the difficulty, background noise levels, and sound type.\n2. Choose between normal or practice mode.\n3. Hold device so that screen faces up and is parallel to the ground.\n4. Press \"Start\" and wait for the countdown.\n5. When a beep is played, rotate your body so that the top of the device faces the direction of the sound.\n6. Press Stop to receive your score and accuracy."
    
    var highScoreAlert: UIAlertController!
    var highAccuracyAlert: UIAlertController!
    
    var isOn: Bool = false
    var timeBetweenBeeps: Double = 6.0   //  App starts with Easy
    var gameTimer: Timer!
    var backgroundNoiseTimer: Timer!
    var backgroundNoiseVolume: Float = 0    //  App starts with no background noise
    var selectedSound: Int = 0  //  App starts with buzzer
    var isFirstTime = true
    var lastUserAngle: Float = 0
    var lastRandAngle: Float = 0
    var points = 0
    var d = [String: Float]()
    var yaw: Float = 0.0
    var timesGone = 0
    var testingOn: Bool = false
    var lastUserYaw = 0.0
    var currUserYaw = 0.0
    var highScore : Int?
    var highScoreText : String?
    var highPoint : Int?
    var highPointText : String?
    
    let defaults = UserDefaults.standard
    
    let PI: Float = 3.14159265359
    var countdown: AVAudioPlayer! = nil
    var bg: AVAudioPlayer! = nil
    let beepFileURL = Bundle.main.url(forResource: "buzzer", withExtension: "wav")
    let ringFileURL = Bundle.main.url(forResource: "ring", withExtension: "wav")
    let fluteFileURL = Bundle.main.url(forResource: "flute", withExtension: "wav")
    let humFileURL = Bundle.main.url(forResource: "hum", withExtension: "wav")
    let bounceFileURL = Bundle.main.url(forResource: "bounce", withExtension: "wav")
    let countdownFileURL = Bundle.main.url(forResource:"321", withExtension:"wav")
    let bgFileURL = Bundle.main.url(forResource:"backgroundCheers", withExtension:"wav")
    var engine: AVAudioEngine!
    var beep:  AVAudioFile! //  beep variable loaded into buffer
    var buffer: AVAudioPCMBuffer!
    var player:  AVAudioPlayerNode!
    var output: AVAudioOutputNode!
    var mixer: AVAudioMixerNode!
    var mixer3d: AVAudioEnvironmentNode!
    var motionManager: CMMotionManager!
    
    override func viewDidAppear(_ animated: Bool) {
        present(instructionsAlert, animated: true, completion: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        highScoreText = defaults.string(forKey: defaultKeys.keyOne)
        highScoreLabel.text = highScoreText
        highPointText = defaults.string(forKey: defaultKeys.keyTwo)
        highPointLabel.text = highPointText
        
        instructionsAlert = UIAlertController(title: titleText, message: messageText, preferredStyle: .alert)
        let defaultAction = UIAlertAction(title: "OK", style: .default) { (action: UIAlertAction) in
            print("alert worked")
        }
        instructionsAlert.addAction(defaultAction)
        
        do {
            beep = try AVAudioFile(forReading: beepFileURL!)
            print("loaded beep")
        }
        catch {
            print("Cannot load audiofile beep!")
        }
        let audioFormat = beep.processingFormat
        let audioFrameCount = UInt32(beep.length)
        buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: audioFrameCount)
        do {
            try beep.read(into: buffer, frameCount: audioFrameCount)
            print("File loaded")
        }
        catch{
            print("Could not load file into buffer")
        }
        
        initEngine()
        
        do{
            try countdown = AVAudioPlayer(contentsOf:countdownFileURL!)
        }catch{
            print("Couldn't load file")
        }
        countdown.volume = 1
        countdown.numberOfLoops = 0 //-1 means loops forever
        
        do{
            try bg = AVAudioPlayer(contentsOf:bgFileURL!)
        }catch{
            print("Couldn't load file")
        }
        bg.volume = 1
        bg.numberOfLoops = 0 //-1 means loops forever
        
        motionManager = CMMotionManager()
        motionManager.deviceMotionUpdateInterval = 0.1
        motionManager.gyroUpdateInterval = 0.1
        motionManager.startDeviceMotionUpdates(using: CMAttitudeReferenceFrame.xTrueNorthZVertical, to: OperationQueue.main) {
            (motion: CMDeviceMotion?, _) in
            if let attitude: CMAttitude = motion?.attitude {
                self.yaw = Float(attitude.yaw)
                if(self.isOn){
                    var currUserDeg1 = (self.yaw*180.0)/self.PI; // conversion to degrees
                    if( currUserDeg1 < 0 ){
                        currUserDeg1 += 360.0
                    }
                    let angleDiff = (((currUserDeg1 - Float(self.lastUserYaw)) + 180.0 + 360.0).truncatingRemainder(dividingBy: 360.0)) - 180.0
                    self.mixer3d.listenerAngularOrientation.yaw = self.mixer3d.listenerAngularOrientation.yaw - (angleDiff)
                    self.lastUserYaw = Double(currUserDeg1)
                }else{
                    self.lastUserYaw = 0
                }
            }
        }
        
        startButtonReceiver.backgroundColor = UIColor(red: 0.33, green: 0.46, blue: 0.31, alpha: 1.0)   //  color
        difficultyLabel.layer.zPosition = -1
        backgroundNoiseLabel.layer.zPosition = -1
        backgroundSliderReceiver.setValue(Float(0), animated: false)
        soundLabel.layer.zPosition = -1
    }
    
    func initEngine(){
        engine = AVAudioEngine()
        player = AVAudioPlayerNode()
        mixer3d = AVAudioEnvironmentNode()
        
        initPositions()
        
        mixer = engine.mainMixerNode
        engine.attach(player)
        engine.attach(mixer3d)
        player.renderingAlgorithm = AVAudio3DMixingRenderingAlgorithm(rawValue: 2)!
        engine.connect(player, to: mixer3d, format: beep.processingFormat)
        engine.connect(mixer3d, to: mixer, format: mixer3d.outputFormat(forBus: 0))
        
        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        do {
            try engine.start()
        }
        catch {
            print("Cannot initialize engine")
        }
    }
    
    func initPositions(){
        mixer3d.listenerPosition.x = 1
        mixer3d.listenerPosition.y = 1
        mixer3d.listenerPosition.z = 5
        
        player.position.x = 0
        player.position.y = 0
        player.position.z = 0
    }
    
    @IBAction func onOffButton(_ sender: UIButton) {
        isOn = !isOn
        if isOn {
            if(!testingOn){
                points = 0
                timesGone = 0
                pointsLabel.text = "Points: \(points)"
                accuracyLabel.text = "Accuracy: --"
            }
            
            sender.isEnabled = false
            sender.backgroundColor = UIColor(red: 0.52, green: 0.45, blue: 0.45, alpha: 1.0)   //  color
            sender.setTitle("Counting Down", for: .normal)
            
            backgroundSliderReceiver.isEnabled = false
            difficultySelectorReceiver.isEnabled = false
            soundSelectorReceiver.isEnabled = false
            testingSwitchOutlet.isEnabled = false
            
            countdown.play()
            
            let when = DispatchTime.now() + 3.5 //  length of countdown
            DispatchQueue.main.asyncAfter(deadline: when){
                self.mainLoop()
                self.backgroundSounds()
                
                //  Off button re-enabled
                sender.isEnabled = true
                sender.backgroundColor = UIColor(red: 0.55, green: 0.43, blue: 0.54, alpha: 1.0)   //  color
                sender.setTitle("Stop", for: .normal)
                
                self.gameTimer = Timer.scheduledTimer(timeInterval: self.timeBetweenBeeps, target: self, selector: #selector(self.mainLoop), userInfo: nil, repeats: true)
                self.bg.volume = self.backgroundNoiseVolume
                self.backgroundNoiseTimer = Timer.scheduledTimer(timeInterval: 0, target: self, selector: #selector(self.backgroundSounds), userInfo: nil, repeats: true)
            }
        } else {
            sender.backgroundColor = UIColor(red: 0.33, green: 0.46, blue: 0.31, alpha: 1.0)  // color
            sender.setTitle("Start", for: .normal)
            difficultySelectorReceiver.isEnabled = true
            backgroundSliderReceiver.isEnabled = true
            soundSelectorReceiver.isEnabled = true
            testingSwitchOutlet.isEnabled = true
            countdown.stop()
            player.stop()
            bg.stop()
            gameTimer.invalidate()
            backgroundNoiseTimer.invalidate()
            if(!testingOn && (timesGone != 0)){
                let accuracy = Int(Double(((Float(points)/10.0)/Float(timesGone))*100).rounded())
                accuracyLabel.text = "Accuracy: \(accuracy)%"
                if (self.highPoint == nil || self.points > self.highPoint! ) {
                    self.highPoint = self.points
                    self.defaults.setValue("Highest Points = \(self.points)", forKey: defaultKeys.keyTwo)
                    self.defaults.synchronize()
                    self.highPointText = self.defaults.string(forKey: defaultKeys.keyTwo)
                    self.highPointLabel.text = self.highPointText
                    
                    self.highScoreAlert = UIAlertController(title: "New Highest Points", message: "\(self.points)", preferredStyle: .alert)
                    let highPointAction = UIAlertAction(title: "OK", style: .default) { (action: UIAlertAction) in
                        print("new high points")
                        
                        if (self.highScore == nil || accuracy > self.highScore! ) {
                            self.highScore = accuracy
                            self.defaults.setValue("Highest Accuracy = \(accuracy)%", forKey: defaultKeys.keyOne)
                            self.defaults.synchronize()
                            self.highScoreText = self.defaults.string(forKey: defaultKeys.keyOne)
                            self.highScoreLabel.text = self.highScoreText
                            
                            self.highAccuracyAlert = UIAlertController(title: "New Highest Accuracy", message: "\(accuracy)%", preferredStyle: .alert)
                            let highAccuracyAction = UIAlertAction(title: "OK", style: .default) { (action: UIAlertAction) in
                                print("new high accuracy")
                            }
                            self.highAccuracyAlert.addAction(highAccuracyAction)
                            self.present(self.highAccuracyAlert, animated: true, completion: nil)
                        }
                    }
                    self.highScoreAlert.addAction(highPointAction)
                    self.present(self.highScoreAlert, animated: true, completion: nil)
                }else{
                    if (highScore == nil || accuracy > highScore! ) {
                        highScore = accuracy
                        defaults.setValue("Highest Accuracy = \(accuracy)%", forKey: defaultKeys.keyOne)
                        defaults.synchronize()
                        highScoreText = defaults.string(forKey: defaultKeys.keyOne)
                        highScoreLabel.text = highScoreText
                        
                        highAccuracyAlert = UIAlertController(title: "New Highest Accuracy", message: "\(accuracy)%", preferredStyle: .alert)
                        let highAccuracyAction = UIAlertAction(title: "OK", style: .default) { (action: UIAlertAction) in
                            print("new high accuracy")
                        }
                        highAccuracyAlert.addAction(highAccuracyAction)
                        present(highAccuracyAlert, animated: true, completion: nil)
                    }
                }
            }
        }
    }
    
    func mainLoop() {
        if(!isFirstTime){
            if(!testingOn){
                var currUserDeg = (yaw*180.0)/self.PI; // conversion to degrees
                if( currUserDeg < 0 ){
                    currUserDeg += 360.0
                }
                var goalAngle = lastRandAngle + lastUserAngle
                if(goalAngle > 360.0){
                    goalAngle -= 360.0
                }
                let angleDiff = (((currUserDeg - goalAngle) + 180.0 + 360.0).truncatingRemainder(dividingBy: 360.0)) - 180.0
                
                if ((angleDiff <= 45.0) && (angleDiff >= -45.0)){
                    points += 10
                    pointsLabel.text = "Points: \(points)"
                }
                timesGone += 1
                print("Generated Angle: \(mixer3d.listenerAngularOrientation.yaw), User's Angle: \(currUserDeg), Goal Angle: \(goalAngle), Points: \(points)")
                lastUserAngle = currUserDeg
            }
            let newRandAngle = Float(arc4random_uniform(UInt32(8)))*45.0
            mixer3d.listenerAngularOrientation.yaw = newRandAngle
            lastRandAngle = newRandAngle
            player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
            player.play()
        }else{
            isFirstTime = false
            let newRandAngle = Float(arc4random_uniform(UInt32(8)))*45.0
            mixer3d.listenerAngularOrientation.yaw = newRandAngle
            lastRandAngle = newRandAngle
            if(!testingOn){
                var currUserDeg = (yaw*180.0)/self.PI; // conversion to degrees
                if( currUserDeg < 0 ){
                    currUserDeg += 360.0
                }
                lastUserAngle = currUserDeg
            }
            player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
            player.play()
        }
    }
    
    func backgroundSounds() {
        bg.play()
    }
    
    @IBAction func testingSwitch(_ sender: UISwitch) {
        testingOn = !testingOn
        if(testingOn){
            pointsLabel.text = "Practice Mode"
            accuracyLabel.text = "(No Scoring)"
        }else{
            points = 0
            timesGone = 0
            pointsLabel.text = "Points: \(points)"
            accuracyLabel.text = "Accuracy: --"
        }
    }
    
    @IBAction func difficultySelector(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            timeBetweenBeeps = 6.0
        case 1:
            timeBetweenBeeps = 4.0
        case 2:
            timeBetweenBeeps = 2.0
        default:
            timeBetweenBeeps = 4.0
        }
    }
    
    @IBAction func backgroundSlider(_ sender: UISlider) {
        backgroundNoiseVolume = sender.value
    }
    
    @IBAction func soundSelector(_ sender: UISegmentedControl) {
        selectedSound = sender.selectedSegmentIndex
        
        do {
            switch selectedSound {
            case 0:
                beep = try AVAudioFile(forReading: beepFileURL!)
                print("beep success")
            case 1:
                beep = try AVAudioFile(forReading: ringFileURL!)
                print("ring success")
            case 2:
                beep = try AVAudioFile(forReading: fluteFileURL!)
                print("flute success")
            case 3:
                beep = try AVAudioFile(forReading: humFileURL!)
                print("hum success")
            case 4:
                beep = try AVAudioFile(forReading: bounceFileURL!)
                print("bounce success")
            default:
                print("selectedSound failed")
            }
        }
        catch {
            print("Cannot load audiofile beep!")
        }
        
        let audioFormat = beep.processingFormat
        let audioFrameCount = UInt32(beep.length)
        buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: audioFrameCount)
        do {
            try beep.read(into: buffer, frameCount: audioFrameCount)
            print("beep loaded")
        }
        catch{
            print("Could not load beep into buffer")
        }
    }
    
    @IBAction func resetScores(_ sender: UIButton) {
        self.defaults.setValue("Highest Points = --", forKey: defaultKeys.keyTwo)
        self.defaults.synchronize()
        self.highPointText = self.defaults.string(forKey: defaultKeys.keyTwo)
        self.highPointLabel.text = self.highPointText
        self.highPoint = 0
        
        self.defaults.setValue("Highest Accuracy = --", forKey: defaultKeys.keyOne)
        self.defaults.synchronize()
        self.highScoreText = self.defaults.string(forKey: defaultKeys.keyOne)
        self.highScoreLabel.text = self.highScoreText
        self.highScore = 0
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
}

