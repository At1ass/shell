import Connectivity 1.0
import qs.src.core.config
import qs.src.core.services

NetworkSecretAgent {
    enabled: AppConfig.moduleEnabled("connections") && AppConfig.networkAgentEnabled
    blocked: GlobalStates.lockscreenActive
    timeoutMs: AppConfig.networkAuthenticationTimeout * 1000
}
