//
//  File.swift
//  
//
//  Created by Jari (LotU) on 04/06/2019.
//

import Prometheus
import CoreMetrics

class MetricsCounter: CounterHandler {
    let counter: PromCounter<Int64, DimensionLabels>
    let labels: DimensionLabels?
    
    internal init(counter: PromCounter<Int64, DimensionLabels>, dimensions: [(String, String)]?) {
        self.counter = counter
        guard let dimensions = dimensions else {
            labels = nil
            return
        }
        self.labels = DimensionLabels(dimensions)
    }
    
    func increment(by: Int64) {
        self.counter.inc(by, labels)
    }
    
    func reset() { }
}

class MetricsGauge: RecorderHandler {
    let gauge: PromGauge<Double, DimensionLabels>
    let labels: DimensionLabels?
    
    internal init(gauge: PromGauge<Double, DimensionLabels>, dimensions: [(String, String)]?) {
        self.gauge = gauge
        guard let dimensions = dimensions else {
            labels = nil
            return
        }
        self.labels = DimensionLabels(dimensions)
    }
    
    func record(_ value: Int64) {
        gauge.inc(value.doubleValue, labels)
    }
    
    func record(_ value: Double) {
        gauge.inc(value, labels)
    }
}

class MetricsHistogram: RecorderHandler {
    let histogram: PromHistogram<Double, DimensionHistogramLabels>
    let labels: DimensionHistogramLabels?
    
    internal init(histogram: PromHistogram<Double, DimensionHistogramLabels>, dimensions: [(String, String)]?) {
        self.histogram = histogram
        guard let dimensions = dimensions else {
            labels = nil
            return
        }
        self.labels = DimensionHistogramLabels(dimensions)
    }
    
    func record(_ value: Int64) {
        histogram.observe(value.doubleValue, labels)
    }
    
    func record(_ value: Double) {
        histogram.observe(value, labels)
    }
}

class MetricsSummary: TimerHandler {
    let summary: PromSummary<Int64, DimensionSummaryLabels>
    let labels: DimensionSummaryLabels?
    
    internal init(summary: PromSummary<Int64, DimensionSummaryLabels>, dimensions: [(String, String)]?) {
        self.summary = summary
        guard let dimensions = dimensions else {
            labels = nil
            return
        }
        self.labels = DimensionSummaryLabels(dimensions)
    }
    
    func recordNanoseconds(_ duration: Int64) {
        summary.observe(duration, labels)
    }
}

extension PrometheusClient: MetricsFactory {
    public func destroyCounter(_ handler: CounterHandler) {
        
    }
    
    public func destroyRecorder(_ handler: RecorderHandler) {
        
    }
    
    public func destroyTimer(_ handler: TimerHandler) {
        
    }
    
    /// Makes a counter
    public func makeCounter(label: String, dimensions: [(String, String)]) -> CounterHandler {
//        fatalError()
        let createHandler = { (counter: PromCounter) -> CounterHandler in
            return MetricsCounter(counter: counter, dimensions: dimensions)
        }
        if let counter = self.metrics.compactMap({ $0 as? PromCounter<Int64, DimensionLabels> }).filter({ (m) -> Bool in
            return m._type == .counter && m.name == label
        }).first {
            return createHandler(counter)
        }
        return createHandler(self.createCounter(forType: Int64.self, named: label, withLabelType: DimensionLabels.self))
    }
    
    /// Makes a recorder
    public func makeRecorder(label: String, dimensions: [(String, String)], aggregate: Bool) -> RecorderHandler {
        fatalError()
        //        if let recorder = self.metrics.filter({ (m) -> Bool in
        //            return m._type == (aggregate ? .histogram : .gauge) && m.name == label
        //        }).first as? RecorderHandler {
        //            return recorder
        //        }
        //        if aggregate {
        //            return self.createHistogram(forType: Double.self, named: label, labels: DimensionHistogramLabels.self)
        //        } else {
        //            return self.createGauge(forType: Double.self, named: label, withLabelType: DimensionLabels.self)
        //        }
    }
    
    /// Makes a timer
    public func makeTimer(label: String, dimensions: [(String, String)]) -> TimerHandler {
        fatalError()
        //        if let timer = self.metrics.filter({ (m) -> Bool in
        //            return m._type == .summary && m.name == label
        //        }).first as? TimerHandler {
        //            return timer
        //        }
        //        return self.createSummary(forType: Double.self, named: label, labels: DimensionSummaryLabels.self)
    }
}

public extension MetricsSystem {
    /// Get the bootstrapped `MetricsSystem` as `PrometheusClient`
    ///
    /// - Returns: `PrometheusClient` used to bootstrap `MetricsSystem`
    /// - Throws: `PrometheusError.PrometheusFactoryNotBootstrapped`
    ///             if no `PrometheusClient` was used to bootstrap `MetricsSystem`
    static func prometheus() throws -> PrometheusClient {
        guard let prom = self.factory as? PrometheusClient else {
            throw PrometheusError.PrometheusFactoryNotBootstrapped
        }
        return prom
    }
}

// MARK: - Labels

/// A generic `String` based `CodingKey` implementation.
fileprivate struct StringCodingKey: CodingKey {
    /// `CodingKey` conformance.
    public var stringValue: String
    
    /// `CodingKey` conformance.
    public var intValue: Int? {
        return Int(self.stringValue)
    }
    
    /// Creates a new `StringCodingKey`.
    public init(_ string: String) {
        self.stringValue = string
    }
    
    /// `CodingKey` conformance.
    public init(stringValue: String) {
        self.stringValue = stringValue
    }
    
    /// `CodingKey` conformance.
    public init(intValue: Int) {
        self.stringValue = intValue.description
    }
}



/// Helper for dimensions
internal struct DimensionLabels: MetricLabels {
    let dimensions: [(String, String)]
    
    init() {
        self.dimensions = []
    }
    
    init(_ dimensions: [(String, String)]) {
        self.dimensions = dimensions
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        try self.dimensions.forEach {
            try container.encode($0.1, forKey: .init($0.0))
        }
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(dimensions.map { "\($0.0)-\($0.1)"})
    }
    
    fileprivate var identifiers: String {
        return dimensions.map { $0.0 }.joined(separator: "-")
    }
    
    static func == (lhs: DimensionLabels, rhs: DimensionLabels) -> Bool {
        return lhs.dimensions.map { "\($0.0)-\($0.1)"} == rhs.dimensions.map { "\($0.0)-\($0.1)"}
    }
}

/// Helper for dimensions
internal struct DimensionHistogramLabels: HistogramLabels {
    /// Bucket
    var le: String
    /// Dimensions
    let dimensions: [(String, String)]
    
    /// Empty init
    init() {
        self.le = ""
        self.dimensions = []
    }
    
    /// Init with dimensions
    init(_ dimensions: [(String, String)]) {
        self.le = ""
        self.dimensions = dimensions
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        try self.dimensions.forEach {
            try container.encode($0.1, forKey: .init($0.0))
        }
        try container.encode(le, forKey: .init("le"))
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(dimensions.map { "\($0.0)-\($0.1)"})
        hasher.combine(le)
    }
    
    fileprivate var identifiers: String {
        return dimensions.map { $0.0 }.joined(separator: "-")
    }
    
    static func == (lhs: DimensionHistogramLabels, rhs: DimensionHistogramLabels) -> Bool {
        return lhs.dimensions.map { "\($0.0)-\($0.1)"} == rhs.dimensions.map { "\($0.0)-\($0.1)"} && rhs.le == lhs.le
    }
}

/// Helper for dimensions
internal struct DimensionSummaryLabels: SummaryLabels {
    /// Quantile
    var quantile: String
    /// Dimensions
    let dimensions: [(String, String)]
    
    /// Empty init
    init() {
        self.quantile = ""
        self.dimensions = []
    }
    
    /// Init with dimensions
    init(_ dimensions: [(String, String)]) {
        self.quantile = ""
        self.dimensions = dimensions
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        try self.dimensions.forEach {
            try container.encode($0.1, forKey: .init($0.0))
        }
        try container.encode(quantile, forKey: .init("quantile"))
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(dimensions.map { "\($0.0)-\($0.1)"})
        hasher.combine(quantile)
    }
    
    fileprivate var identifiers: String {
        return dimensions.map { $0.0 }.joined(separator: "-")
    }
    
    static func == (lhs: DimensionSummaryLabels, rhs: DimensionSummaryLabels) -> Bool {
        return lhs.dimensions.map { "\($0.0)-\($0.1)"} == rhs.dimensions.map { "\($0.0)-\($0.1)"} && rhs.quantile == lhs.quantile
    }
}