import Testing
@testable import Folita

@MainActor
struct AppEnvironmentTests {
    /// 识别失败会让测试宿主监听系统剪贴板并写入真实历史库。
    @Test func detectsTestHost() {
        #expect(AppEnvironment.isRunningTests)
    }
}
