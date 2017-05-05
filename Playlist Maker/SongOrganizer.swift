//
//  ViewController.swift
//  Playlist Maker
//
//  Created by Tomn on 04/05/2017.
//  Copyright © 2017 Thomas NAUDET. All rights reserved.
//

import UIKit

class SongOrganizer: UIViewController {

    @IBOutlet weak var artwork: UIImageView!
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var artistLabel: UILabel!
    @IBOutlet weak var detailLabel: UILabel!
    
    @IBOutlet weak var scrubbar: UISlider!
    
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var progressionLabel: UILabel!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        DataStore.shared.library.load()
        show(song: DataStore.shared.library.songs.first!)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func show(song: Song) {
        
        artwork.image = song.artwork
        
        titleLabel.text  = song.title
        artistLabel.text = song.artist
        detailLabel.text = song.album
        
        scrubbar.minimumValue = 0
        scrubbar.maximumValue = Float(song.length)
        scrubbar.value = 0
        
        progressionLabel.text = "\(DataStore.shared.currrentIndex ?? 1)/\(DataStore.shared.library.songs.count)"
    }

}

