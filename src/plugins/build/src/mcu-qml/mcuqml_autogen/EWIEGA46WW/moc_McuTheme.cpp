/****************************************************************************
** Meta object code from reading C++ file 'McuTheme.h'
**
** Created by: The Qt Meta Object Compiler version 69 (Qt 6.10.1)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../../../../../src/mcu-qml/McuTheme.h"
#include <QtCore/qmetatype.h>

#include <QtCore/qtmochelpers.h>

#include <memory>


#include <QtCore/qxptype_traits.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'McuTheme.h' doesn't include <QObject>."
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
struct qt_meta_tag_ZN8McuThemeE_t {};
} // unnamed namespace

template <> constexpr inline auto McuTheme::qt_create_metaobjectdata<qt_meta_tag_ZN8McuThemeE_t>()
{
    namespace QMC = QtMocConstants;
    QtMocHelpers::StringRefStorage qt_stringData {
        "McuTheme",
        "QML.Element",
        "auto",
        "sourceChanged",
        "",
        "darkModeChanged",
        "variantChanged",
        "contrastChanged",
        "colorsChanged",
        "validChanged",
        "loadingChanged",
        "setSource",
        "QVariant",
        "v",
        "setDarkMode",
        "dark",
        "setVariant",
        "variant",
        "setContrast",
        "contrast",
        "source",
        "darkMode",
        "colors",
        "QVariantMap",
        "valid",
        "loading"
    };

    QtMocHelpers::UintData qt_methods {
        // Signal 'sourceChanged'
        QtMocHelpers::SignalData<void()>(3, 4, QMC::AccessPublic, QMetaType::Void),
        // Signal 'darkModeChanged'
        QtMocHelpers::SignalData<void()>(5, 4, QMC::AccessPublic, QMetaType::Void),
        // Signal 'variantChanged'
        QtMocHelpers::SignalData<void()>(6, 4, QMC::AccessPublic, QMetaType::Void),
        // Signal 'contrastChanged'
        QtMocHelpers::SignalData<void()>(7, 4, QMC::AccessPublic, QMetaType::Void),
        // Signal 'colorsChanged'
        QtMocHelpers::SignalData<void()>(8, 4, QMC::AccessPublic, QMetaType::Void),
        // Signal 'validChanged'
        QtMocHelpers::SignalData<void()>(9, 4, QMC::AccessPublic, QMetaType::Void),
        // Signal 'loadingChanged'
        QtMocHelpers::SignalData<void()>(10, 4, QMC::AccessPublic, QMetaType::Void),
        // Method 'setSource'
        QtMocHelpers::MethodData<void(const QVariant &)>(11, 4, QMC::AccessPublic, QMetaType::Void, {{
            { 0x80000000 | 12, 13 },
        }}),
        // Method 'setDarkMode'
        QtMocHelpers::MethodData<void(bool)>(14, 4, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::Bool, 15 },
        }}),
        // Method 'setVariant'
        QtMocHelpers::MethodData<void(const QString &)>(16, 4, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 17 },
        }}),
        // Method 'setContrast'
        QtMocHelpers::MethodData<void(double)>(18, 4, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::Double, 19 },
        }}),
    };
    QtMocHelpers::UintData qt_properties {
        // property 'source'
        QtMocHelpers::PropertyData<QVariant>(20, 0x80000000 | 12, QMC::DefaultPropertyFlags | QMC::Writable | QMC::EnumOrFlag | QMC::StdCppSet, 0),
        // property 'darkMode'
        QtMocHelpers::PropertyData<bool>(21, QMetaType::Bool, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 1),
        // property 'variant'
        QtMocHelpers::PropertyData<QString>(17, QMetaType::QString, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 2),
        // property 'contrast'
        QtMocHelpers::PropertyData<double>(19, QMetaType::Double, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 3),
        // property 'colors'
        QtMocHelpers::PropertyData<QVariantMap>(22, 0x80000000 | 23, QMC::DefaultPropertyFlags | QMC::EnumOrFlag, 4),
        // property 'valid'
        QtMocHelpers::PropertyData<bool>(24, QMetaType::Bool, QMC::DefaultPropertyFlags, 5),
        // property 'loading'
        QtMocHelpers::PropertyData<bool>(25, QMetaType::Bool, QMC::DefaultPropertyFlags, 6),
    };
    QtMocHelpers::UintData qt_enums {
    };
    QtMocHelpers::UintData qt_constructors {};
    QtMocHelpers::ClassInfos qt_classinfo({
            {    1,    2 },
    });
    return QtMocHelpers::metaObjectData<McuTheme, void>(QMC::MetaObjectFlag{}, qt_stringData,
            qt_methods, qt_properties, qt_enums, qt_constructors, qt_classinfo);
}
Q_CONSTINIT const QMetaObject McuTheme::staticMetaObject = { {
    QMetaObject::SuperData::link<QObject::staticMetaObject>(),
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN8McuThemeE_t>.stringdata,
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN8McuThemeE_t>.data,
    qt_static_metacall,
    nullptr,
    qt_staticMetaObjectRelocatingContent<qt_meta_tag_ZN8McuThemeE_t>.metaTypes,
    nullptr
} };

void McuTheme::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    auto *_t = static_cast<McuTheme *>(_o);
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: _t->sourceChanged(); break;
        case 1: _t->darkModeChanged(); break;
        case 2: _t->variantChanged(); break;
        case 3: _t->contrastChanged(); break;
        case 4: _t->colorsChanged(); break;
        case 5: _t->validChanged(); break;
        case 6: _t->loadingChanged(); break;
        case 7: _t->setSource((*reinterpret_cast<std::add_pointer_t<QVariant>>(_a[1]))); break;
        case 8: _t->setDarkMode((*reinterpret_cast<std::add_pointer_t<bool>>(_a[1]))); break;
        case 9: _t->setVariant((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 10: _t->setContrast((*reinterpret_cast<std::add_pointer_t<double>>(_a[1]))); break;
        default: ;
        }
    }
    if (_c == QMetaObject::IndexOfMethod) {
        if (QtMocHelpers::indexOfMethod<void (McuTheme::*)()>(_a, &McuTheme::sourceChanged, 0))
            return;
        if (QtMocHelpers::indexOfMethod<void (McuTheme::*)()>(_a, &McuTheme::darkModeChanged, 1))
            return;
        if (QtMocHelpers::indexOfMethod<void (McuTheme::*)()>(_a, &McuTheme::variantChanged, 2))
            return;
        if (QtMocHelpers::indexOfMethod<void (McuTheme::*)()>(_a, &McuTheme::contrastChanged, 3))
            return;
        if (QtMocHelpers::indexOfMethod<void (McuTheme::*)()>(_a, &McuTheme::colorsChanged, 4))
            return;
        if (QtMocHelpers::indexOfMethod<void (McuTheme::*)()>(_a, &McuTheme::validChanged, 5))
            return;
        if (QtMocHelpers::indexOfMethod<void (McuTheme::*)()>(_a, &McuTheme::loadingChanged, 6))
            return;
    }
    if (_c == QMetaObject::ReadProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 0: *reinterpret_cast<QVariant*>(_v) = _t->source(); break;
        case 1: *reinterpret_cast<bool*>(_v) = _t->darkMode(); break;
        case 2: *reinterpret_cast<QString*>(_v) = _t->variant(); break;
        case 3: *reinterpret_cast<double*>(_v) = _t->contrast(); break;
        case 4: *reinterpret_cast<QVariantMap*>(_v) = _t->colors(); break;
        case 5: *reinterpret_cast<bool*>(_v) = _t->valid(); break;
        case 6: *reinterpret_cast<bool*>(_v) = _t->loading(); break;
        default: break;
        }
    }
    if (_c == QMetaObject::WriteProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 0: _t->setSource(*reinterpret_cast<QVariant*>(_v)); break;
        case 1: _t->setDarkMode(*reinterpret_cast<bool*>(_v)); break;
        case 2: _t->setVariant(*reinterpret_cast<QString*>(_v)); break;
        case 3: _t->setContrast(*reinterpret_cast<double*>(_v)); break;
        default: break;
        }
    }
}

const QMetaObject *McuTheme::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *McuTheme::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_staticMetaObjectStaticContent<qt_meta_tag_ZN8McuThemeE_t>.strings))
        return static_cast<void*>(this);
    return QObject::qt_metacast(_clname);
}

int McuTheme::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        if (_id < 11)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 11;
    }
    if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        if (_id < 11)
            *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType();
        _id -= 11;
    }
    if (_c == QMetaObject::ReadProperty || _c == QMetaObject::WriteProperty
            || _c == QMetaObject::ResetProperty || _c == QMetaObject::BindableProperty
            || _c == QMetaObject::RegisterPropertyMetaType) {
        qt_static_metacall(this, _c, _id, _a);
        _id -= 7;
    }
    return _id;
}

// SIGNAL 0
void McuTheme::sourceChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 0, nullptr);
}

// SIGNAL 1
void McuTheme::darkModeChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 1, nullptr);
}

// SIGNAL 2
void McuTheme::variantChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 2, nullptr);
}

// SIGNAL 3
void McuTheme::contrastChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 3, nullptr);
}

// SIGNAL 4
void McuTheme::colorsChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 4, nullptr);
}

// SIGNAL 5
void McuTheme::validChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 5, nullptr);
}

// SIGNAL 6
void McuTheme::loadingChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 6, nullptr);
}
QT_WARNING_POP
