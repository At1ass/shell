#include <QtQml/qqmlextensionplugin.h>
#include <QtQml/qqml.h>
#include "McuTheme.h"

class McuPlugin : public QQmlExtensionPlugin {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlExtensionInterface_iid)
public:
    void registerTypes(const char* uri) override {
        qmlRegisterType<McuTheme>(uri, 1, 0, "Theme");
    }
};
#include "plugin.moc"
