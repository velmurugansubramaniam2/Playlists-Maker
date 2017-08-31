//
//  PlaylistsView.swift
//  Playlist Maker
//
//  Created by Tomn on 06/05/2017.
//  Copyright © 2017 Thomas NAUDET. All rights reserved.
//

import UIKit

class PlaylistsViewController: UICollectionViewController {
    
    var organizer: SongOrganizer?
    
    var indexPathsForPlaylistsAlreadyContaining = [IndexPath]()
    
    var playlists = [Playlist]() {
        didSet {
            DispatchQueue.main.async {
                self.collectionView?.reloadData()
            }
        }
    }
    
    
    func createPlaylist() {
        
        let alert = UIAlertController(title: "Name your new playlist",
                                      message: nil,
                                      preferredStyle: .alert)
        
        alert.addTextField(configurationHandler: { textField in
            textField.placeholder = "My New Playlist"
        })
        
        let confirmAction = UIAlertAction(title: "Create",
                                          style: .default, handler: { [unowned self] _ in
            
            let name = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespaces)
            guard !(name?.isEmpty ?? true) else {
                /* Retry if empty name */
                self.createPlaylist()
                return
            }
            
            DataStore.shared.library.createPlaylist(named: name!,
                                                    completion:
                { [unowned self] playlist, error in
                    
                    /* Apple Music error */
                    guard error == nil else {
                        let alert = UIAlertController(title: "Unable to create playlist",
                                                      message: error?.localizedDescription,
                                                      preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
                        self.organizer?.present(alert, animated: true)
                        return
                    }
                    
                    /* Reload content */
                    self.playlists = DataStore.shared.library.playlists
                    DispatchQueue.main.async {
                        self.collectionView?.reloadItems(at: [IndexPath(item: self.playlists.count, section: 0),
                                                              IndexPath(item: self.playlists.count - 1, section: 0)])
                    }
            })
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(confirmAction)
        alert.preferredAction = confirmAction
        
        organizer?.present(alert, animated: true)
    }
    
}


// MARK: - Data Source
extension PlaylistsViewController {
    
    /// Defines the number of playlists displayed
    ///
    /// - Parameters:
    ///   - collectionView: Collection View to configure
    ///   - section: Group of cells to fill
    /// - Returns: Number of playlist cells in a given section
    override func collectionView(_ collectionView: UICollectionView,
                                 numberOfItemsInSection section: Int) -> Int {
        
        // Add 1 for Add Playlist cell
        return playlists.count + 1
    }
    
    /// Configure cells
    ///
    /// - Parameters:
    ///   - collectionView: Collection View to populate
    ///   - indexPath: Position of the cell to configure
    /// - Returns: The configured cell
    override func collectionView(_ collectionView: UICollectionView,
                                 cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        /* New Playlist Button */
        if indexPath.item == playlists.count {
            
            return collectionView.dequeueReusableCell(withReuseIdentifier: "newPlaylistCell",
                                                      for: indexPath)
        }
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "playlistCell",
                                                      for: indexPath) as! PlaylistCell
        
        let playlist = playlists[indexPath.item]
        cell.name.text = playlist.name
        cell.imageView.image = playlist.artwork
        
        cell.wrapper.layer.cornerRadius = 7
        cell.wrapper.clipsToBounds = true
        
        var selected = false
        if let selection = collectionView.indexPathsForSelectedItems?.contains(indexPath) {
            selected = selection
        }
        cell.apply(style: selected ? PlaylistCell.selectedShadowStyle
                                   : PlaylistCell.deselectedShadowStyle)
        cell.clipsToBounds = false
        
        return cell
    }
    
    /// Footer (hint how to use)
    override func collectionView(_ collectionView: UICollectionView,
                                 viewForSupplementaryElementOfKind kind: String,
                                 at indexPath: IndexPath) -> UICollectionReusableView {
        
        guard kind == UICollectionElementKindSectionFooter else {
            return UICollectionReusableView()
        }
        
        return collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionElementKindSectionFooter, withReuseIdentifier: "playlistFooter", for: indexPath)
    }
    
}

// MARK: - Delegate
extension PlaylistsViewController {
    
    /// Called when a not-selected-yet cell is tapped
    ///
    /// - Parameters:
    ///   - collectionView: Collection view containing the item
    ///   - indexPath: Position of the new selection
    override func collectionView(_ collectionView: UICollectionView,
                                 didSelectItemAt indexPath: IndexPath) {
        
        // Add Playlist Button
        if indexPath.item == playlists.count {
            
            createPlaylist()
            collectionView.deselectItem(at: indexPath, animated: false)
            return
        }
        
        if let cell = collectionView.cellForItem(at: indexPath) as? PlaylistCell {
            cell.animateSelectionStyle(before: PlaylistCell.deselectedShadowStyle,
                                       after:  PlaylistCell.selectedShadowStyle)
        }
    }
    
    /// Disable deselection of already selected playlists before the sorting process.
    ///
    /// - Parameters:
    ///   - collectionView: Collection view containing the item to deselect
    ///   - indexPath: Position of the requested deselection
    /// - Returns: Whether this item can be deselected
    override func collectionView(_ collectionView: UICollectionView,
                                 shouldDeselectItemAt indexPath: IndexPath) -> Bool {
        
        /* Return true by default */
        guard let organizer = organizer,
              indexPathsForPlaylistsAlreadyContaining.contains(indexPath) else {
            return true
        }
        
        /* Return false if the playlist contained the song before the sorting process.
           And display an alert */
        let alert = UIAlertController(title: "“\(DataStore.shared.currentSong?.title ?? "Unknown track")” is already in this playlist",
            message: "The playlist cannot be deselected, since the app is not allowed to remove songs from your playlists.\n\nPlease go in Music app to manually remove it.",
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Got it!", style: .cancel))
        organizer.present(alert, animated: true)
        
        return false
    }
    
    /// Called when a selected cell is tapped
    ///
    /// - Parameters:
    ///   - collectionView: Collection view containing the item
    ///   - indexPath: Position of the old selection
    override func collectionView(_ collectionView: UICollectionView,
                                 didDeselectItemAt indexPath: IndexPath) {
        
        if let cell = collectionView.cellForItem(at: indexPath) as? PlaylistCell {
            
            cell.animateSelectionStyle(before: PlaylistCell.selectedShadowStyle,
                                       after:  PlaylistCell.deselectedShadowStyle)
        }
    }
    
}


// MARK:
/// Appearance & structure of a cell displaying a playlist
class PlaylistCell: UICollectionViewCell {
    
    typealias PlaylistCellStyle = (opacity: Float, color: CGColor, radius: CGFloat, offset: CGSize)
    
    static let deselectedShadowStyle: PlaylistCellStyle = (opacity: 0.2, color: UIColor.black.cgColor,
                                                           radius: 5, offset: CGSize(width: 0, height: 4))
    
    static let selectedShadowStyle:   PlaylistCellStyle = (opacity: 1, color: #colorLiteral(red: 1, green: 0.231372549, blue: 0.1921568627, alpha: 1).cgColor,
                                                           radius: 8, offset: .zero)
    
    static let shadowPath = CGPath(rect: CGRect(x: 0, y: 0, width: 100, height: 100), transform: nil)
    
    
    /// Text displaying the name of the playlist
    @IBOutlet weak var name:  UILabel!
    
    /// Background image
    @IBOutlet weak var imageView: UIImageView!
    
    /// View holding the content (name, image)
    @IBOutlet weak var wrapper: UIView!
    
    
    func apply(style: PlaylistCellStyle) {
        let contentLayer = contentView.layer
        contentLayer.shadowOpacity = style.opacity
        contentLayer.shadowColor   = style.color
        contentLayer.shadowRadius  = style.radius
        contentLayer.shadowOffset  = style.offset
        contentLayer.shadowPath    = PlaylistCell.shadowPath
    }
    
    func animateSelectionStyle(before: PlaylistCellStyle, after: PlaylistCellStyle) {
        
        let duration = 0.15
        let contentLayer = contentView.layer
        
        let animationOpacity = CABasicAnimation(keyPath: "shadowOpacity")
        animationOpacity.fromValue = before.opacity
        animationOpacity.toValue   = after.opacity
        animationOpacity.duration  = duration
        contentLayer.add(animationOpacity, forKey: "shadowOpacity")
        
        let animationColor = CABasicAnimation(keyPath: "shadowColor")
        animationColor.fromValue = before.color
        animationColor.toValue   = after.color
        animationColor.duration  = duration
        contentLayer.add(animationColor, forKey: "shadowColor")
        
        let animationRadius = CABasicAnimation(keyPath: "shadowRadius")
        animationRadius.fromValue = before.radius
        animationRadius.toValue   = after.radius
        animationRadius.duration  = duration
        contentLayer.add(animationRadius, forKey: "shadowRadius")
        
        let animationOffset = CABasicAnimation(keyPath: "shadowOffset")
        animationOffset.fromValue = before.offset
        animationOffset.toValue   = after.offset
        animationOffset.duration  = duration
        contentLayer.add(animationOffset, forKey: "shadowOffset")
        
        apply(style: after)
    }
    
}
