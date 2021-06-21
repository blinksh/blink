//////////////////////////////////////////////////////////////////////////////////
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


import Intents
import Machines
import Promise


fileprivate let url = "https://api-staging.blink.build";

fileprivate let auth0 = Auth0(config: .init(
  clientId: "x7RQ8NR862VscbotFSfu2VO7PEj55ExK",
  domain: "dev-i8bp-l6b.us.auth0.com",
  scope: "offline_access+openid+profile+read:build+write:build",
  audience: "blink.build"
))

fileprivate let tokenProvider = AuthTokenProvider(
  auth0: auth0,
  storage: UserDefaultsTokenStorage(ud: .suite, tokenKey: "machinesToken")
)

func machine() -> Machines.Machine {
  Machines.machine(baseURL: url, auth: .bearer(tokenProvider))
}

class IntentHandler: INExtension {
  
  override func handler(for intent: INIntent) -> Any {
    return self
  }
  
}

extension IntentHandler: MachineStatusIntentHandling {
  func handle(intent: MachineStatusIntent, completion: @escaping (MachineStatusIntentResponse) -> Void) {
    
    do {
      let response = MachineStatusIntentResponse(code: .success, userActivity: nil)
      response.status = try machine().status().awaitOutput()
      
      completion(response)
    } catch Machines.Error.deviceNotAuthenticated {
      completion(.init(code: .notAuthenticated, userActivity: nil))
    } catch {
      completion(.init(code: .failure, userActivity: nil))
    }
  }
}


extension IntentHandler: MachineStopIntentHandling {
  func handle(intent: MachineStopIntent, completion: @escaping (MachineStopIntentResponse) -> Void) {
    do {
      let _ = try machine().stop().awaitOutput()
      let response = MachineStopIntentResponse(code: .success, userActivity: nil)
      completion(response)
    } catch Machines.Error.deviceNotAuthenticated {
      completion(.init(code: .notAuthenticated, userActivity: nil))
    } catch {
      completion(.init(code: .failure, userActivity: nil))
    }
  }
}


extension IntentHandler: MachineStartIntentHandling {
  func resolveRegion(for intent: MachineStartIntent, with completion: @escaping (INStringResolutionResult) -> Void) {
    guard let region = intent.region?.lowercased(),
          Machines.availableRegions.contains(region)
    else {
      return completion(.success(with: Machines.availableRegions.first!))
    }
    completion(.success(with: region))
  }
  
  func resolveSize(for intent: MachineStartIntent, with completion: @escaping (INStringResolutionResult) -> Void) {
    guard
      let size = intent.size?.lowercased(),
      Machines.availableSizes.contains(size)
    else {
      return completion(.success(with: Machines.availableSizes.first!))
    }
    completion(.success(with: size))
  }
  
  func provideRegionOptionsCollection(for intent: MachineStartIntent, searchTerm: String?, with completion: @escaping (INObjectCollection<NSString>?, Error?) -> Void) {
    
    var items = Machines.availableRegions.map { $0 as NSString }
    
    if let filter =  searchTerm?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) {
      items = items.filter({ s in
        s.contains(filter)
      })
    }
    
    
    completion(INObjectCollection<NSString>(items: items), nil)
  }
  
  func provideSizeOptionsCollection(for intent: MachineStartIntent, searchTerm: String?, with completion: @escaping (INObjectCollection<NSString>?, Error?) -> Void) {
    
    var items = Machines.availableSizes.map { $0 as NSString }
    if let filter =  searchTerm?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) {
      items = items.filter({ s in
        s.contains(filter)
      })
    }
    
    completion(INObjectCollection<NSString>(items: items), nil)
  }
  
  func handle(intent: MachineStartIntent, completion: @escaping (MachineStartIntentResponse) -> Void) {
    guard
      let region = intent.region?.lowercased(),
      Machines.availableRegions.contains(region),
      let size = intent.size?.lowercased(),
      Machines.availableSizes.contains(size)
    else {
      return completion(.init(code: .failure, userActivity: nil))
    }
    
    do {
      let _ = try machine().start(region: region, size: size).awaitOutput()
      
      completion(.init(code: .success, userActivity: nil))
    } catch Machines.Error.deviceNotAuthenticated {
      completion(.init(code: .notAuthenticated, userActivity: nil))
    } catch {
      completion(.init(code: .failure, userActivity: nil))
    }
  }
  
  
}
