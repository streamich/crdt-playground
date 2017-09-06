//
//  AppDelegate.swift
//  CRDTPlayground
//
//  Created by Alexei Baboulevitch on 2017-8-28.
//  Copyright © 2017 Alexei Baboulevitch. All rights reserved.
//

import Cocoa

struct TestStruct {
    var site: Int32
    var causingSite: Int32
    var index: Int64
    var causingIndex: Int64
    var value: UniChar
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    var randomArray = ContiguousArray<TestStruct>()
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        quickPerfCheck: do {
            let startCharCount = 500000
            let iterationCount = 1500
            
            print("Size of test struct: \(MemoryLayout<TestStruct>.size)")
            
            let characters: [UniChar] = ["a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z"].map {
                UnicodeScalar($0)!.utf16.first!
            }
            
            timeMe({
                for _ in 0..<startCharCount {
                    let val: UniChar = characters[Int(arc4random_uniform(UInt32(characters.count)))]
                    let aStruct = TestStruct(site: Int32(arc4random_uniform(8)), causingSite: Int32(arc4random_uniform(8)), index: Int64(arc4random_uniform(10000000)), causingIndex: Int64(arc4random_uniform(10000000)), value: val)
                    randomArray.append(aStruct)
                }
            }, "TestArrayGen")
            
            for _ in 0..<iterationCount {
                timeMe({
                    let randomIndex = Int(arc4random_uniform(UInt32(randomArray.count)))
                    let val: UniChar = characters[Int(arc4random_uniform(UInt32(characters.count)))]
                    let aStruct = TestStruct(site: Int32(arc4random_uniform(8)), causingSite: Int32(arc4random_uniform(8)), index: Int64(arc4random_uniform(10000000)), causingIndex: Int64(arc4random_uniform(10000000)), value: val)
                    randomArray.insert(aStruct, at: randomIndex)
                }, "TestArrayBenchmark", every: 200)
            }
            
            let testMap: [Int32:Int32] = [0:3,1:2,2:7,5:6,7:0]
            timeMe({
                for i in 0..<randomArray.count {
                    if let fromMap = testMap[randomArray[i].site] {
                        randomArray[i].site = fromMap
                    }
                    if let toMap = testMap[randomArray[i].causingSite] {
                        randomArray[i].causingSite = toMap
                    }
                }
            }, "TestArrayRewrite")
        }
    }
}

