/****************************************************************************
** Meta object code from reading C++ file 'SystemMonitor.h'
**
** Created by: The Qt Meta Object Compiler version 69 (Qt 6.10.1)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../../../../../src/system-monitor-qml/SystemMonitor.h"
#include <QtCore/qmetatype.h>

#include <QtCore/qtmochelpers.h>

#include <memory>


#include <QtCore/qxptype_traits.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'SystemMonitor.h' doesn't include <QObject>."
#elif Q_MOC_OUTPUT_REVISION != 69
#error "This file was generated using the moc from 6.10.1. It"
#error "cannot be used with the include files from this version of Qt."
#error "(The moc has changed too much.)"
#endif

#ifndef Q_CONSTINIT
#define Q_CONSTINIT
#endif

QT_WARNING_PUSH
QT_WARNING_DISABLE_DEPRECATED
QT_WARNING_DISABLE_GCC("-Wuseless-cast")
namespace {
struct qt_meta_tag_ZN13SystemMonitorE_t {};
} // unnamed namespace

template <> constexpr inline auto SystemMonitor::qt_create_metaobjectdata<qt_meta_tag_ZN13SystemMonitorE_t>()
{
    namespace QMC = QtMocConstants;
    QtMocHelpers::StringRefStorage qt_stringData {
        "SystemMonitor",
        "QML.Element",
        "auto",
        "QML.Singleton",
        "true",
        "cpuUsageChanged",
        "",
        "cpuTempChanged",
        "cpuModelChanged",
        "ramUsageChanged",
        "ramUsedChanged",
        "ramTotalChanged",
        "gpuUsageChanged",
        "gpuTempChanged",
        "gpuModelChanged",
        "diskUsageChanged",
        "diskUsedChanged",
        "diskTotalChanged",
        "userNameChanged",
        "isMonitoringChanged",
        "hasCpuTempChanged",
        "hasGpuStatsChanged",
        "statsUpdated",
        "errorOccurred",
        "message",
        "setUpdateInterval",
        "milliseconds",
        "refresh",
        "handleSnapshot",
        "StatsSnapshot",
        "snapshot",
        "cpuUsage",
        "cpuTemp",
        "cpuModel",
        "ramUsage",
        "ramUsed",
        "ramTotal",
        "gpuUsage",
        "gpuTemp",
        "gpuModel",
        "diskUsage",
        "diskUsed",
        "diskTotal",
        "userName",
        "osName",
        "wmName",
        "isMonitoring",
        "hasCpuTemp",
        "hasGpuStats"
    };

    QtMocHelpers::UintData qt_methods {
        // Signal 'cpuUsageChanged'
        QtMocHelpers::SignalData<void()>(5, 6, QMC::AccessPublic, QMetaType::Void),
        // Signal 'cpuTempChanged'
        QtMocHelpers::SignalData<void()>(7, 6, QMC::AccessPublic, QMetaType::Void),
        // Signal 'cpuModelChanged'
        QtMocHelpers::SignalData<void()>(8, 6, QMC::AccessPublic, QMetaType::Void),
        // Signal 'ramUsageChanged'
        QtMocHelpers::SignalData<void()>(9, 6, QMC::AccessPublic, QMetaType::Void),
        // Signal 'ramUsedChanged'
        QtMocHelpers::SignalData<void()>(10, 6, QMC::AccessPublic, QMetaType::Void),
        // Signal 'ramTotalChanged'
        QtMocHelpers::SignalData<void()>(11, 6, QMC::AccessPublic, QMetaType::Void),
        // Signal 'gpuUsageChanged'
        QtMocHelpers::SignalData<void()>(12, 6, QMC::AccessPublic, QMetaType::Void),
        // Signal 'gpuTempChanged'
        QtMocHelpers::SignalData<void()>(13, 6, QMC::AccessPublic, QMetaType::Void),
        // Signal 'gpuModelChanged'
        QtMocHelpers::SignalData<void()>(14, 6, QMC::AccessPublic, QMetaType::Void),
        // Signal 'diskUsageChanged'
        QtMocHelpers::SignalData<void()>(15, 6, QMC::AccessPublic, QMetaType::Void),
        // Signal 'diskUsedChanged'
        QtMocHelpers::SignalData<void()>(16, 6, QMC::AccessPublic, QMetaType::Void),
        // Signal 'diskTotalChanged'
        QtMocHelpers::SignalData<void()>(17, 6, QMC::AccessPublic, QMetaType::Void),
        // Signal 'userNameChanged'
        QtMocHelpers::SignalData<void()>(18, 6, QMC::AccessPublic, QMetaType::Void),
        // Signal 'isMonitoringChanged'
        QtMocHelpers::SignalData<void()>(19, 6, QMC::AccessPublic, QMetaType::Void),
        // Signal 'hasCpuTempChanged'
        QtMocHelpers::SignalData<void()>(20, 6, QMC::AccessPublic, QMetaType::Void),
        // Signal 'hasGpuStatsChanged'
        QtMocHelpers::SignalData<void()>(21, 6, QMC::AccessPublic, QMetaType::Void),
        // Signal 'statsUpdated'
        QtMocHelpers::SignalData<void()>(22, 6, QMC::AccessPublic, QMetaType::Void),
        // Signal 'errorOccurred'
        QtMocHelpers::SignalData<void(const QString &)>(23, 6, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 24 },
        }}),
        // Slot 'setUpdateInterval'
        QtMocHelpers::SlotData<void(int)>(25, 6, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::Int, 26 },
        }}),
        // Slot 'refresh'
        QtMocHelpers::SlotData<void()>(27, 6, QMC::AccessPublic, QMetaType::Void),
        // Slot 'handleSnapshot'
        QtMocHelpers::SlotData<void(const StatsSnapshot &)>(28, 6, QMC::AccessPrivate, QMetaType::Void, {{
            { 0x80000000 | 29, 30 },
        }}),
    };
    QtMocHelpers::UintData qt_properties {
        // property 'cpuUsage'
        QtMocHelpers::PropertyData<qreal>(31, QMetaType::QReal, QMC::DefaultPropertyFlags, 0),
        // property 'cpuTemp'
        QtMocHelpers::PropertyData<int>(32, QMetaType::Int, QMC::DefaultPropertyFlags, 1),
        // property 'cpuModel'
        QtMocHelpers::PropertyData<QString>(33, QMetaType::QString, QMC::DefaultPropertyFlags, 2),
        // property 'ramUsage'
        QtMocHelpers::PropertyData<qreal>(34, QMetaType::QReal, QMC::DefaultPropertyFlags, 3),
        // property 'ramUsed'
        QtMocHelpers::PropertyData<QString>(35, QMetaType::QString, QMC::DefaultPropertyFlags, 4),
        // property 'ramTotal'
        QtMocHelpers::PropertyData<QString>(36, QMetaType::QString, QMC::DefaultPropertyFlags, 5),
        // property 'gpuUsage'
        QtMocHelpers::PropertyData<int>(37, QMetaType::Int, QMC::DefaultPropertyFlags, 6),
        // property 'gpuTemp'
        QtMocHelpers::PropertyData<int>(38, QMetaType::Int, QMC::DefaultPropertyFlags, 7),
        // property 'gpuModel'
        QtMocHelpers::PropertyData<QString>(39, QMetaType::QString, QMC::DefaultPropertyFlags, 8),
        // property 'diskUsage'
        QtMocHelpers::PropertyData<qreal>(40, QMetaType::QReal, QMC::DefaultPropertyFlags, 9),
        // property 'diskUsed'
        QtMocHelpers::PropertyData<QString>(41, QMetaType::QString, QMC::DefaultPropertyFlags, 10),
        // property 'diskTotal'
        QtMocHelpers::PropertyData<QString>(42, QMetaType::QString, QMC::DefaultPropertyFlags, 11),
        // property 'userName'
        QtMocHelpers::PropertyData<QString>(43, QMetaType::QString, QMC::DefaultPropertyFlags, 12),
        // property 'osName'
        QtMocHelpers::PropertyData<QString>(44, QMetaType::QString, QMC::DefaultPropertyFlags | QMC::Constant),
        // property 'wmName'
        QtMocHelpers::PropertyData<QString>(45, QMetaType::QString, QMC::DefaultPropertyFlags | QMC::Constant),
        // property 'isMonitoring'
        QtMocHelpers::PropertyData<bool>(46, QMetaType::Bool, QMC::DefaultPropertyFlags, 13),
        // property 'hasCpuTemp'
        QtMocHelpers::PropertyData<bool>(47, QMetaType::Bool, QMC::DefaultPropertyFlags, 14),
        // property 'hasGpuStats'
        QtMocHelpers::PropertyData<bool>(48, QMetaType::Bool, QMC::DefaultPropertyFlags, 15),
    };
    QtMocHelpers::UintData qt_enums {
    };
    QtMocHelpers::UintData qt_constructors {};
    QtMocHelpers::ClassInfos qt_classinfo({
            {    1,    2 },
            {    3,    4 },
    });
    return QtMocHelpers::metaObjectData<SystemMonitor, void>(QMC::MetaObjectFlag{}, qt_stringData,
            qt_methods, qt_properties, qt_enums, qt_constructors, qt_classinfo);
}
Q_CONSTINIT const QMetaObject SystemMonitor::staticMetaObject = { {
    QMetaObject::SuperData::link<QObject::staticMetaObject>(),
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN13SystemMonitorE_t>.stringdata,
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN13SystemMonitorE_t>.data,
    qt_static_metacall,
    nullptr,
    qt_staticMetaObjectRelocatingContent<qt_meta_tag_ZN13SystemMonitorE_t>.metaTypes,
    nullptr
} };

void SystemMonitor::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    auto *_t = static_cast<SystemMonitor *>(_o);
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: _t->cpuUsageChanged(); break;
        case 1: _t->cpuTempChanged(); break;
        case 2: _t->cpuModelChanged(); break;
        case 3: _t->ramUsageChanged(); break;
        case 4: _t->ramUsedChanged(); break;
        case 5: _t->ramTotalChanged(); break;
        case 6: _t->gpuUsageChanged(); break;
        case 7: _t->gpuTempChanged(); break;
        case 8: _t->gpuModelChanged(); break;
        case 9: _t->diskUsageChanged(); break;
        case 10: _t->diskUsedChanged(); break;
        case 11: _t->diskTotalChanged(); break;
        case 12: _t->userNameChanged(); break;
        case 13: _t->isMonitoringChanged(); break;
        case 14: _t->hasCpuTempChanged(); break;
        case 15: _t->hasGpuStatsChanged(); break;
        case 16: _t->statsUpdated(); break;
        case 17: _t->errorOccurred((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 18: _t->setUpdateInterval((*reinterpret_cast<std::add_pointer_t<int>>(_a[1]))); break;
        case 19: _t->refresh(); break;
        case 20: _t->handleSnapshot((*reinterpret_cast<std::add_pointer_t<StatsSnapshot>>(_a[1]))); break;
        default: ;
        }
    }
    if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        switch (_id) {
        default: *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType(); break;
        case 20:
            switch (*reinterpret_cast<int*>(_a[1])) {
            default: *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType(); break;
            case 0:
                *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType::fromType< StatsSnapshot >(); break;
            }
            break;
        }
    }
    if (_c == QMetaObject::IndexOfMethod) {
        if (QtMocHelpers::indexOfMethod<void (SystemMonitor::*)()>(_a, &SystemMonitor::cpuUsageChanged, 0))
            return;
        if (QtMocHelpers::indexOfMethod<void (SystemMonitor::*)()>(_a, &SystemMonitor::cpuTempChanged, 1))
            return;
        if (QtMocHelpers::indexOfMethod<void (SystemMonitor::*)()>(_a, &SystemMonitor::cpuModelChanged, 2))
            return;
        if (QtMocHelpers::indexOfMethod<void (SystemMonitor::*)()>(_a, &SystemMonitor::ramUsageChanged, 3))
            return;
        if (QtMocHelpers::indexOfMethod<void (SystemMonitor::*)()>(_a, &SystemMonitor::ramUsedChanged, 4))
            return;
        if (QtMocHelpers::indexOfMethod<void (SystemMonitor::*)()>(_a, &SystemMonitor::ramTotalChanged, 5))
            return;
        if (QtMocHelpers::indexOfMethod<void (SystemMonitor::*)()>(_a, &SystemMonitor::gpuUsageChanged, 6))
            return;
        if (QtMocHelpers::indexOfMethod<void (SystemMonitor::*)()>(_a, &SystemMonitor::gpuTempChanged, 7))
            return;
        if (QtMocHelpers::indexOfMethod<void (SystemMonitor::*)()>(_a, &SystemMonitor::gpuModelChanged, 8))
            return;
        if (QtMocHelpers::indexOfMethod<void (SystemMonitor::*)()>(_a, &SystemMonitor::diskUsageChanged, 9))
            return;
        if (QtMocHelpers::indexOfMethod<void (SystemMonitor::*)()>(_a, &SystemMonitor::diskUsedChanged, 10))
            return;
        if (QtMocHelpers::indexOfMethod<void (SystemMonitor::*)()>(_a, &SystemMonitor::diskTotalChanged, 11))
            return;
        if (QtMocHelpers::indexOfMethod<void (SystemMonitor::*)()>(_a, &SystemMonitor::userNameChanged, 12))
            return;
        if (QtMocHelpers::indexOfMethod<void (SystemMonitor::*)()>(_a, &SystemMonitor::isMonitoringChanged, 13))
            return;
        if (QtMocHelpers::indexOfMethod<void (SystemMonitor::*)()>(_a, &SystemMonitor::hasCpuTempChanged, 14))
            return;
        if (QtMocHelpers::indexOfMethod<void (SystemMonitor::*)()>(_a, &SystemMonitor::hasGpuStatsChanged, 15))
            return;
        if (QtMocHelpers::indexOfMethod<void (SystemMonitor::*)()>(_a, &SystemMonitor::statsUpdated, 16))
            return;
        if (QtMocHelpers::indexOfMethod<void (SystemMonitor::*)(const QString & )>(_a, &SystemMonitor::errorOccurred, 17))
            return;
    }
    if (_c == QMetaObject::ReadProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 0: *reinterpret_cast<qreal*>(_v) = _t->cpuUsage(); break;
        case 1: *reinterpret_cast<int*>(_v) = _t->cpuTemp(); break;
        case 2: *reinterpret_cast<QString*>(_v) = _t->cpuModel(); break;
        case 3: *reinterpret_cast<qreal*>(_v) = _t->ramUsage(); break;
        case 4: *reinterpret_cast<QString*>(_v) = _t->ramUsed(); break;
        case 5: *reinterpret_cast<QString*>(_v) = _t->ramTotal(); break;
        case 6: *reinterpret_cast<int*>(_v) = _t->gpuUsage(); break;
        case 7: *reinterpret_cast<int*>(_v) = _t->gpuTemp(); break;
        case 8: *reinterpret_cast<QString*>(_v) = _t->gpuModel(); break;
        case 9: *reinterpret_cast<qreal*>(_v) = _t->diskUsage(); break;
        case 10: *reinterpret_cast<QString*>(_v) = _t->diskUsed(); break;
        case 11: *reinterpret_cast<QString*>(_v) = _t->diskTotal(); break;
        case 12: *reinterpret_cast<QString*>(_v) = _t->userName(); break;
        case 13: *reinterpret_cast<QString*>(_v) = _t->osName(); break;
        case 14: *reinterpret_cast<QString*>(_v) = _t->wmName(); break;
        case 15: *reinterpret_cast<bool*>(_v) = _t->isMonitoring(); break;
        case 16: *reinterpret_cast<bool*>(_v) = _t->hasCpuTemp(); break;
        case 17: *reinterpret_cast<bool*>(_v) = _t->hasGpuStats(); break;
        default: break;
        }
    }
}

const QMetaObject *SystemMonitor::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *SystemMonitor::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_staticMetaObjectStaticContent<qt_meta_tag_ZN13SystemMonitorE_t>.strings))
        return static_cast<void*>(this);
    return QObject::qt_metacast(_clname);
}

int SystemMonitor::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        if (_id < 21)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 21;
    }
    if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        if (_id < 21)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 21;
    }
    if (_c == QMetaObject::ReadProperty || _c == QMetaObject::WriteProperty
            || _c == QMetaObject::ResetProperty || _c == QMetaObject::BindableProperty
            || _c == QMetaObject::RegisterPropertyMetaType) {
        qt_static_metacall(this, _c, _id, _a);
        _id -= 18;
    }
    return _id;
}

// SIGNAL 0
void SystemMonitor::cpuUsageChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 0, nullptr);
}

// SIGNAL 1
void SystemMonitor::cpuTempChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 1, nullptr);
}

// SIGNAL 2
void SystemMonitor::cpuModelChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 2, nullptr);
}

// SIGNAL 3
void SystemMonitor::ramUsageChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 3, nullptr);
}

// SIGNAL 4
void SystemMonitor::ramUsedChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 4, nullptr);
}

// SIGNAL 5
void SystemMonitor::ramTotalChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 5, nullptr);
}

// SIGNAL 6
void SystemMonitor::gpuUsageChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 6, nullptr);
}

// SIGNAL 7
void SystemMonitor::gpuTempChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 7, nullptr);
}

// SIGNAL 8
void SystemMonitor::gpuModelChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 8, nullptr);
}

// SIGNAL 9
void SystemMonitor::diskUsageChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 9, nullptr);
}

// SIGNAL 10
void SystemMonitor::diskUsedChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 10, nullptr);
}

// SIGNAL 11
void SystemMonitor::diskTotalChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 11, nullptr);
}

// SIGNAL 12
void SystemMonitor::userNameChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 12, nullptr);
}

// SIGNAL 13
void SystemMonitor::isMonitoringChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 13, nullptr);
}

// SIGNAL 14
void SystemMonitor::hasCpuTempChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 14, nullptr);
}

// SIGNAL 15
void SystemMonitor::hasGpuStatsChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 15, nullptr);
}

// SIGNAL 16
void SystemMonitor::statsUpdated()
{
    QMetaObject::activate(this, &staticMetaObject, 16, nullptr);
}

// SIGNAL 17
void SystemMonitor::errorOccurred(const QString & _t1)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 17, nullptr, _t1);
}
QT_WARNING_POP
