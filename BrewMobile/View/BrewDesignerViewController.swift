//
//  BrewDesignerViewController.swift
//  BrewMobile
//
//  Created by Ágnes Vásárhelyi on 07/11/14.
//  Copyright (c) 2014 Ágnes Vásárhelyi. All rights reserved.
//

import UIKit
import ISO8601
import ReactiveCocoa

class BrewDesignerViewController : UIViewController, UITableViewDataSource, UITableViewDelegate, UIGestureRecognizerDelegate {

    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var startTimeTextField: UITextField!
    @IBOutlet weak var phasesTableView: UITableView!
    @IBOutlet weak var startTimePicker: UIDatePicker!
    @IBOutlet weak var pickerBgView: UIView!
    @IBOutlet weak var editButton: UIButton!
    @IBOutlet weak var syncButton: UIButton!
    @IBOutlet weak var trashButton: UIButton!
    @IBOutlet weak var addButton: UIButton!
    @IBOutlet weak var tapGestureRecognizer: UITapGestureRecognizer!

    let brewDesignerViewModel: BrewDesignerViewModel
    let brewManager: BrewManager
    var cocoaActionTrash: CocoaAction!

    init(brewDesignerViewModel: BrewDesignerViewModel) {
        self.brewDesignerViewModel = brewDesignerViewModel
        self.brewManager = brewDesignerViewModel.brewManager
        
        super.init(nibName:"BrewDesignerViewController", bundle: nil)
        self.tabBarItem = UITabBarItem(title: "Designer", image: UIImage(named: "DesignerIcon"), tag: 0)
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let nib = UINib(nibName: "PhaseCell", bundle: nil)
        phasesTableView.registerNib(nib, forCellReuseIdentifier: "PhaseCell")
        
//        editButton.rac_command = RACCommand(enabled: self.brewDesignerViewModel.hasPhasesSignal) {
//            (any:AnyObject!) -> RACSignal in
//            self.phasesTableView.editing = !self.phasesTableView.editing
//            return RACSignal.empty()
//        }

        let trashAction = Action<Void, Void, NSError>(enabledIf: self.brewDesignerViewModel.hasPhasesProperty, {
            self.brewDesignerViewModel.phases = PhaseArray()
            self.nameTextField.text = ""
            self.phasesTableView.reloadData()
            
            return SignalProducer.empty
        })
        
        cocoaActionTrash = CocoaAction(trashAction, input: ())
        
        syncButton.addTarget(self.brewDesignerViewModel.cocoaActionSync, action:CocoaAction.selector, forControlEvents: .TouchUpInside)
        trashButton.addTarget(cocoaActionTrash, action: CocoaAction.selector, forControlEvents: .TouchUpInside)
     
        self.brewManager.syncBrewAction.errors
            |> observeOn(UIScheduler())
            |> observe(next: { error in
                UIAlertView(title: "Error creating brew", message: error.localizedDescription, delegate: nil, cancelButtonTitle: "OK").show()
            })
        
        addButton.rac_command = RACCommand() {
            (any:AnyObject!) -> RACSignal in
            self.navigationController?.pushViewController(BrewNewPhaseViewController(brewDesignerViewModel: self.brewDesignerViewModel), animated: true)
            return RACSignal.empty()
        }

//        self.brewDesignerViewModel.hasPhasesSignal.subscribeNext {
//            (next: AnyObject!) -> () in
//
//            if !self.phasesTableView.editing {
//                self.phasesTableView.reloadData()
//            }
//
//            if !(next as! Bool) {
//                self.phasesTableView.editing = false
//            }
//        }

        RACObserve(self.phasesTableView, "editing").subscribeNext {
            (editing: AnyObject!) -> Void in
            let editingValue = editing as! Bool
            self.editButton.setTitle(editingValue ? "Done" : "Edit", forState: .Normal)
        }

        self.brewDesignerViewModel.nameProperty <~ self.nameTextField.rac_textSignalProducer()

        let startTimeTextFieldProducer = self.startTimeTextField.rac_signalForControlEvents(.EditingDidBegin).toSignalProducer()
        startTimeTextFieldProducer
            |> map { picker in
                let datePicker = picker as! UITextField
                return datePicker.text
            }
            |> catch { _ in SignalProducer<String, NoError>.empty }
        
        startTimeTextFieldProducer.start(next: { _ in
            self.dismissKeyboards()
        })
    
        self.pickerBgView.rac_hidden <~ startTimeTextFieldProducer
            |> map { _ in return false }
            |> catch { _ in SignalProducer<Bool, NoError>.empty }

        let pickerDateProducer = self.startTimePicker.rac_signalForControlEvents(.ValueChanged).toSignalProducer()
            |> map { picker in
                let datePicker = picker as! UIDatePicker
                return datePicker.date
            }
            |> catch { _ in SignalProducer<NSDate, NoError>.empty }
        
        pickerDateProducer.start(next: { _ in
            self.dismissKeyboards()
        })

        self.startTimeTextField.rac_text <~ pickerDateProducer
            |> map { date in
                let dateFormatter = NSDateFormatter()
                dateFormatter.dateFormat = "YYYY.MM.dd. HH:mm"
                return dateFormatter.stringFromDate(date as NSDate)
            }
            |> catch { _ in SignalProducer<String, NoError>.empty }

        self.brewDesignerViewModel.startTimeProperty <~ pickerDateProducer
            |> map { date in
                let isoDateFormatter = ISO8601DateFormatter()
                isoDateFormatter.defaultTimeZone = NSTimeZone.defaultTimeZone()
                isoDateFormatter.includeTime = true
                
                return isoDateFormatter.stringFromDate(date)
            }
            |> catch { _ in SignalProducer<String, NoError>.empty }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    func dismissKeyboards() {
        self.view.endEditing(true)
        self.pickerBgView.hidden = true
    }

    // MARK: UITableViewDataSource
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.brewDesignerViewModel.phases.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("PhaseCell", forIndexPath: indexPath) as! PhaseCell
        if self.brewDesignerViewModel.phases.count > indexPath.row  {
            let phase = self.brewDesignerViewModel.phases[indexPath.row]
            cell.phaseLabel.text = "\(indexPath.row + 1). \(phase.min) min \(phase.temp) ˚C"
        }
        
        return cell
    }
    
    func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Phases"
    }
    
    func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
    
    func tableView(tableView: UITableView, canMoveRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
    
    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == UITableViewCellEditingStyle.Delete {
            if self.brewDesignerViewModel.phases.count > indexPath.row {
                var newPhases = self.brewDesignerViewModel.phases
                newPhases.removeAtIndex(indexPath.row)
                self.brewDesignerViewModel.setValue(newPhases, forKeyPath: "phases")
                tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.Automatic)
            }
        }
    }
    
    func tableView(tableView: UITableView, moveRowAtIndexPath sourceIndexPath: NSIndexPath, toIndexPath destinationIndexPath: NSIndexPath) {
        let destinationPhase = self.brewDesignerViewModel.phases[destinationIndexPath.row]

        var newPhases = self.brewDesignerViewModel.phases
        newPhases[destinationIndexPath.row] = newPhases[sourceIndexPath.row]
        newPhases[sourceIndexPath.row] = destinationPhase
        self.brewDesignerViewModel.setValue(newPhases, forKeyPath: "phases")
        tableView.reloadData()
    }
    
    //MARK: UIGestureRecognizerDelegate

    func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldReceiveTouch touch: UITouch) -> Bool {
        if !touch.view.isDescendantOfView(nameTextField) && !touch.view.isDescendantOfView(pickerBgView) {
            dismissKeyboards()
            return false
        }
        return true
    }
    
}
