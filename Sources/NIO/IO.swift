//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2017-2018 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//
#if os(Linux)
import Glibc
#else
import Darwin
#endif

public struct IOError: Swift.Error {
    
    public let errno: Int32
    public let reason: String?
    
    public init(errno errnoNumber: Int32, reason: String) {
        self.errno = errnoNumber
        self.reason = reason
    }
}

func ioError(errno: Int32, function: String) -> IOError {
    return IOError(errno: errno, reason: reasonForError(errno: errno, function: function))
}

func reasonForError(errno: Int32, function: String) -> String {
    if let strError = String(utf8String: strerror(errno)) {
        return "\(function) failed: errno(\(errno)) \(strError)"
    } else {
        return "\(function) failed"
    }
}

private func testForBlacklistedErrno(_ code: Int32) {
    switch code {
    case EFAULT:
        fallthrough
    case EBADF:
        fatalError("blacklisted errno \(code) \(strerror(code)!)")
    default:
        ()
    }
}

func wrapSyscall(function: @autoclosure () -> String,
                 _ successCondition: (Int) -> Bool, _ fn: () -> Int) throws -> Int {
    while true {
        let result = fn()
        if !successCondition(result) {
            let err = errno
            switch err {
            case EINTR:
                continue
            case let err:
                testForBlacklistedErrno(err)
                throw ioError(errno: err, function: function())
            }
        } else {
            return result
        }
    }
}

func wrapSyscall(_ successCondition: (Int) -> Bool,
                 function: @autoclosure () -> String, _ fn: () -> Int) throws -> Int {
    return try wrapSyscall(function: function, successCondition, fn)
}

public enum IOResult<T> {
    case wouldBlock
    case processed(T)
}


func wrapSyscallMayBlock(_ successCondition: (Int) -> Bool,
                         function: @autoclosure () -> String, _ fn: () -> Int) throws -> IOResult<Int> {
    loop: repeat {
        let result = fn()
        guard successCondition(result) else {
            let err = errno
            switch err {
            case EWOULDBLOCK:
                return .wouldBlock
            case EINTR:
                continue loop
            default:
                testForBlacklistedErrno(err)
                throw ioError(errno: err, function: function())
            }
        }
        return .processed(result)
    } while true
}

func wrapSyscall(function: @autoclosure () -> String,
                 _ successCondition: (Int32) -> Bool, _ fn: () -> Int32) throws -> Int32 {
    while true {
        let result = fn()
        if !successCondition(result) {
            let err = errno
            switch err {
            case EINTR:
                continue
            case let err:
                testForBlacklistedErrno(err)
                throw ioError(errno: err, function: function())
            }
        } else {
            return result
        }
    }
}

func wrapSyscall(_ successCondition: (Int32) -> Bool,
                 function: @autoclosure () -> String, _ fn: () -> Int32) throws -> Int32 {
    return try wrapSyscall(function: function, successCondition, fn)
}

func wrapSyscallMayBlock(_ successCondition: (Int32) -> Bool,
                         function: @autoclosure () -> String, _ fn: () -> Int32) throws -> IOResult<Int32> {
    
    loop: repeat {
        let result = fn()
        guard successCondition(result) else {
            let err = errno
            switch err {
            case EWOULDBLOCK:
                return .wouldBlock
            case EINTR:
                continue loop
            default:
                testForBlacklistedErrno(err)
                throw ioError(errno: err, function: function())
            }
        }
        return .processed(result)
    } while true
}