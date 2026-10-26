import Connectivity 1.0
import qs.src.core.config
import qs.src.core.services

BluetoothPairingAgent {
    enabled: AppConfig.moduleEnabled("connections") && AppConfig.bluetoothAgentEnabled
    blocked: GlobalStates.lockscreenActive || !BluetoothService.enabled
        || !GlobalStates.connectionsOpen || GlobalStates.connectionsSection !== "bluetooth"
    timeoutMs: AppConfig.bluetoothPairingTimeout * 1000
}
