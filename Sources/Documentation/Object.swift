enum ObjectType: String, Codable {
	case `class`
	case method
	case interface
	case typeAlias
	case enumeration
	case `struct`
	case `extension`
}

class InstanceType: Codable {
	let name: String
	var refLink: String?
	var pureName: String {
		self.name
			.replacingOccurrences(of: "?", with: "")
			.replacingOccurrences(of: "[", with: "")
			.replacingOccurrences(of: "]", with: "")
	}

	init(name: String) {
		self.name = name
	}
}

class Method: Codable {
	let name: String
	var description: String?
	var parameters: [Property]
	var result: ReturnResult?
	private let isConstructor: Bool = false

	init(name: String, parameters: [Property], result: ReturnResult?) {
		self.name = name
		self.parameters = parameters
		self.result = result
	}
}

class Property: Codable {
	let name: String
	let types: [InstanceType]
	var description: String?
	var isOptional: Bool?

	init(name: String, types: [InstanceType]) {
		self.name = name
		self.types = types
	}

}

class Properties: Codable {
	let name: String
	var description: String?
	/// Class
	var constructorMethods: [Method]?
	var methods: [Method]?
	var implement: [InstanceType]?
	/// Interface
	var inherits: [InstanceType]?
	var properties: [Property]?
	/// Method
	var isConstructor: Bool?
	var parameters: [Property]?
	var result: ReturnResult?
	init(name: String) {
		self.name = name
	}
}

class Object: Codable {
	let type: ObjectType
	var props: Properties
	init(type: ObjectType, props: Properties) {
		self.type = type
		self.props = props
	}
}

struct Documentation: Codable {
	struct Config: Codable {
		var textProvider: String = "md"
	}
	private let config: Config = Config()
	let refMap: [String: Object]
}

class ReturnResult: Codable {
	var types: [InstanceType]
	var description: String?
	init(types: [InstanceType]) {
		self.types = types
	}
}

extension Object {

	func refMap() -> String {
		"/ios/maps/reference/\(self.props.name)"
	}

	func addMissingRefs(_ refs: [String: String]) {
		self.props.constructorMethods?.forEach({ $0.addMissingRefs(refs) })
		self.props.implement?.addMissingRefs(refs)
		self.props.inherits?.addMissingRefs(refs)
		self.props.methods?.forEach({ $0.addMissingRefs(refs) })
		self.props.properties?.forEach({ $0.addMissingRefs(refs) })
		self.props.parameters?.forEach({ $0.addMissingRefs(refs) })
		self.props.result?.addMissingRefs(refs)
	}

}

extension Method {
	func addMissingRefs(_ refs: [String: String]) {
		self.parameters.forEach { $0.addMissingRefs(refs) }
		self.result?.addMissingRefs(refs)
	}
}

extension Property {
	func addMissingRefs(_ refs: [String: String]) {
		self.types.addMissingRefs(refs)
	}
}

extension InstanceType {
	func addMissingRefs(_ refs: [String: String]) {
		self.refLink = refs[self.pureName]
	}
}

extension ReturnResult {
	func addMissingRefs(_ refs: [String: String]) {
		self.types.addMissingRefs(refs)
	}
}

extension Array where Element == InstanceType {
	func addMissingRefs(_ refs: [String: String]) {
		self.forEach { $0.addMissingRefs(refs) }
	}
}

