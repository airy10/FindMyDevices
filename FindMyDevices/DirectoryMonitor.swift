//
//  DirectoryMonitor.swift
//  FindMyDevices
//
//  Created by Airy ANDRE on 08/02/2024.
//  From https://developer.apple.com/forums/thread/115387


import Foundation

class DirectoryMonitor {

    init(dir: URL, queue: DispatchQueue, callback: @escaping (URL, FSEventStreamEventFlags) -> Void) {
        self.dir = dir
        self.queue = queue
        self.changeProcessor = callback
    }

    deinit {
        // The stream has a reference to us via its `info` pointer. If the
        // client releases their reference to us without calling `stop`, that
        // results in a dangling pointer. We detect this as a programming error.
        // There are other approaches to take here (for example, messing around
        // with weak, or forming a retain cycle that’s broken on `stop`), but
        // this approach:
        //
        // * Has clear rules
        // * Is easy to implement
        // * Generate a sensible debug message if the client gets things wrong
        precondition(self.stream == nil, "released a running monitor")
    }

    let dir: URL
    let queue: DispatchQueue

    let changeProcessor: (URL, FSEventStreamEventFlags) -> Void

    private var stream: FSEventStreamRef? = nil

    func start() -> Bool {
        precondition(self.stream == nil, "started a running monitor")

        // Set up our context.
        //
        // `FSEventStreamCallback` is a C function, so we pass `self` to the
        // `info` pointer so that it get call our `handleUnsafeEvents(…)`
        // method.  This involves the standard `Unmanaged` dance:
        //
        // * Here we set `info` to an unretained pointer to `self`.
        // * Inside the function we extract that pointer as `obj` and then use
        //   that to call `handleUnsafeEvents(…)`.

        var context = FSEventStreamContext()
        context.info = Unmanaged.passUnretained(self).toOpaque()

        // Create the stream.
        //
        // In this example I wanted to show how to deal with raw string paths,
        // so I’m not taking advantage of `kFSEventStreamCreateFlagUseCFTypes`
        // or the even cooler `kFSEventStreamCreateFlagUseExtendedData`.

        guard let stream = FSEventStreamCreate(nil, { (stream, info, numEvents, eventPaths, eventFlags, eventIds) in
            let obj = Unmanaged<DirectoryMonitor>.fromOpaque(info!).takeUnretainedValue()
            obj.handleUnsafeEvents(numEvents: numEvents, eventPaths: eventPaths, eventFlags: eventFlags, eventIDs: eventIds)
        },
                                               &context,
                                               [self.dir.path as NSString] as NSArray,
                                               UInt64(kFSEventStreamEventIdSinceNow),
                                               1.0,
                                               FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamEventFlagItemIsFile | kFSEventStreamEventFlagItemModified | kFSEventStreamEventFlagItemCreated)
        ) else {
            return false
        }
        self.stream = stream

        // Now that we have a stream, schedule it on our target queue.

        FSEventStreamSetDispatchQueue(stream, queue)
        guard FSEventStreamStart(stream) else {
            FSEventStreamInvalidate(stream)
            self.stream = nil
            return false
        }
        return true
    }

    private func handleUnsafeEvents(numEvents: Int, eventPaths: UnsafeMutableRawPointer, eventFlags: UnsafePointer<FSEventStreamEventFlags>, eventIDs: UnsafePointer<FSEventStreamEventId>) {
        // This takes the low-level goo from the C callback, converts it to
        // something that makes sense for Swift, and then passes that to
        // `handle(events:…)`.
        //
        // Note that we don’t need to do any rebinding here because this data is
        // coming C as the right type.
        let pathsBase = eventPaths.assumingMemoryBound(to: UnsafePointer<CChar>.self)
        let pathsBuffer = UnsafeBufferPointer(start: pathsBase, count: numEvents)
        let flagsBuffer = UnsafeBufferPointer(start: eventFlags, count: numEvents)
        let eventIDsBuffer = UnsafeBufferPointer(start: eventIDs, count: numEvents)
        // As `zip(_:_:)` only handles two sequences, I map over the index.
        let events = (0..<numEvents).map { i -> (url: URL, flags: FSEventStreamEventFlags, eventIDs: FSEventStreamEventId) in
            let path = pathsBuffer[i]
            // If we set `isDirectory` to true because we only generate directory
            // events (that is, we don’t pass
            // `kFSEventStreamCreateFlagFileEvents` to `FSEventStreamCreate`.
            // This is generally the best way to use FSEvents, but if you decide
            // to take advantage of `kFSEventStreamCreateFlagFileEvents` then
            // you’ll need to code to `isDirectory` correctly.
            let url: URL = URL(fileURLWithFileSystemRepresentation: path, isDirectory: false, relativeTo: nil)
            return (url, flagsBuffer[i], eventIDsBuffer[i])
        }
        self.handle(events: events)
    }

    private func handle(events: [(url: URL, flags: FSEventStreamEventFlags, eventIDs: FSEventStreamEventId)]) {
        for (url, flags, _) in events {
            changeProcessor(url, flags)
        }
    }

    func stop() {
        guard let stream = self.stream else {
            return          // We accept redundant calls to `stop`.
        }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        self.stream = nil
    }
}
