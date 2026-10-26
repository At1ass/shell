#pragma once
#include <QObject>

class GreeterDataTests : public QObject {
    Q_OBJECT
private slots:
    void quotedArgumentsAndEscapes();
    void shellSyntaxIsNeverExecuted();
    void fieldCodesAndOnePassExpansion();
    void invalidCommands_data();
    void invalidCommands();
    void filtersAndTryExec();
    void localeAndGroupIsolation();
    void duplicateEntryAndMasking();
    void malformedAndBoundedFiles();
    void localUsers();
    void asynchronousPublicationAndReload();
    void facadeMayDieWhileWorkerFinishes();
};
