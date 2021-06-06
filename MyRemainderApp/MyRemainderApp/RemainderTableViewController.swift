//
//  ViewController.swift
//  MyRemainderApp
//
//  Created by systimanx on 03/06/21.
//

import UIKit
import UserNotifications
import CoreData

class RemainderTableViewController: UIViewController {

    @IBOutlet weak var reminderTableView: UITableView!
    
    let remainderCellId = "RemainderCellId"
    
    var remainders: [RemainderMessage] = []
    var datePicker: UIDatePicker = UIDatePicker()
    var dateTextField: UITextField?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        { granted, error in
            if granted {
                print("!!!!!!!!!!!")
            } else if let error = error {
                print(error.localizedDescription)
            }
            
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard let appdelegate =  UIApplication.shared.delegate as? AppDelegate else {
            return
        }
        let managedContext = appdelegate.persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "RemainderMessage")
        remainders = try! managedContext.fetch(fetchRequest) as! [RemainderMessage]
    }
    
    @IBAction func addNewReminderAction(_ sender: Any) {
        
        let alertController = UIAlertController(title: "Reminder", message: nil, preferredStyle: .alert)
        alertController.addTextField(configurationHandler: {(textField) in
            textField.placeholder = "Message to be reminded about"
        })
        alertController.addTextField(configurationHandler: {(textField) in
            self.configureDatePickerFor(textField: textField)
        })
        
        let save = UIAlertAction(title: "Save", style: .default){ action in
            
            guard let textField = alertController.textFields?.first,
                  let reminderText = textField.text else {
                return
            }
            self.save(text: reminderText, date: self.datePicker.date)
        }
        let cancel = UIAlertAction(title: "Cancel", style: .cancel)
        
        alertController.addAction(save)
        alertController.addAction(cancel)
        present(alertController, animated: true,completion: nil)
        
    }
    
    func configureDatePickerFor(textField: UITextField) {
        
        textField.placeholder = "Date & Time"
        textField.inputView = self.datePicker
        dateTextField = textField
        datePicker.datePickerMode = .dateAndTime
        datePicker.timeZone = NSTimeZone.local
        datePicker.addTarget(self, action: #selector(dateChanged(_:)), for: .valueChanged)
        if #available(iOS 12.4, *) {
            datePicker.preferredDatePickerStyle = .wheels
        }
    }
    
    @objc func dateChanged(_ sender: UIDatePicker) {
        
        print(sender.date)
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        dateTextField?.text = sender.date.toString()
    }
    
    func save(text: String, date: Date) {
        
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            return
        }
        
        let managedContext = appDelegate.persistentContainer.viewContext
        
        let entity = NSEntityDescription.entity(forEntityName: "RemainderMessage",
                                                in: managedContext)
        
        let message = NSManagedObject(entity: entity!, insertInto: managedContext) as! RemainderMessage
        
        message.text = text
        message.date = date
        do {
            try managedContext.save()
            remainders.append(message)
            reminderTableView.reloadData()
        } catch let error as NSError {
            print("Could not save. \(error), \(error.userInfo)")
        }
        let content = UNMutableNotificationContent()
        content.title = "Remainder"
        content.subtitle = text
        content.sound = UNNotificationSound.default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
    
    func update(remainder: RemainderMessage) {
        
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            return
        }
        let managedContext = appDelegate.persistentContainer.viewContext
        try? managedContext.save()
        reminderTableView.reloadData()
        if let reminderText = remainder.text, let date = remainder.date {
            let content = UNMutableNotificationContent()
            content.title = "Remainder"
            content.subtitle = reminderText
            content.sound = UNNotificationSound.default
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let  request = UNNotificationRequest(identifier: date.description, content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request)
        }
        
    }
    
    func edit(at: Int) {
        
        let remainder = remainders[at]
        let alertController = UIAlertController(title: "Reminder", message: nil, preferredStyle: .alert)
        alertController.addTextField(configurationHandler: {(textField) in
            textField.text = remainder.text
            textField.placeholder = "Message to be reminded about"
        })
        alertController.addTextField(configurationHandler: {(textField) in
            textField.text = remainder.date?.toString()
            self.configureDatePickerFor(textField: textField)
        })
        
        let save = UIAlertAction(title: "Update", style: .default){ action in
            
            guard let textField = alertController.textFields?.first,
                  let text = textField.text else {
                return
            }
            if let identifier = remainder.date?.description {
                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [identifier])
            }
            remainder.text = text
            remainder.date = self.datePicker.date
            self.update(remainder: remainder)
        }
        let cancel = UIAlertAction(title: "Cancel", style: .cancel)
        
        alertController.addAction(save)
        alertController.addAction(cancel)
        present(alertController, animated: true,completion: nil)
        
    }
    
    func delete(at: Int) {
        
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            return
        }
        
        let managedContext = appDelegate.persistentContainer.viewContext
        let remainder = remainders[at]
        managedContext.delete(remainder)
        try? managedContext.save()
        remainders.remove(at: at)
        reminderTableView.reloadData()
        if let identifier = remainder.date?.description {
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [identifier])
        }
    }
}

extension RemainderTableViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return remainders.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: remainderCellId, for: indexPath)
        let reminder = remainders[indexPath.row]
        cell.textLabel?.text = reminder.text
        cell.textLabel?.font = UIFont(name: "Arial", size: 23)
        cell.detailTextLabel?.text = reminder.date?.toString()
        cell.detailTextLabel?.font = UIFont(name: "Arial", size: 20)
        return cell
    }
}

extension RemainderTableViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        alertController.addAction(UIAlertAction(title: "Edit", style: .default , handler:{ (action) in
            self.edit(at: indexPath.row)
        }))
        
        alertController.addAction(UIAlertAction(title: "Delete", style: .destructive , handler:{ (action) in
            self.delete(at: indexPath.row)
        }))
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler:{ (action) in
        }))
        
        self.present(alertController, animated: true, completion: nil)
    }
}

extension Date {
    
    func toString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy hh:mm a"
        let toString = formatter.string(from: self)
        return toString
    }
}


//let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
//let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
//let request = UNNotificationRequest(identifier: date.description, content: content, trigger: trigger)
