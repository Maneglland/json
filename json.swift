import Foundation

// MARK: - Error
// swiftlint:disable line_length
public enum SwiftyJSONError: Int, Swift.Error {
    case unsupportedType = 999
    case indexOutOfBounds = 900
    case elementTooDeep = 902
    case wrongType = 901
    case notExist = 500
    case invalidJSON = 490
}

extension SwiftyJSONError: CustomNSError {

    /// return the error domain of SwiftyJSONError
    public static var errorDomain: String { return "com.swiftyjson.SwiftyJSON" }

    /// return the error code of SwiftyJSONError
    public var errorCode: Int { return self.rawValue }

    /// return the userInfo of SwiftyJSONError
    public var errorUserInfo: [String: Any] {
        switch self {
        case .unsupportedType:
            return [NSLocalizedDescriptionKey: "It is an unsupported type."]
        case .indexOutOfBounds:
            return [NSLocalizedDescriptionKey: "Array Index is out of bounds."]
        case .wrongType:
            return [NSLocalizedDescriptionKey: "Couldn't merge, because the JSONs differ in type on top level."]
        case .notExist:
            return [NSLocalizedDescriptionKey: "Dictionary key does not exist."]
        case .invalidJSON:
            return [NSLocalizedDescriptionKey: "JSON is invalid."]
        case .elementTooDeep:
            return [NSLocalizedDescriptionKey: "Element too deep. Increase maxObjectDepth and make sure there is no reference loop."]
        }
    }
}

// MARK: - JSON Type

/**
JSON's type definitions.

See http://www.json.org
*/
public enum Type: Int {
	case number
	case string
	case bool
	case array
	case dictionary
	case null
	case unknown
}

// MARK: - JSON Base

public struct JSON {

	/**
	 Creates a JSON using the data.
	
	 - parameter data: The NSData used to convert to json.Top level object in data is an NSArray or NSDictionary
	 - parameter opt: The JSON serialization reading options. `[]` by default.
	
	 - returns: The created JSON
	 */
    public init(data: Data, options opt: JSONSerialization.ReadingOptions = []) throws {
        let object: Any = try JSONSerialization.jsonObject(with: data, options: opt)
        self.init(jsonObject: object)
    }

    /**
	 Creates a JSON object
	 - note: this does not parse a `String` into JSON, instead use `init(parseJSON: String)`
	
	 - parameter object: the object

	 - returns: the created JSON object
	 */
    public init(_ object: Any) {
        switch object {
        case let object as Data:
            do {
                try self.init(data: object)
            } catch {
                self.init(jsonObject: NSNull())
            }
        default:
            self.init(jsonObject: object)
        }
    }

	/**
	 Parses the JSON string into a JSON object
	
	 - parameter json: the JSON string
	
	 - returns: the created JSON object
	*/
	public init(parseJSON jsonString: String) {
		if let data = jsonString.data(using: .utf8) {
			self.init(data)
		} else {
			self.init(NSNull())
		}
	}

	/**
	 Creates a JSON using the object.
	
	 - parameter jsonObject:  The object must have the following properties: All objects are NSString/String, NSNumber/Int/Float/Double/Bool, NSArray/Array, NSDictionary/Dictionary, or NSNull; All dictionary keys are NSStrings/String; NSNumbers are not NaN or infinity.
	
	 - returns: The created JSON
	 */
    fileprivate init(jsonObject: Any) {
        object = jsonObject
    }

	/**
	 Merges another JSON into this JSON, whereas primitive values which are not present in this JSON are getting added,
	 present values getting overwritten, array values getting appended and nested JSONs getting merged the same way.
 
	 - parameter other: The JSON which gets merged into this JSON
	
	 - throws `ErrorWrongType` if the other JSONs differs in type on the top level.
	 */
    public mutating func merge(with other: JSON) throws {
        try self.merge(with: other, typecheck: true)
    }

	/**
	 Merges another JSON into this JSON and returns a new JSON, whereas primitive values which are not present in this JSON are getting added,
	 present values getting overwritten, array values getting appended and nested JSONS getting merged the same way.
	
	 - parameter other: The JSON which gets merged into this JSON
	
	 - throws `ErrorWrongType` if the other JSONs differs in type on the top level.
	
	 - returns: New merged JSON
	 */
    public func merged(with other: JSON) throws -> JSON {
        var merged = self
        try merged.merge(with: other, typecheck: true)
        return merged
    }

    /**
     Private woker function which does the actual merging
     Typecheck is set to true for the first recursion level to prevent total override of the source JSON
 	*/
 	fileprivate mutating func merge(with other: JSON, typecheck: Bool) throws {
        if type == other.type {
            switch type {
            case .dictionary:
                for (key, _) in other {
                    try self[key].merge(with: other[key], typecheck: false)
                }
            case .array:
                self = JSON(arrayValue + other.arrayValue)
            default:
                self = other
            }
        } else {
            if typecheck {
                throw SwiftyJSONError.wrongType
            } else {
                self = other
            }
        }
    }

    /// Private object
    fileprivate var rawArray: [Any] = []
    fileprivate var rawDictionary: [String: Any] = [:]
    fileprivate var rawString: String = ""
    fileprivate var rawNumber: NSNumber = 0
    fileprivate var rawNull: NSNull = NSNull()
    fileprivate var rawBool: Bool = false

    /// JSON type, fileprivate setter
    public fileprivate(set) var type: Type = .null

    /// Error in JSON, fileprivate setter
    public fileprivate(set) var error: SwiftyJSONError?

    /// Object in JSON
    public var object: Any {
        get {
            switch type {
            case .array:      return rawArray
            case .dictionary: return rawDictionary
            case .string:     return rawString
            case .number:     return rawNumber
            case .bool:       return rawBool
            default:          return rawNull
            }
        }
        set {
            error = nil
            switch unwrap(newValue) {
            case let number as NSNumber:
                if number.isBool {
                    type = .bool
                    rawBool = number.boolValue
                } else {
                    type = .number
                    rawNumber = number
                }
            case let string as String:
                type = .string
                rawString = string
            case _ as NSNull:
                type = .null
            case Optional<Any>.none:
                type = .null
            case let array as [Any]:
                type = .array
                rawArray = array
            case let dictionary as [String: Any]:
                type = .dictionary
                rawDictionary = dictionary
            default:
                type = .unknown
                error = SwiftyJSONError.unsupportedType
            }
        }
    }

    /// The static null JSON
    @available(*, unavailable, renamed:"null")
    public static var nullJSON: JSON { return null }
    public static var null: JSON { return JSON(NSNull()) }
}

/// Private method to unwarp an object recursively
private func unwrap(_ object: Any) -> Any {
    switch object {
    case let json as JSON:
        return unwrap(json.object)
    case let array as [Any]:
        return array.map(unwrap)
    case let dictionary as [String: Any]:
        var d = dictionary
        dictionary.forEach { pair in
            d[pair.key] = unwrap(pair.value)
        }
        return d
    default:
        return object
    }
}

public enum Index<T: Any>: Comparable {
    case array(Int)
    case dictionary(DictionaryIndex<String, T>)
    case null

    static public func == (lhs: Index, rhs: Index) -> Bool {
        switch (lhs, rhs) {
        case (.array(let left), .array(let right)):           return left == right
        case (.dictionary(let left), .dictionary(let right)): return left == right
        case (.null, .null):                                  return true
        default:                                              return false
        }
    }

    static public func < (lhs: Index, rhs: Index) -> Bool {
        switch (lhs, rhs) {
        case (.array(let left), .array(let right)):           return left < right
        case (.dictionary(let left), .dictionary(let right)): return left < right
        default:                                              return false
        }
    }
}

public typealias JSONIndex = Index<JSON>
public typealias JSONRawIndex = Index<Any>

extension JSON: Swift.Collection {

    public typealias Index = JSONRawIndex

    public var startIndex: Index {
        switch type {
        case .array:      return .array(rawArray.startIndex)
        case .dictionary: return .dictionary(rawDictionary.startIndex)
        default:          return .null
        }
    }

    public var endIndex: Index {
        switch type {
        case .array:      return .array(rawArray.endIndex)
        case .dictionary: return .dictionary(rawDictionary.endIndex)
        default:          return .null
        }
    }

    public func index(after i: Index) -> Index {
        switch i {
        case .array(let idx):      return .array(rawArray.index(after: idx))
        case .dictionary(let idx): return .dictionary(rawDictionary.index(after: idx))
        default:                   return .null
        }
    }

    public subscript (position: Index) -> (String, JSON) {
        switch position {
        case .array(let idx):      return (String(idx), JSON(rawArray[idx]))
        case .dictionary(let idx): return (rawDictionary[idx].key, JSON(rawDictionary[idx].value))
        default:                   return ("", JSON.null)
        }
    }
}

// MARK: - Subscript

/**
 *  To mark both String and Int can be used in subscript.
 */
public enum JSONKey {
    case index(Int)
    case key(String)
}

public protocol JSONSubscriptType {
    var jsonKey: JSONKey { get }
}

extension Int: JSONSubscriptType {
    public var jsonKey: JSONKey {
        return JSONKey.index(self)
    }
}

extension String: JSONSubscriptType {
    public var jsonKey: JSONKey {
        return JSONKey.key(self)
    }
}

extension JSON {

    /// If `type` is `.array`, return json whose object is `array[index]`, otherwise return null json with error.
    fileprivate subscript(index index: Int) -> JSON {
        get {
            if type != .array {
                var r = JSON.null
                r.error = self.error ?? SwiftyJSONError.wrongType
                return r
            } else if rawArray.indices.contains(index) {
                return JSON(rawArray[index])
            } else {
                var r = JSON.null
                r.error = SwiftyJSONError.indexOutOfBounds
                return r
            }
        }
        set {
            if type == .array &&
                rawArray.indices.contains(index) &&
                newValue.error == nil {
                rawArray[index] = newValue.object
            }
        }
    }

    /// If `type` is `.dictionary`, return json whose object is `dictionary[key]` , otherwise return null json with error.
    fileprivate subscript(key key: String) -> JSON {
        get {
            var r = JSON.null
            if type == .dictionary {
                if let o = rawDictionary[key] {
                    r = JSON(o)
                } else {
                    r.error = SwiftyJSONError.notExist
                }
            } else {
                r.error = self.error ?? SwiftyJSONError.wrongType
            }
            return r
        }
        set {
            if type == .dictionary && newValue.error == nil {
                rawDictionary[key] = newValue.object
            }
        }
    }

    /// If `sub` is `Int`, return `subscript(index:)`; If `sub` is `String`,  return `subscript(key:)`.
    fileprivate subscript(sub sub: JSONSubscriptType) -> JSON {
        get {
            switch sub.jsonKey {
            case .index(let index): return self[index: index]
            case .key(let key):     return self[key: key]
            }
        }
        set {
            switch sub.jsonKey {
            case .index(let index): self[index: index] = newValue
            case .key(let key):     self[key: key] = newValue
            }
        }
    }

	/**
	 Find a json in the complex data structures by using array of Int and/or String as path.
	
	 Example:
	
	 ```
	 let json = JSON[data]
	 let path = [9,"list","person","name"]
	 let name = json[path]
	 ```
	
	 The same as: let name = json[9]["list"]["person"]["name"]
	
	 - parameter path: The target json's path.
	
	 - returns: Return a json found by the path or a null json with error
	 */
    public subscript(path: [JSONSubscriptType]) -> JSON {
        get {
            return path.reduce(self) { $0[sub: $1] }
        }
        set {
            switch path.count {
            case 0: return
            case 1: self[sub:path[0]].object = newValue.object
            default:
                var aPath = path
                aPath.remove(at: 0)
                var nextJSON = self[sub: path[0]]
                nextJSON[aPath] = newValue
                self[sub: path[0]] = nextJSON
            }
        }
    }

    /**
     Find a json in the complex data structures by using array of Int and/or String as path.

     - parameter path: The target json's path. Example:

     let name = json[9,"list","person","name"]

     The same as: let name = json[9]["list"]["person"]["name"]

     - returns: Return a json found by the path or a null json with error
     */
    public subscript(path: JSONSubscriptType...) -> JSON {
        get {
            return self[path]
        }
        set {
            self[path] = newValue
        }
    }
}

// MARK: - LiteralConvertible

extension JSON: Swift.ExpressibleByStringLiteral {

    public init(stringLiteral value: StringLiteralType) {
        self.init(value)
    }

    public init(extendedGraphemeClusterLiteral value: StringLiteralType) {
        self.init(value)
    }

    public init(unicodeScalarLiteral value: StringLiteralType) {
        self.init(value)
    }
}

extension JSON: Swift.ExpressibleByIntegerLiteral {

    public init(integerLiteral value: IntegerLiteralType) {
        self.init(value)
    }
}

extension JSON: Swift.ExpressibleByBooleanLiteral {

    public init(booleanLiteral value: BooleanLiteralType) {
        self.init(value)
    }
}

extension JSON: Swift.ExpressibleByFloatLiteral {

    public init(floatLiteral value: FloatLiteralType) {
        self.init(value)
    }
}

extension JSON: Swift.ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, Any)...) {
        let dictionary = elements.reduce(into: [String: Any](), { $0[$1.0] = $1.1})
        self.init(dictionary)
    }
}

extension JSON: Swift.ExpressibleByArrayLiteral {

    public init(arrayLiteral elements: Any...) {
        self.init(elements)
    }
}

// MARK: - Raw

extension JSON: Swift.RawRepresentable {

    public init?(rawValue: Any) {
        if JSON(rawValue).type == .unknown {
            return nil
        } else {
            self.init(rawValue)
        }
    }

    public var rawValue: Any {
        return object
    }

    public func rawData(options opt: JSONSerialization.WritingOptions = JSONSerialization.WritingOptions(rawValue: 0)) throws -> Data {
        guard JSONSerialization.isValidJSONObject(object) else {
            throw SwiftyJSONError.invalidJSON
        }

        return try JSONSerialization.data(withJSONObject: object, options: opt)
	}

	public func rawString(_ encoding: String.Encoding = .utf8, options opt: JSONSerialization.WritingOptions = .prettyPrinted) -> String? {
		do {
			return try _rawString(encoding, options: [.jsonSerialization: opt])
		} catch {
			print("Could not serialize object to JSON because:", error.localizedDescription)
			return nil
		}
	}

	public func rawString(_ options: [writingOptionsKeys: Any]) -> String? {
		let encoding = options[.encoding] as? String.Encoding ?? String.Encoding.utf8
		let maxObjectDepth = options[.maxObjextDepth] as? Int ?? 10
		do {
			return try _rawString(encoding, options: options, maxObjectDepth: maxObjectDepth)
		} catch {
			print("Could not serialize object to JSON because:", error.localizedDescription)
			return nil
		}
	}

	fileprivate func _rawString(_ encoding: String.Encoding = .utf8, options: [writingOptionsKeys: Any], maxObjectDepth: Int = 10) throws -> String? {
        guard maxObjectDepth > 0 else { throw SwiftyJSONError.invalidJSON }
        switch type {
        case .dictionary:
			do {
				if !(options[.castNilToNSNull] as? Bool ?? false) {
					let jsonOption = options[.jsonSerialization] as? JSONSerialization.WritingOptions ?? JSONSerialization.WritingOptions.prettyPrinted
					let data = try rawData(options: jsonOption)
					return String(data: data, encoding: encoding)
				}

				guard let dict = object as? [String: Any?] else {
					return nil
				}
				let body = try dict.keys.map { key throws -> String in
					guard let value = dict[key] else {
						return "\"\(key)\": null"
					}
					guard let unwrappedValue = value else {
						return "\"\(key)\": null"
					}

					let nestedValue = JSON(unwrappedValue)
					guard let nestedString = try nestedValue._rawString(encoding, options: options, maxObjectDepth: maxObjectDepth - 1) else {
						throw SwiftyJSONError.elementTooDeep
					}
					if nestedValue.type == .string {
						return "\"\(key)\": \"\(nestedString.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\""
					} else {
						return "\"\(key)\": \(nestedString)"
					}
				}

				return "{\(body.joined(separator: ","))}"
			} catch _ {
				return nil
			}
        case .array:
            do {
				if !(options[.castNilToNSNull] as? Bool ?? false) {
					let jsonOption = options[.jsonSerialization] as? JSONSerialization.WritingOptions ?? JSONSerialization.WritingOptions.prettyPrinted
					let data = try rawData(options: jsonOption)
					return String(data: data, encoding: encoding)
				}

                guard let array = object as? [Any?] else {
                    return nil
                }
                let body = try array.map { value throws -> String in
                    guard let unwrappedValue = value else {
                        return "null"
                    }

                    let nestedValue = JSON(unwrappedValue)
                    guard let nestedString = try nestedValue._rawString(encoding, options: options, maxObjectDepth: maxObjectDepth - 1) else {
                        throw SwiftyJSONError.invalidJSON
                    }
                    if nestedValue.type == .string {
                        return "\"\(nestedString.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\""
                    } else {
                        return nestedString
                    }
                }

                return "[\(body.joined(separator: ","))]"
            } catch _ {
                return nil
            }
        case .string: return rawString
        case .number: return rawNumber.stringValue
        case .bool:   return rawBool.description
        case .null:   return "null"
        default:      return nil
        }
    }
}
