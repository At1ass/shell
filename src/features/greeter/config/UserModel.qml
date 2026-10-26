pragma Singleton
import Quickshell
import GreeterData 1.0

Singleton {
    readonly property var users: GreeterDataBackend.users
    readonly property list<string> names: GreeterDataBackend.userNames
    readonly property int count: users.length
    readonly property bool ready: GreeterDataBackend.ready
    function indexOfUser(username) { return GreeterDataBackend.userIndex(username) }
}
