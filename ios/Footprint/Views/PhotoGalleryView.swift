import Photos
import SwiftUI

/// View that displays photos from the user's photo library by asset IDs
struct PhotoGalleryView: View {
    let photoAssetIDs: [String]
    @Environment(\.dismiss) private var dismiss
    @State private var assets: [PHAsset] = []
    @State private var isLoading = true
    @State private var selectedAsset: PHAsset?

    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 150), spacing: 2)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading photos...")
                } else if assets.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                        Text("No photos found")
                            .font(.headline)
                        Text("The photos may have been deleted from your library.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(assets, id: \.localIdentifier) { asset in
                                PhotoThumbnailView(asset: asset)
                                    .aspectRatio(1, contentMode: .fill)
                                    .clipped()
                                    .onTapGesture {
                                        selectedAsset = asset
                                    }
                            }
                        }
                        .padding(2)
                    }
                }
            }
            .navigationTitle("\(assets.count) Photo\(assets.count == 1 ? "" : "s")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .fullScreenCover(item: $selectedAsset) { asset in
                PhotoDetailView(asset: asset)
            }
        }
        .task {
            await loadAssets()
        }
    }

    private func loadAssets() async {
        Log.photoGallery.debug("Loading \(photoAssetIDs.count) asset IDs")

        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: photoAssetIDs, options: nil)
        Log.photoGallery.debug("Fetch returned \(fetchResult.count) assets")

        var loadedAssets: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in
            loadedAssets.append(asset)
        }
        // Sort by creation date, newest first
        loadedAssets.sort { ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast) }

        await MainActor.run {
            assets = loadedAssets
            isLoading = false
        }
    }
}

/// Thumbnail view for a single photo
struct PhotoThumbnailView: View {
    let asset: PHAsset
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay {
                        ProgressView()
                            .scaleEffect(0.5)
                    }
            }
        }
        .task {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true

        let targetSize = CGSize(width: 200, height: 200)

        await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { result, info in
                if let result = result {
                    Task { @MainActor in
                        self.image = result
                    }
                }
                // Only continue once (not for degraded images)
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if !isDegraded {
                    continuation.resume()
                }
            }
        }
    }
}

/// Full-screen photo detail view
struct PhotoDetailView: View {
    let asset: PHAsset
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    Color.black.ignoresSafeArea()

                    if let image = image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height)
                    } else if isLoading {
                        ProgressView()
                            .tint(.white)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }

                ToolbarItem(placement: .principal) {
                    if let date = asset.creationDate {
                        Text(date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .task {
            await loadFullImage()
        }
    }

    private func loadFullImage() async {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true

        let targetSize = CGSize(width: asset.pixelWidth, height: asset.pixelHeight)

        await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { result, info in
                Task { @MainActor in
                    if let result = result {
                        self.image = result
                    }
                    self.isLoading = false
                }
                continuation.resume()
            }
        }
    }
}

// Make PHAsset identifiable for the fullScreenCover
extension PHAsset: @retroactive Identifiable {
    public var id: String { localIdentifier }
}

#Preview {
    PhotoGalleryView(photoAssetIDs: [])
}
