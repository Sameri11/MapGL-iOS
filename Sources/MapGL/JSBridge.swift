import Foundation
import CoreLocation
import WebKit

class JSBridge : NSObject {

	struct MapOptions {
		let center: CLLocationCoordinate2D
		let maxZoom: Double
		let minZoom: Double
		let zoom: Double
		let maxPitch: Double
		let minPitch: Double
		let pitch: Double
		let rotation: Double
		let apiKey: String
		let autoHideOSMCopyright: Bool
		let disableRotationByUserInteraction: Bool
		let disablePitchByUserInteraction: Bool
	}

	typealias Completion = (Result<Void, Error>) -> Void

	private unowned let executor: JSExecutorProtocol
	weak var delegate: JSBridgeDelegate?

	init(executor: JSExecutorProtocol) {
		self.executor = executor
	}

	func initializeMap(
		options: MapOptions,
		completion: Completion? = nil
	) {
		let js = "window.initializeMap(\(options.jsValue()));"
		self.evaluateJS(js, completion: completion)
	}

	func invalidateSize(completion: Completion? = nil) {
		let js = "window.map.invalidateSize();"
		self.evaluateJS(js, completion: completion)
	}

	func fetchGeographicalBounds(completion: @escaping (Result<GeographicalBounds, Error>) -> Void) {
		let js = "window.map.getBounds();"
		self.executor.evaluateJavaScript(js) { result, erorr in
			if let error = erorr {
				completion(.failure(error))
			} else {
				let dictionary = result as? [String: Any]
				if let bounds = GeographicalBounds(dictionary: dictionary) {
					completion(.success(bounds))
				} else {
					completion(.failure(MapGLError(text: "Parsing error")))
				}
			}
		}
	}

	func fetchMapCenter(completion: ((Result<CLLocationCoordinate2D, Error>) -> Void)?) {
		let js = "window.map.getCenter();"
		self.executor.evaluateJavaScript(js) { (result, erorr) in
			if let error = erorr {
				completion?(.failure(error))
			} else if let result = result as? [Double], result.count == 2 {
				let lon = result[0]
				let lat = result[1]
				completion?(.success(CLLocationCoordinate2D(latitude: lat, longitude: lon)))
			} else {
				completion?(.failure(MapGLError(text: "Parsing error")))
			}
		}
	}

	func setMapCenter(_ center: CLLocationCoordinate2D, completion: Completion? = nil) {
		let js = "window.map.setCenter(\(center.jsValue()));"
		self.evaluateJS(js, completion: completion)
	}

	func fetchMapZoom(completion: ((Result<Double, Error>) -> Void)?) {
		let js = "window.map.getZoom();"
		self.executor.evaluateJavaScript(js) { (result, erorr) in
			if let error = erorr {
				completion?(.failure(error))
			} else if let result = result as? Double {
				completion?(.success(result))
			} else {
				completion?(.failure(MapGLError(text: "Parsing error")))
			}
		}
	}

	func setMapZoom(_ zoom: Double, completion: Completion? = nil) {
		let js = "window.map.setZoom(\(zoom));"
		self.evaluateJS(js, completion: completion)
	}

	func setMapMaxZoom(_ maxZoom: Double, completion: Completion? = nil) {
		let js = "window.map.setMaxZoom(\(maxZoom));"
		self.evaluateJS(js, completion: completion)
	}

	func setMapMinZoom(_ minZoom: Double, completion: Completion? = nil) {
		let js = "window.map.setMinZoom(\(minZoom));"
		self.evaluateJS(js, completion: completion)
	}

	func fetchMapRotation(completion: ((Result<Double, Error>) -> Void)? = nil) {
		let js = "window.map.getRotation();"
		self.executor.evaluateJavaScript(js) { (result, erorr) in
			if let error = erorr {
				completion?(.failure(error))
			} else if let result = result as? Double {
				completion?(.success(result))
			} else {
				completion?(.failure(MapGLError(text: "Parsing error")))
			}
		}
	}

	func setMapRotation(_ rotation: Double, completion: Completion? = nil) {
		let js = "window.map.setRotation(\(rotation));"
		self.evaluateJS(js, completion: completion)
	}

	func fetchMapPitch(completion: ((Result<Double, Error>) -> Void)?) {
		let js = "window.map.getPitch();"
		self.executor.evaluateJavaScript(js) { (result, erorr) in
			if let error = erorr {
				completion?(.failure(error))
			} else if let result = result as? Double {
				completion?(.success(result))
			} else {
				completion?(.failure(MapGLError(text: "Parsing error")))
			}
		}
	}

	func setMapPitch(_ pitch: Double, completion: Completion? = nil) {
		let js = "window.map.setPitch(\(pitch));"
		self.evaluateJS(js, completion: completion)
	}

	func setMapMaxPitch(_ maxPitch: Double, completion: Completion? = nil) {
		let js = "window.map.setMaxPitch(\(maxPitch));"
		self.evaluateJS(js, completion: completion)
	}

	func setMapMinPitch(_ minPitch: Double, completion: Completion? = nil) {
		let js = "window.map.setMinPitch(\(minPitch));"
		self.evaluateJS(js, completion: completion)
	}

	func add(_ object: IJSMapObject, completion: Completion? = nil) {
		let js = object.createJSCode()
		self.evaluateJS(js, completion: completion)
	}

	func destroy(_ object: IJSMapObject, completion: Completion? = nil) {
		let js = object.destroyJSCode()
		self.evaluateJS(js, completion: completion)
	}

	func evaluateJS(_ js: String, completion: Completion? = nil) {
		self.executor.evaluateJavaScript(js) { (_, error) in
			if let error = error {
				completion?(.failure(error))
			} else {
				completion?(.success(()))
			}
		}
	}

	func setSelectedObjects(_ objectsIds: [String]) {
		let js = """
		window.setSelectedObjects(\(objectsIds.jsValue()));
		"""
		self.evaluateJS(js)
	}

}

extension JSBridge: WKScriptMessageHandler {

	var messageHandlerName: String { "dgsMessage" }
	var errorHandlerName: String { "error" }

	func userContentController(
		_ userContentController: WKUserContentController,
		didReceive message: WKScriptMessage
	) {
		switch message.name {
			case self.errorHandlerName:
				self.handleError(message: message)
			case self.messageHandlerName:
				self.handleMessage(message: message)
			default:
				break
		}
	}

	private func handleError(message: WKScriptMessage) {
	}

	private func handleMessage(message: WKScriptMessage) {
		guard let delegate = self.delegate else { return }
		guard let body = message.body as? [String: Any] else { return }
		guard let type = body["type"] as? String else { return }
		switch type {
			case "centerChanged":
				let data = body["value"] as? [Double]
				if let lat = data?.last, let lon = data?.first {
					delegate.js(self, mapCenterDidChange: CLLocationCoordinate2D(latitude: lat, longitude: lon))
			}
			case "zoomChanged":
				let data = body["value"] as? Double
				if let zoom = data {
					delegate.js(self, mapZoomDidChange: zoom)
			}
			case "rotationChanged":
				let data = body["value"] as? Double
				if let rotation = data {
					delegate.js(self, mapRotationDidChange: rotation)
			}
			case "pitchChanged":
				let data = body["value"] as? Double
				if let pitch = data {
					delegate.js(self, mapPitchDidChange: pitch)
			}
			case "mapClick":
				let data = body["value"] as? String
				if let event = MapClickEvent(string: data) {
					delegate.js(self, didClickMapWithEvent: event)
				}
			case "objectClick":
				if let id = body["value"] as? String {
					delegate.js(self, didClickObjectWithId: id)
				} else {
					assertionFailure()
				}
			case "clusterClick":
				guard let clusterId = body["id"] as? String else { assertionFailure(); return }

				if let marker = body["value"] as? [String: Any] {
					if let id = marker["id"] as? String {
						delegate.js(self, didClickClusterWithId: clusterId, markerIds: [id])
					} else {
						assertionFailure()
					}
				} else if let cluster = body["value"] as? [[String: Any]] {
					let ids = cluster.compactMap { $0["id"] as? String }
					assert(cluster.count == ids.count)
					delegate.js(self, didClickClusterWithId: clusterId, markerIds: ids)
				} else {
					assertionFailure()
				}
			case "carRouteCompletion":
				guard let data = body["value"] as? [String: String],
					  let directionId = data["directionId"],
					  let completionId = data["completionId"],
					  let error = data["error"] else {

					assertionFailure()
					return
				}
				let mapglError: MapGLError? = error.isEmpty ? nil : MapGLError(text: error)
				delegate.js(self, carRouteDidFinishWithId: directionId, completionId: completionId, error: mapglError)
			default:
				assertionFailure()
		}
	}

}

extension JSBridge.MapOptions: IJSOptions {

	func jsKeyValue() -> [String : IJSValue] {
		[
			"center": self.center,
			"maxZoom": self.maxZoom,
			"minZoom": self.minZoom,
			"zoom": self.zoom,
			"maxPitch": self.maxPitch,
			"minPitch": self.minPitch,
			"pitch": self.pitch,
			"rotation": self.rotation,
			"zoomControl": false,
			"key": self.apiKey,
			"interactiveCopyright": false,
			"autoHideOSMCopyright": self.autoHideOSMCopyright,
			"preserveDrawingBuffer": true,
			"disableRotationByUserInteraction": self.disableRotationByUserInteraction,
			"disablePitchByUserInteraction": self.disablePitchByUserInteraction,
		]
	}
}
