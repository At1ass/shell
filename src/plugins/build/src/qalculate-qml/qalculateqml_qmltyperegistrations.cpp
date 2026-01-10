/****************************************************************************
** Generated QML type registration code
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include <QtQml/qqml.h>
#include <QtQml/qqmlmoduleregistration.h>

#if __has_include(<QalculateWrapper.h>)
#  include <QalculateWrapper.h>
#endif


#if !defined(QT_STATIC)
#define Q_QMLTYPE_EXPORT Q_DECL_EXPORT
#else
#define Q_QMLTYPE_EXPORT
#endif
Q_QMLTYPE_EXPORT void qml_register_types_Qalculate()
{
    QT_WARNING_PUSH QT_WARNING_DISABLE_DEPRECATED
    qmlRegisterTypesAndRevisions<QalculateWrapper>("Qalculate", 1);
    QT_WARNING_POP
    qmlRegisterModule("Qalculate", 1, 0);
}

static const QQmlModuleRegistration qalculateRegistration("Qalculate", qml_register_types_Qalculate);
