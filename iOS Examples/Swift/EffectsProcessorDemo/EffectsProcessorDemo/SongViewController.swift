//
//  SongViewController.swift
//  EffectsProcessorDemo
//
//  Created by Aurelius Prochazka on 12/25/13.
//  Copyright (c) 2013 Aurelius Prochazka. All rights reserved.
//


import UIKit
import AVFoundation
import MediaPlayer

class SongViewController: UIViewController {
    
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var albumImageView: UIImageView!
    
    var exportPath: String = ""
    var isReadyToPlay: Bool = true
    var startTime: Float = 0.00
    var global: SharedStore!
    
    var song: MPMediaItem? {
        didSet {
            global = SharedStore.globals
            
            if song!.valueForProperty(MPMediaItemPropertyArtistPersistentID).integerValue !=
                global.currentSong?.valueForProperty(MPMediaItemPropertyArtistPersistentID).integerValue {
                
                global.audioFilePlayer.stop()
                global.isPlaying = false
                global.currentSong = song!
                startTime = 0
                exportSong(song!)
                    
            } else { // the same song again.
                isReadyToPlay = true
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        if let artwork = global.currentSong!.valueForProperty(MPMediaItemPropertyArtwork) as? MPMediaItemArtwork {
            albumImageView.image = artwork.imageWithSize(self.view.bounds.size)
        }
        
        if global.isPlaying!  {
            playButton.setTitle("Pause", forState: .Normal)
        } else {
            playButton.setTitle("Play", forState: .Normal)
        }
    }
    
    @IBAction func play(sender: UIButton) {
        
        if isReadyToPlay == false {
            println("Not Ready")
            return
        }
        
        global = SharedStore.globals
       
        if sender.titleLabel!.text == "Play" {
            loadSong()
            let playback = Playback(startTime: startTime)
            global.audioFilePlayer.playNote(playback)
            playButton.setTitle("Pause", forState: .Normal)
            playButton.hidden = false
            global.isPlaying = true
        
        } else {
            global.audioFilePlayer.stop()
            startTime = startTime + global.audioFilePlayer.filePosition!.value
            playButton.setTitle("Play", forState: .Normal)
            global.isPlaying = false
        }
    }
    
    func loadSong() {
        
        global = SharedStore.globals
        
        if NSFileManager.defaultManager().fileExistsAtPath(exportPath) == false {
            println("exportPath: \(exportPath)")
            println("File does not exist.")
            return
        }
    
        playButton.hidden = false
        
        // Create the orchestra and instruments
        global.audioFilePlayer = AudioFilePlayer()
        global.variableDelay = VariableDelay(audioSource: global.audioFilePlayer.auxilliaryOutput)
        global.moogLadder = MoogLadder(audioSource: global.variableDelay!.auxilliaryOutput)
        global.reverb = Reverb(audioSource: global.moogLadder!.auxilliaryOutput)
        
        AKOrchestra.addInstrument(global.audioFilePlayer)
        AKOrchestra.addInstrument(global.variableDelay!)
        AKOrchestra.addInstrument(global.moogLadder!)
        AKOrchestra.addInstrument(global.reverb!)
        
        global.variableDelay!.play()
        global.moogLadder!.play()
        global.reverb!.play()
    }
    
    func exportSong(song: MPMediaItem) {
        
        isReadyToPlay = false
        
        let paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, NSSearchPathDomainMask.UserDomainMask, false)
        let documentsDirectory = paths[0] as! String
        exportPath = String(format: "%@/exported.wav", documentsDirectory)
    
        let url = song.valueForProperty(MPMediaItemPropertyAssetURL) as! NSURL
        let songAsset = AVURLAsset(URL: url, options: nil)
        
        var assetError: NSError?
        var assetReader: AVAssetReader?
        
        if let assetReader = AVAssetReader(asset: songAsset, error: &assetError) {
            
            // Create an asset reader ouput and add it to the reader.
            let assetReaderOutput = AVAssetReaderAudioMixOutput(audioTracks: songAsset.tracks, audioSettings: nil)
            
            if !assetReader.canAddOutput(assetReaderOutput) {
                println("Can't add reader output...die!")
            } else {
                assetReader.addOutput(assetReaderOutput)
            }
            
            // If a file already exists at the export path, remove it.
            if NSFileManager.defaultManager().fileExistsAtPath(exportPath) {
                println("Deleting said file.")
                NSFileManager.defaultManager().removeItemAtPath(exportPath, error: nil)
            }
            
            // Create an asset writer with the export path.
            let exportURL = NSURL.fileURLWithPath(exportPath)
            let assetWriter = AVAssetWriter(URL: exportURL, fileType: AVFileTypeCoreAudioFormat, error: &assetError)
            
            if assetError != nil {
                println("Error \(assetError)")
                return
            }
            
            // Define the format settings for the asset writer.  Defined in AVAudioSettings.h
            var channelLayout: AudioChannelLayout?
            // memset(&channelLayout, 0, sizeof(AudioChannelLayout))
            let outputSettings = [ AVFormatIDKey: NSNumber(integer: kAudioFormatLinearPCM),
                AVSampleRateKey: NSNumber(float: 44100.0),
                AVNumberOfChannelsKey: NSNumber(unsignedInt: 2),
                // AVChannelLayoutKey: NSData(bytes: &channelLayout, length: sizeof(AudioChannelLayout)),
                AVLinearPCMBitDepthKey: NSNumber(int: 16),
                AVLinearPCMIsNonInterleaved: NSNumber(bool: false),
                AVLinearPCMIsFloatKey: NSNumber(bool: false),
                AVLinearPCMIsBigEndianKey: NSNumber(bool: false)
            ]
            
            // Create a writer input to encode and write samples in this format.
            let assetWriterInput = AVAssetWriterInput(mediaType: AVMediaTypeAudio, outputSettings: outputSettings)
            
            // Add the input to the writer.
            if assetWriter.canAddInput(assetWriterInput) {
                assetWriter.addInput(assetWriterInput)
            } else {
                println("cant add asset writer input...die!")
                return
            }
                
            // Change this property to YES if you want to start using the data immediately.
            assetWriterInput.expectsMediaDataInRealTime = false
                
            // Start reading from the reader and writing to the writer.
            assetWriter.startWriting()
            assetReader.startReading()
                
            // Set the session start time.
            let soundTrack = songAsset.tracks[0] as! AVAssetTrack
            let cmtStartTime: CMTime = CMTimeMake(0, soundTrack.naturalTimeScale)
            assetWriter.startSessionAtSourceTime(cmtStartTime)
            
            // Variable to store the converted bytes.
            var convertedByteCount: Int = 0
            var buffers: Float = 0
                
            // Create a queue to which the writing block with be submitted.
            let mediaInputQueue: dispatch_queue_t = dispatch_queue_create("mediaInputQueue", nil)
            
            // Instruct the writer input to invoke a block repeatedly, at its convenience, in
            // order to gather media data for writing to the output.
            assetWriterInput.requestMediaDataWhenReadyOnQueue(mediaInputQueue, usingBlock: {
                
                // While the writer input can accept more samples, keep appending its buffers
                // with buffers read from the reader output.
                while (assetWriterInput.readyForMoreMediaData) {
                    
                    let nextBuffer = assetReaderOutput.copyNextSampleBuffer()
                    
                    if (nextBuffer != nil) {
                        assetWriterInput.appendSampleBuffer(nextBuffer)
                        // Increment byte count.
                        convertedByteCount += CMSampleBufferGetTotalSampleSize(nextBuffer)
                        buffers += 0.0002
                    
                    } else {
                        // All done
                        assetWriterInput.markAsFinished()
                        assetWriter.finishWritingWithCompletionHandler(){
                            self.isReadyToPlay = true
                            self.playButton.hidden = false
                        }
                        assetReader.cancelReading()
                        break
                    }
                    // Core Foundation objects automatically memory managed in Swift
                    // CFRelease(nextBuffer)
                }
            })

                
        } else {
            println("Initializing assetReader Failed")
        }
        
    }

}














