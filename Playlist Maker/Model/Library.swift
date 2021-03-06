//
//  Library.swift
//  Playlist Maker
//
//  Created by Tomn on 04/05/2017.
//  Copyright © 2017 Thomas NAUDET. All rights reserved.
//

import Foundation
import MediaPlayer

/// Available song selection settings.
/// Associated `Int` is settings storage value.
enum SongSelectionMode: Int {
    /// Songs added to library before/after selected date(s)
    case addedDate       = 5
    /// Songs in no playlist at all
    case inNoPlaylist    = 0
    /// Songs not in destination playlists
    case inNoDestination = 1
    /// Songs not in selected playlists
    case notInPlaylists  = 2
    /// Songs in selected playlists
    case inPlaylists     = 3
    /// Whole library
    case allSongs        = 4
    /// Only used when editing destination playlists
    case destination     = -1
    
    /// Get table view row index from mode
    func rowIndex() -> Int {
        switch self {
        case .addedDate:
            return 0
        case .inNoPlaylist:
            return 1
        case .inNoDestination:
            return 2
        case .notInPlaylists:
            return 3
        case .inPlaylists:
            return 4
        case .allSongs:
            return 5
        case .destination:
            return -1
        }
    }
    
    /// Get mode from table view row index
    static func mode(for row: Int) -> SongSelectionMode? {
        switch row {
        case 0:
            return .addedDate
        case 1:
            return .inNoPlaylist
        case 2:
            return .inNoDestination
        case 3:
            return .notInPlaylists
        case 4:
            return .inPlaylists
        case 5:
            return .allSongs
        default:
            return nil
        }
    }
}


/// Available song selection at date settings.
/// Associated `Int` is settings storage value.
enum DateSelectionMode: Int {
    /// `SongSelectionMode.addedDate` applies to song added dates before selection
    case before = 0
    /// `SongSelectionMode.addedDate` applies to song added dates after selection
    case after  = 1
    /// `SongSelectionMode.addedDate` applies to song added dates between date selection
    case range  = 2
}


/// Contains all information about the current songs to sort
class Library {
    
    // MARK: Status
    
    typealias LibraryStatus = MPMediaLibraryAuthorizationStatus
    
    /// Get current access status from iOS
    class var status: LibraryStatus {
        return MPMediaLibrary.authorizationStatus()
    }
    
    
    /// Ask access to iOS music library
    ///
    /// - Parameter handler: Block called after the user choses whether to authorize the app
    class func askAuthorization(handler: @escaping (LibraryStatus) -> Void) {
        
        MPMediaLibrary.requestAuthorization(handler)
    }
    
    
    // MARK: Content
    
    /// List of the songs to sort
    var songs = [Song]()
    
    /// List of the playlists
    var playlists = [Playlist]()
    
    /// Stored selection of playlists for Not Contained In mode
    var selectionNotInPlaylists = [Playlist]() {
        didSet {
            UserDefaults.standard.set(selectionNotInPlaylists.map { $0.id },
                                      forKey: UserDefaultsKey.selectionNotInPlaylists)
        }
    }
    
    /// Stored selection of playlists for Contained In mode
    var selectionInPlaylists = [Playlist]() {
        didSet {
            UserDefaults.standard.set(selectionInPlaylists.map { $0.id },
                                      forKey: UserDefaultsKey.selectionInPlaylists)
        }
    }
    
    /// Stored selection of playlists acting as destinations when sorting songs
    var destinationPlaylists = [Playlist]() {
        didSet {
            UserDefaults.standard.set(destinationPlaylists.map { $0.id },
                                      forKey: UserDefaultsKey.destinationPlaylists)
        }
    }
    
    
    /// Fill library with user's playlists
    func loadPlaylists(completionHandler completion: @escaping () -> ()) {
        
        DispatchQueue.global(qos: .userInitiated).async {
            
            guard Library.status == .authorized else {
                completion()
                return
            }
        
            // Get raw playlists in library focus
            let libraryPlaylists = MPMediaQuery.playlists().collections ?? []
            var playlists = [Playlist]()
            
            // Store playlists
            for libraryPlaylist in libraryPlaylists {
                if let playlist = libraryPlaylist as? MPMediaPlaylist {
                    playlists.append(Playlist(raw: playlist))
                }
            }
            
            // Sort by name
            playlists.sort { playlist1, playlist2 in
                playlist1.name.localizedCaseInsensitiveCompare(playlist2.name) == .orderedAscending
            }
            
            self.playlists = playlists
            
            /* Load selection subsets */
            // Associated class properties have a `didSet`, so we'll create temporary variables
            var t_selectionNotInPlaylists = [Playlist]()
            var t_selectionInPlaylists    = [Playlist]()
            var t_destinationPlaylists    = [Playlist]()
            
            // Fetch stored playlist IDs
            let def = UserDefaults.standard
            if let notInPlaylistsDef = def.array(forKey: UserDefaultsKey.selectionNotInPlaylists) as? [NSNumber],
               let inPlaylistsDef    = def.array(forKey: UserDefaultsKey.selectionInPlaylists) as? [NSNumber],
               let destPlaylistsDef  = def.array(forKey: UserDefaultsKey.destinationPlaylists) as? [NSNumber] {
                
                // Process every playlist we have
                for playlist in playlists {
                    
                    // Add the playlist if its ID is contained in the storage
                    if notInPlaylistsDef.contains(playlist.id) {
                        t_selectionNotInPlaylists.append(playlist)
                    }
                    if inPlaylistsDef.contains(playlist.id) {
                        t_selectionInPlaylists.append(playlist)
                    }
                    if destPlaylistsDef.contains(playlist.id) {
                        t_destinationPlaylists.append(playlist)
                    }
                }
            }
            
            // Finish by copying back
            self.selectionNotInPlaylists  = t_selectionNotInPlaylists
            self.selectionInPlaylists     = t_selectionInPlaylists
            if t_destinationPlaylists.isEmpty {
                self.destinationPlaylists = self.playlists
            } else {
                self.destinationPlaylists = t_destinationPlaylists
            }
            
            completion()
        }
    }
    
    /// Fill library with songs to sort
    func loadSongs(using songSelectionMode: SongSelectionMode,
                   completionHandler completion: @escaping () -> ()) {
        
        DispatchQueue.global(qos: .userInitiated).async {
            
            guard Library.status == .authorized else {
                completion()
                return
            }
            
            let librarySongs: Set<MPMediaItem>
            
            // Select songs according to mode
            switch songSelectionMode {
            case .addedDate:
                librarySongs = LibraryQueries.addedToLibraryAtDates
                
            case .inNoPlaylist:
                librarySongs = LibraryQueries.inNoPlaylists
                
            case .inNoDestination:
                librarySongs = LibraryQueries.notInDestinationPlaylists
                
            case .notInPlaylists:
                librarySongs = LibraryQueries.notInSelectedPlaylists
                
            case .inPlaylists:
                librarySongs = LibraryQueries.inSelectedPlaylists
                
            case .allSongs:
                librarySongs = LibraryQueries.allSongs
                
            case .destination:
                // Error. Abort.
                self.songs = []
                completion()
                return
            }
            
            var songs = [Song]()
            
            // Store songs
            for songItem in librarySongs {
                songs.append(Song(raw: songItem))
            }
            
            if songSelectionMode == .addedDate &&
               DateSelectionMode(rawValue: UserDefaults.standard.integer(forKey: UserDefaultsKey.dateSelectionMode)) ?? .after == .after &&
               UserDefaults.standard.bool(forKey: UserDefaultsKey.dateSelectionUpdates) {
                // Sort by added date,
                // so the user gets the same Up Next list when they restart the sorting process
                songs.sort { song1, song2 in
                    song1.dateAdded < song2.dateAdded
                }
                
            } else {
                // Sort by artist
                songs.sort { song1, song2 in
                    song1.artist.localizedCaseInsensitiveCompare(song2.artist) == .orderedAscending
                }
            }
            
            self.songs = songs
            completion()
        }
    }
    
    /// Creates a playlist in the user's librayry
    ///
    /// - Parameters:
    ///   - playlistName: Name of the new playlist
    ///   - completionHandler: Called when operation completed.
    ///                        Gives back the new playlist object if succeeded, an error otherwise.
    class func createPlaylist(named playlistName: String,
                              completion completionHandler: @escaping (Playlist?, Error?) -> ()) {
        
        let data = MPMediaPlaylistCreationMetadata(name: playlistName)
        MPMediaLibrary.default().getPlaylist(with: UUID(),
                                             creationMetadata: data,
                                             completionHandler:
            { playlist, error in
                
                guard playlist != nil, error == nil else {
                    completionHandler(nil, error)
                    return
                }
                
                let newPlaylist = Playlist(raw: playlist!)
                completionHandler(newPlaylist, nil)
        })
    }
    
    /// Adds a given song to selected playlists
    ///
    /// - Parameters:
    ///   - song: Songs to add
    ///   - playlists: Destination playlists
    ///   - completionHandler: Called for each playlist processed.
    class func addSong(_ song: Song,
                       to playlists: [Playlist],
                       completion completionHandler: @escaping (Playlist, Error?) -> ()) {
        
        for playlist in playlists {
            
            // Add song to each playlist
            playlist.raw.add([song.raw]) { error in
                completionHandler(playlist, error)
            }
        }
    }
    
}


/// Represents a song in the user's library.
/// Wraps MPMediaItem
struct Song {
    
    /// Default maximum artwork size displayed
    static let artworkSize = CGSize(width: 100, height: 100)
    
    
    let id: UInt64
    
    let title: String
    
    let artist: String//Artist
    
    let album: String?//Album
    
    let genre: (category: Genre?, raw: String?)
    
    let length: TimeInterval
    
    let artwork: UIImage?
    
    let dateAdded: Date
    
    let raw: MPMediaItem
    
    
    /// Init Song object with a media library query result
    ///
    /// - Parameter item: Library item to wrap in Song object
    init(raw item: MPMediaItem) {
        
        self.raw = item
        
        /* Load property values in batch */
        var properties: [String : Any?] = [MPMediaItemPropertyPersistentID     : nil,
                                           MPMediaItemPropertyTitle            : nil,
                                           MPMediaItemPropertyArtist           : nil,
                                           MPMediaItemPropertyAlbumTitle       : nil,
                                           MPMediaItemPropertyGenre            : nil,
                                           MPMediaItemPropertyPlaybackDuration : nil,
                                           MPMediaItemPropertyDateAdded        : nil,
                                           MPMediaItemPropertyArtwork          : nil]
        
        item.enumerateValues(forProperties: Set(properties.keys)) { property, value, _ in
            properties[property] = value
        }
        
        /* Apply properties */
        self.id        = properties[MPMediaItemPropertyPersistentID] as? MPMediaEntityPersistentID ?? 0
        self.title     = properties[MPMediaItemPropertyTitle]        as? String ?? "Unknown title"
        self.artist    = properties[MPMediaItemPropertyArtist]       as? String ?? "Unknown artist"
        self.album     = properties[MPMediaItemPropertyAlbumTitle]   as? String ?? "Unknown album"
        if let genre   = properties[MPMediaItemPropertyGenre]        as? String {
            self.genre = (Genre(fromString: genre), genre)
        } else {
            self.genre = (.unknown, nil)
        }
        self.length    =  properties[MPMediaItemPropertyPlaybackDuration] as? TimeInterval ?? 0
        self.dateAdded =  properties[MPMediaItemPropertyDateAdded] as? Date ?? Date.distantPast
        self.artwork   = (properties[MPMediaItemPropertyArtwork] as? MPMediaItemArtwork)?.image(at: Song.artworkSize)
    }
    
}

/// Represents a user's playlist in their library.
/// MPMediaItemCollection wrapper
struct Playlist {
    
    /// Default maximum artwork size displayed
    static let artworkSize = CGSize(width: 200, height: 200)
    
    
    let id: NSNumber
    
    /// Name of the playlist
    let name: String
    
    /// Songs contained in the playlist
//    let songs: [Song]
    
    let artwork: UIImage?
    
    let raw: MPMediaPlaylist
    
    
    /// Init Playlist object with a playlist raw type
    ///
    /// - Parameter collection: Playlist in library
    init(raw collection: MPMediaPlaylist) {
        
        self.raw = collection
        
        /* Load property values in batch */
        var properties: [String : Any?] = [MPMediaPlaylistPropertyPersistentID : nil,
                                           MPMediaPlaylistPropertyName         : nil]
        
        collection.enumerateValues(forProperties: Set(properties.keys)) { property, value, _ in
            properties[property] = value
        }
        
        /* Apply properties */
        self.id   = properties[MPMediaPlaylistPropertyPersistentID] as? NSNumber ?? NSNumber(value: 0)
        self.name = properties[MPMediaPlaylistPropertyName]         as? String   ?? "Unknown playlist"
        
        /* Fetch artworks from the 4 first tracks
           Does not use collection.items.dropLast because it's O(nbrSongs - 4) */
        var artworks = [UIImage]()
        let nbrSongs = collection.count
        if let firstArtwork = collection.items.first?.artwork?.image(at: Playlist.artworkSize) {
            artworks.append(firstArtwork)
        }
        if nbrSongs > 1,
           let secondArtwork = collection.items[1].artwork?.image(at: Playlist.artworkSize) {
            artworks.append(secondArtwork)
        }
        if nbrSongs > 2,
           let thirdArtwork  = collection.items[2].artwork?.image(at: Playlist.artworkSize) {
            artworks.append(thirdArtwork)
        }
        if nbrSongs > 3,
           let fourthArtwork = collection.items[3].artwork?.image(at: Playlist.artworkSize) {
            artworks.append(fourthArtwork)
        }
        /* Try to find other artworks if there are not 4 enough */
        var index = 4
        while artworks.count < 4 && index < nbrSongs && index < 50 {
            
            if let otherArtwork = collection.items[index].artwork?.image(at: Playlist.artworkSize) {
                artworks.append(otherArtwork)
            }
            index += 1
        }
        
        /* Combine them */
        self.artwork = Playlist.combinedArtwork(from: artworks)
        
        /*self.songs = collection.items.map({ playlistItem -> Song in
            Song(item: playlistItem)
        })*/
    }
    
    /// <#Description#>
    ///
    /// - Parameter artworks: <#artworks description#>
    /// - Returns: <#return value description#>
    private static func combinedArtwork(from artworks: [UIImage]) -> UIImage? {
        
        if artworks.count >= 2 {
            let size = Playlist.artworkSize
            
            UIGraphicsBeginImageContextWithOptions(size, true, 0)
            let halfWidth  = size.width  / 2
            let halfHeight = size.height / 2
            
            UIColor.white.set()
            UIRectFill(CGRect(origin: .zero, size: size))
            
            if artworks.count == 2 {
                let halfSize = CGSize(width: size.width / 2, height: size.height / 2)
                
                artworks[0].draw(in: CGRect(origin: .zero, size: halfSize))
                artworks[1].draw(in: CGRect(origin: CGPoint(x: halfHeight, y: 0), size: halfSize))
                
            } else {
                let quarterSize = CGSize(width: size.width / 2, height: size.height / 2)
                
                artworks[0].draw(in: CGRect(origin: CGPoint(x: 0, y: 0), size: quarterSize))
                artworks[1].draw(in: CGRect(origin: CGPoint(x: halfWidth, y: 0), size: quarterSize))
                artworks[2].draw(in: CGRect(origin: CGPoint(x: 0, y: halfHeight), size: quarterSize))
                if artworks.count >= 4 {
                    artworks[3].draw(in: CGRect(origin: CGPoint(x: halfWidth, y: halfHeight), size: quarterSize))
                }
            }
            
            defer {
                UIGraphicsEndImageContext()
            }
            
            return UIGraphicsGetImageFromCurrentImageContext()
            
        } else if artworks.count == 1 {
            return artworks.first
            
        } else {
            return nil
        }
    }
    
    /// <#Description#>
    ///
    /// - Parameter song: <#song description#>
    /// - Returns: <#return value description#>
    func contains(song: Song) -> Bool {
        
        let songPredicate = MPMediaPropertyPredicate(value: song.id,
                                                     forProperty: MPMediaItemPropertyPersistentID,
                                                     comparisonType: .equalTo)
        let playlistPredicate = MPMediaPropertyPredicate(value: self.id,
                                                         forProperty: MPMediaPlaylistPropertyPersistentID,
                                                         comparisonType: .equalTo)
        let results = MPMediaQuery(filterPredicates: [songPredicate, playlistPredicate])
        
        return results.items?.count ?? 0 > 0
    }
    
    /// <#Description#>
    ///
    /// - Parameter song: <#song description#>
    /// - Returns: <#return value description#>
    func contains(songId: MPMediaEntityPersistentID) -> Bool {
        
        let songPredicate = MPMediaPropertyPredicate(value: songId,
                                                     forProperty: MPMediaItemPropertyPersistentID,
                                                     comparisonType: .equalTo)
        let playlistPredicate = MPMediaPropertyPredicate(value: self.id,
                                                         forProperty: MPMediaPlaylistPropertyPersistentID,
                                                         comparisonType: .equalTo)
        let results = MPMediaQuery(filterPredicates: [songPredicate, playlistPredicate])
        
        return results.items?.count ?? 0 > 0
    }
    
}

struct Artist {
    
    var albums: [Album] {
        return []
    }
    
}

struct Album {
    
}

/// Defines principal music genres
enum Genre: String {
    
    case country = "🤠"
    case disco = "🕺"
    case newAge = "📻"
    case alternative = "🔌"
    case rap = "🎙"
    case classical = "🎻"
    case dance = "💃"
    case electronic = "🎛"
    case house = "🏠"
    case reggae = "🇯🇲"
    case rock = "🎸"
    case pop = "🎤"
    case jazz = "🎷"
    case latin = "🇪🇸"
    case metal = "🤘"
    case singer = "👨‍🎤"
    case soundtrack = "🎥"
    case game = "🎮"
    case gospel = "⛪️"
    case world = "🌍"
    case instrumental = "🎹"
    case meditative = "💤"
    case experimental = "⚗️"
    case jPop = "🇯🇵"
    case book = "📓"
    case fantasy = "👽"
    case kids = "👶"
    case teens = "⭐️"
    case sports = "⚽️"
    case surf = "🏄"
    case tv = "📺"
    case britPop = "🇬🇧"
    case variété = "🇫🇷"
    case german = "🇩🇪"
    case unknown = "❓"
    
    init?(fromString input: String) {
        
        /* Lowercase and without accents for comparison purposes */
        let normalizedInput = input.lowercased().folding(options: .diacriticInsensitive, locale: .current)
        
        /* Find genre in input string */
        if normalizedInput.containsAny(["country"]) {
            self = .country
        } else if normalizedInput.containsAny(["variete", "franc", "french"]) {
            self = .variété
        } else if normalizedInput.containsAny(["brit"]) {
            self = .britPop
        } else if normalizedInput.containsAny(["german"]) {
            self = .german
        } else if normalizedInput.containsAny(["disco", "funk", "wave"]) {
            self = .disco
        } else if normalizedInput.containsAny(["age", "old", "swing"]) {
            self = .newAge
        } else if normalizedInput.containsAny(["rap", "hip-hop", "hiphop", "hip hop", "soul", "r&b", "rnb", "r'n'b"]) {
            self = .rap
        } else if normalizedInput.containsAny(["alternati", "indie", "trip"]) {
            self = .alternative
        } else if normalizedInput.containsAny(["classi", "symphoni", "sonat", "chamb"]) {
            self = .classical
        } else if normalizedInput.containsAny(["dance", "danse"]) {
            self = .dance
        } else if normalizedInput.containsAny(["lectroni", "dubstep", "tech", "trance", "fusion", "acid", "club"]) {
            self = .electronic
        } else if normalizedInput.containsAny(["house", "lounge"]) {
            self = .house
        } else if normalizedInput.containsAny(["reggae", "dub", "root", "ska"]) {
            self = .reggae
        } else if normalizedInput.containsAny(["jazz"]) {
            self = .jazz
        } else if normalizedInput.containsAny(["latin", "tango", "samba", "spain", "spanish", "espagn"]) {
            self = .latin
        } else if normalizedInput.containsAny(["metal", "punk", "hard", "bass", "jungle"]) {
            self = .metal
        } else if normalizedInput.containsAny(["singer", "chant", "vocal", "auteur", "writer", "voix", "voice", "spoken", "parle", "podcast"]) {
            self = .singer
        } else if normalizedInput.containsAny(["soundtrack", "movie", "film", "video"]) {
            self = .soundtrack
        } else if normalizedInput.containsAny(["kid", "child", "enfan", "family", "famille", "christmas", "holiday", "vacance"]) {
            self = .kids
        } else if normalizedInput.containsAny(["gospel", "christ", "chreti", "religi", "spirit"]) {
            self = .gospel
        } else if normalizedInput.containsAny(["world", "monde", "folk", "europ"]) {
            self = .world
        } else if normalizedInput.containsAny(["instrument", "acousti", "ambient", "ambian"]) {
            self = .instrumental
        } else if normalizedInput.containsAny(["meditat", "down"]) {
            self = .meditative
        } else if normalizedInput.containsAny(["jpop", "j-pop", "j pop", "anime"]) {
            self = .jPop
        } else if normalizedInput.containsAny(["book"]) {
            self = .book
        } else if normalizedInput.containsAny(["fantas", "scifi", "sci-fi", "sci fi"]) {
            self = .fantasy
        } else if normalizedInput.containsAny(["surf"]) {
            self = .surf
        } else if normalizedInput.containsAny(["sport"]) {
            self = .sports
        } else if normalizedInput.containsAny(["tv", "television"]) {
            self = .tv
        } else if normalizedInput.containsAny(["pop"]) {
            self = .pop
        } else if normalizedInput.containsAny(["rock", "grunge", "drum", "blues", "guitar"]) {
            self = .rock
        } else if normalizedInput.containsAny(["experiment", "industrial"]) {
            self = .experimental
        } else if normalizedInput.containsAny(["game", "jeu"]) {
            self = .game
        } else if normalizedInput.containsAny(["teen", "ado"]) {
            self = .teens
        } else if normalizedInput.containsAny(["unknown", "other", "easy"]) {
            self = .unknown
        } else {
            return nil
        }
    }
}
