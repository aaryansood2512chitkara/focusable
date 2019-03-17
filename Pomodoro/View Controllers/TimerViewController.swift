//
//  ViewController.swift
//  Pomodoro
//
//  Created by Sonnie Hiles on 13/01/2019.
//  Copyright © 2019 Sonnie Hiles. All rights reserved.
//

import UIKit
import CoreData

class TimerViewController: UIViewController {

    enum SessionStates {
        case ready
        case paused
        case timing
    }

    let persistanceService: PersistanceService!
    let audioNotificationController: AudioNotificationService!
    let settingsController: SettingsViewController!
    let timerService: TimerService!
    var timeViewer: TimeViewer!
    var sessionStatus: SessionStates = .ready
    var subjects: [Subject] = []

    init(persistanceService: PersistanceService, audioNotificationController: AudioNotificationService, settingsController: SettingsViewController) {
        self.persistanceService = persistanceService
        self.audioNotificationController = audioNotificationController
        self.settingsController = settingsController
        self.timerService = TimerService(persistanceService: persistanceService, notificationService: NotificationService(), defaults: Defaults())
        
        super.init(nibName: nil, bundle: nil)
        timerService.timeTickerDelegate = self
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //Styling
        self.view.backgroundColor = .white
        
        //Adding skip button
        let skipButton = UIBarButtonItem(title: "Skip", style: .plain, target: self, action: #selector(self.skip))
        skipButton.isEnabled = false
        self.navigationItem.rightBarButtonItem = skipButton
        
        //Adding settings button
        let settingsButton = UIBarButtonItem(title: "Settings", style: .plain, target: self, action: #selector(self.pushSettings))
        settingsController.settingsDelegate = timerService
        self.navigationItem.leftBarButtonItem = settingsButton
        
        //Adding the time ticker
        timeViewer = TimeViewer(frame: .zero)
        self.view.addSubview(timeViewer)
        timeViewer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            timeViewer.leftAnchor.constraint(equalTo: self.view.leftAnchor, constant: 10),
            timeViewer.rightAnchor.constraint(equalTo: self.view.rightAnchor, constant: -10),
            timeViewer.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor, constant: 10),
            timeViewer.bottomAnchor.constraint(equalTo: self.view.centerYAnchor)])
        
        //Adding start/stop button
        self.view.addSubview(timeControllButtons)
        NSLayoutConstraint.activate([
            timeControllButtons.leftAnchor.constraint(equalTo: self.view.leftAnchor, constant: 10),
            timeControllButtons.rightAnchor.constraint(equalTo: self.view.rightAnchor, constant: -10),
            timeControllButtons.topAnchor.constraint(equalTo: self.view.centerYAnchor, constant: 10)])
        
        //Defualt values to show
        updateTimer(timeChunk: timerService.session![0])
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        self.navigationItem.title = "TIMER"
        
        //Getting Data
        self.subjects = persistanceService.fetchAllSubjects()
    }
    
    /**
     Updates the UI when a change occures within the session
     - Parameter timeChunk: The `TimeChunk` to display to calulate progress and display correct label.
     */
    func updateTimer(timeChunk: TimeChunk) -> Void {
        timeViewer.updateTimeViewer(timeChunk: timeChunk)
    }
    
    /**
     Skips the current time chunk and starts the next one
     */
    @objc func skip() -> Void {
        timerService.skipChunk()
    }
    
    /**
     Push into the settings controller.
     */
    @objc func pushSettings() -> Void {
        self.navigationController?.pushViewController(settingsController, animated: true)
    }
    
    /**
     Starts and stops the timer if the user needs an unexpected break
     */
    @objc func startStop() -> Void {
        switch sessionStatus {
        case .ready:
            let actionSession = UIAlertController(title: "Select Subject for Session", message: "Select the subject for the next session.", preferredStyle: .actionSheet)
            
            subjects.forEach { subject in
                actionSession.addAction(UIAlertAction(title: subject.name, style: .default, handler: { (a) in
                    Defaults().setSubject(subject.name!)
                    self.sessionStatus = .timing
                    self.timerService.startTimer()
                    self.startStopButton.setTitle("PAUSE", for: .normal)
                    
                    UIView.animate(withDuration: 0.10) { () -> Void in
                        self.timeControllButtons.arrangedSubviews[1].isHidden = false
                        self.navigationItem.rightBarButtonItem?.isEnabled = true
                    }
                }))
            }
            
            let title = subjects.isEmpty ? "Add Subject" : "Edit Subjects"
            actionSession.addAction(UIAlertAction(title: title, style: .default, handler: { (a) in
                self.navigationController?.pushViewController(SubjectManagementTable(persistanceService: self.persistanceService), animated: true)
            }))
            
            actionSession.addAction(UIAlertAction(title: "Close", style: .cancel, handler: nil))
            self.present(actionSession, animated: true, completion: nil)
        case .timing:
            sessionStatus = .paused
            timerService.stopTimer()
            startStopButton.setTitle("RESUME", for: .normal)
        case .paused:
            sessionStatus = .timing
            timerService.startTimer()
            startStopButton.setTitle("PAUSE", for: .normal)
        }
    }
    
    /**
     Resets the timer if the user wasnts to select another subject or end their current session
     */
    @objc private func reset() -> Void {
        timerService.resetSession()
        sessionFinished()
    }
    
    /**
     Resets the UI when either a session is reset or the session ends
     */
    private func sessionFinished() -> Void {
        sessionStatus = .ready
        startStopButton.setTitle("START", for: .normal)
        UIView.animate(withDuration: 0.10) { () -> Void in
            self.timeControllButtons.arrangedSubviews[1].isHidden = true
            self.navigationItem.rightBarButtonItem?.isEnabled = false
        }
    }
    
    lazy var startStopButton: UIButton = {
        let button = UIButton(frame: .zero)
        button.setTitle("START", for: .normal)
        button.addTarget(self, action: #selector(self.startStop), for: .touchUpInside)
        button.backgroundColor = .orange
        button.layer.cornerRadius = CGFloat(10.0)
        button.clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    lazy var resetButton: UIButton = {
        let button = UIButton(frame: .zero)
        button.setTitle("RESET", for: .normal)
        button.addTarget(self, action: #selector(self.reset), for: .touchUpInside)
        button.backgroundColor = .orange
        button.layer.cornerRadius = CGFloat(10.0)
        button.clipsToBounds = true
        button.isHidden = true
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    lazy var timeControllButtons: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [startStopButton, resetButton])
        stack.axis = .horizontal
        stack.alignment = .fill
        stack.spacing = 5.0
        stack.distribution = .fillProportionally
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
}

extension TimerViewController: TimeTickerDelegate {
    
    /**
    Updates the UI when a change occures within the session
     - Parameter timeChunk: The `TimeChunk` to display to calulate progress and display correct label.
     */
    func timerDecrement(timeChunk: TimeChunk){
        updateTimer(timeChunk: timeChunk)
    }
    
    /**
     Updates the UI when a change occures within the session
     - Parameter timeChunk: The `TimeChunk` to display to calulate progress and display correct label.
     */
    func resetTimerDisplay(timeChunk: TimeChunk) {
        updateTimer(timeChunk: timeChunk)
    }
    
    /**
     Resets the UI when either a session is reset or the session ends
     */
    func isFinished() {
        sessionFinished()
    }
    
    /**
     Handles when a chunk is completed by the notification sound
     */
    func chunkCompleted() {
        audioNotificationController.playNotificationSound()
    }
}
