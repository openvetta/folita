import Foundation

enum AppEnvironment {
    /// 单元测试以本应用为宿主进程运行。此时不能监听系统剪贴板、不能读写真实的历史库，
    /// 测试需要的服务由各测试自行注入隔离实例。
    static let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
}
