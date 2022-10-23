// MIT License
//
// Copyright (c) 2022 Yi Wang
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import AVFoundation
import Foundation
import SwiftUI

public struct LoopingPlayerView: UIViewRepresentable {
  private let videoURL: URL
  private let playbackRate: Float

  public init(videoURL: URL, playbackRate: Float) {
    self.videoURL = videoURL
    self.playbackRate = playbackRate
  }

  public func makeUIView(context: Context) -> AVPlayerView {
    AVPlayerView()
  }

  public func makeCoordinator() -> AVPlayerLooper {
    AVPlayerLooper()
  }

  public func updateUIView(_ uiView: AVPlayerView, context: Context) {
    let player = AVPlayer(url: videoURL)
    uiView.player = player
    context.coordinator.loopPlayer(player, atRate: playbackRate)
  }
}

public class AVPlayerLooper {
  private var observer: Any?

  fileprivate func loopPlayer(_ avPlayer: AVPlayer, atRate rate: Float) {
    avPlayer.rate = rate > 0 ? rate : 1.0

    observer = NotificationCenter.default.addObserver(
      forName: NSNotification.Name.AVPlayerItemDidPlayToEndTime,
      object: nil,
      queue: OperationQueue.main
    ) { [weak avPlayer] _ in
      avPlayer?.seek(to: .zero)
      avPlayer?.play()
    }
  }

  deinit {
    if let observer = observer {
      NotificationCenter.default.removeObserver(observer)
    }
  }
}

public class AVPlayerView: UIView {
  public override class var layerClass: AnyClass {
    AVPlayerLayer.self
  }

  var player: AVPlayer? {
    get {
      playerLayer.player
    }
    set {
      playerLayer.player = newValue
      playerLayer.videoGravity = .resizeAspectFill
    }
  }

  private var playerLayer: AVPlayerLayer {
    layer as! AVPlayerLayer
  }
}
