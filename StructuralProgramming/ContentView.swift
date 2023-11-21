//

import SwiftUI
import Structural

var initial = Book(title: "Thinking in SwiftUI", published: .now, authors: "Florian and Chris", updated: true)

struct ContentView: View {
    let sampleBT = BookType.hardcover(title: "Test", published: .now)

    @State private var book = initial
    @State private var update = BookUpdate(description: "foo", date: .now)

    let simple = Simple(foo: "Hello", bar: Date())
    var body: some View {
        VStack {
            simple.view
//            sampleBT.view
            book.view
            Form {
                Book.edit($book)
                BookUpdate.edit($update)
            }
            Button("Generate Random") {
                book = Book.random()
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
