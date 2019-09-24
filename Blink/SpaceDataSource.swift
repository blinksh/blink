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


import UIKit

/**
 Our custom DataSource, bc DiffableDataSource doesn't work well with drag and drop for now
*/
class SpaceDataSource: NSObject, UICollectionViewDataSource {
  
  typealias CellBuilder = (_ collectionView: UICollectionView, _ indexPath: IndexPath, _ key: UUID) -> UICollectionViewCell?
  
  private var _workingData: [UUID] = []
  private var _uiData: [UUID] = []
  var cellBuilder: CellBuilder?
  
  func setInitialData(data: [UUID]) {
    _uiData = data
    _workingData = data
  }
  
  var isUIEmpty: Bool {
    _uiData.isEmpty
  }
  
  func uiIndexOf(key: UUID) -> Int? {
    _uiData.firstIndex(of: key)
  }
  
  var uiData:[UUID] { _uiData }
  
  func keyFor(indexPath: IndexPath) -> UUID? {
    if _uiData.startIndex >= indexPath.row && _uiData.endIndex < indexPath.row {
      return _uiData[indexPath.row]
    }
    return nil
  }
  
  var isEmpty: Bool {
    _workingData.isEmpty
  }
  
  func insert(items: [UUID], after: UUID?) {
    if let after = after, let idx = _workingData.firstIndex(of: after) {
      _workingData.insert(contentsOf: items, at: idx)
    } else {
      _workingData.append(contentsOf: items)
    }
  }
  
  func delete(items: [UUID]) {
    _workingData.removeAll { (key) -> Bool in
      items.firstIndex(of: key) != nil
    }
  }
  
  func indexPath(for key: UUID?) -> IndexPath? {
    if let idx = index(for: key) {
      return IndexPath(row: idx, section: 0)
    }
    return nil
  }
  
  func index(for key: UUID?) -> Int? {
    if let key = key {
      return _uiData.firstIndex(of: key)
    }
    return nil
  }
  
  func apply(collectionView: UICollectionView) {
    let diff = _workingData.difference(from: _uiData)
    if diff.isEmpty {
      return
    }
    
    let diffWithMoves = diff.inferringMoves()
    
    collectionView.performBatchUpdates({
      var inserts: [IndexPath] = []
      var deletes: [IndexPath] = []
      var reloads: [IndexPath] = []
      for change in diffWithMoves {
        switch change {
        case .insert(offset: let row, element: _, associatedWith: let associatedRow):
          if let destRow = associatedRow {
            if row == destRow {
              reloads.append(IndexPath(row: row, section: 0))
            } else {
              collectionView.moveItem(at: IndexPath(row: row, section: 0), to: IndexPath(row: destRow, section: 0))
            }
          } else {
            inserts.append(IndexPath(row: row, section: 0))
          }
        case .remove(offset: let row, element: _, associatedWith: let targetIndex):
          if targetIndex == nil {
            deletes.append(IndexPath(row: row, section: 0))
          }
        }
      }
      
      collectionView.insertItems(at: inserts)
      collectionView.deleteItems(at: deletes)
      collectionView.reloadItems(at: reloads)
      self._uiData = self._workingData
    }) { (done) in
      
    }
  }
  
  var count: Int {
    _uiData.count
  }
  
  func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    if section == 0 {
      return _uiData.count
    }
    return 0
  }
  
  func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let key = _uiData[indexPath.row]
    guard
      let builder = cellBuilder,
      let cell = builder(collectionView, indexPath, key)
    else {
      return UICollectionViewCell()
    }
    
    return cell
  }
}
