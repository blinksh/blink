////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016-2019 Blink Mobile Shell Project
//
// This file is part of Blink.
//
// Blink is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Blink is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Blink. If not, see <http://www.gnu.org/licenses/>.
//
// In addition, Blink is also subject to certain additional terms under
// GNU GPL version 3 section 7.
//
// You should have received a copy of these additional terms immediately
// following the terms and conditions of the GNU General Public License
// which accompanied the Blink Source Code. If not, see
// <http://www.github.com/blinksh/blink>.
//
////////////////////////////////////////////////////////////////////////////////

import Foundation
import CoreMotion
import simd;
import SwiftUI


class ShakeDetector: ObservableObject {
  private let _m = CMMotionManager()
  private var _timer: Timer = Timer()
  private var _shakeHintCounter = 0;
  @Published var shakeHintIsOn: Bool = false
  
  private var _prevValue: SIMD3<Double>? = nil
  @Published var progress: Double = 0.3
  private var _doTrack = false
  
  init() {
    start()
  }
  
  deinit {
    stop()
  }
  
  func start() {
     let frequency = 1.0 / 60.0;
    _m.accelerometerUpdateInterval = frequency
    _m.startAccelerometerUpdates()
    
    _timer = Timer(
      fire: Date(),
      interval: frequency,
      repeats: true,
      block: { [weak self] _ in self?._onTimerTick() }
    )
    
    // Add the timer to the current run loop.
    RunLoop.current.add(_timer, forMode: .default)
  }
  
  func stop() {
    _timer.invalidate()
    _m.stopAccelerometerUpdates()
  }
  
  func startOver() {
    if progress == 0 {
      _doTrack = false
      progress = 0.3
    }
  }
  
  
  private func _onTimerTick() {
      var p = self.progress
      
      guard _doTrack
      else {
        if p > 0 {
          p -= 0.02
          if p <= 0 {
            p = 0
            _doTrack = true
          }
        }
        self.progress = p
        return
      }
      
      if let data = _m.accelerometerData {
        _processNewData(acc: data.acceleration)
      }
  }
  
  private func _processNewData(acc: CMAcceleration) {
    let a = SIMD3(acc.x, acc.y, acc.z);
    defer {
      _prevValue = a
    }
    
    guard let prev = _prevValue else {
      return;
    }

    let threshold = 1.0;
    
    var p = self.progress
    defer {
      self.progress = p
      if p >= 1 {
        SubscriptionNag.shared.restart()
      }
    }
    
    let d = distance(prev, a)
    if d > threshold {
      p += 0.003
    } else {
      p -= 0.001;
    }
    
    p = min(max(p, 0), 1.0)
    if p == 0 {
      _shakeHintCounter += 1;
    } else {
      _shakeHintCounter = 0;
    }
    
    if _shakeHintCounter == 0 {
      self.shakeHintIsOn = false
    }
    
    let i = _shakeHintCounter % 500
    
    if i == 60 * 2 {
      self.shakeHintIsOn = true
    }
    
    if i == 60 * 2 + 20 {
      self.shakeHintIsOn = false
    }
  }
}

