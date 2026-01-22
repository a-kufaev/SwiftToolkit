//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftToolkit open source project
//
// Copyright (c) 2026 Artem Kufaev
// Licensed under MIT License
//
// See https://github.com/a-kufaev/SwiftToolkit/blob/main/LICENSE for license information
//
//===----------------------------------------------------------------------===//

#if canImport(UIKit) && canImport(PhotosUI)
import PhotosUI
import SwiftUI

struct ImagesPickerModifier: ViewModifier {

    @Binding
    var isPresented: Bool
    @Binding
    var selection: UIImage?

    let preferredItemEncoding: PhotosPickerItem.EncodingDisambiguationPolicy

    @State
    private var pickerItem: PhotosPickerItem?

    func body(content: Content) -> some View {
        content
            .photosPicker(
                isPresented: $isPresented,
                selection: $pickerItem,
                matching: .images,
                preferredItemEncoding: preferredItemEncoding
            )
            .task(id: pickerItem) {
                guard let item = pickerItem,
                      let data = try? await item.loadTransferable(type: Data.self) else {
                    selection = nil
                    return
                }
                selection = UIImage(data: data)
            }
            .onChange(of: selection) { _, newValue in
                if newValue == nil {
                    pickerItem = nil
                }
            }
    }
}

extension View {
    /// Presents the system photos picker and delivers the chosen image as a `UIImage`.
    public func imagesPicker(
        isPresented: Binding<Bool>,
        selection: Binding<UIImage?>,
        preferredItemEncoding: PhotosPickerItem.EncodingDisambiguationPolicy = .automatic
    ) -> some View {
        modifier(ImagesPickerModifier(
            isPresented: isPresented,
            selection: selection,
            preferredItemEncoding: preferredItemEncoding
        ))
    }
}
#endif
