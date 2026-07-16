# Shared install logic for all QML plugin modules.
#
# plugin_install(<target>) installs the module (plugin .so + qmldir +
# typeinfo) under INSTALL_QMLDIR. The default is the ABSOLUTE system QML
# path, so plain `cmake -B build && cmake --install build` lands in the
# right place; with -DCMAKE_INSTALL_PREFIX=/ the old relative form
# produced /usr/local/usr/lib/... on default prefixes.
set(INSTALL_QMLDIR "/usr/lib/qt6/qml" CACHE STRING "QML modules install dir")

function(plugin_install target)
    qt_query_qml_module(${target}
        URI module_uri
        VERSION module_version
        PLUGIN_TARGET module_plugin_target
        TARGET_PATH module_target_path
        QMLDIR module_qmldir
        TYPEINFO module_typeinfo
    )

    message(STATUS "Created QML module ${module_uri}, version ${module_version}")

    set(module_dir "${INSTALL_QMLDIR}/${module_target_path}")
    # The backing target IS the plugin target (PLUGIN_TARGET == target),
    # so a single install(TARGETS) suffices — the old per-plugin copies
    # installed the same file twice.
    install(TARGETS ${target} LIBRARY DESTINATION "${module_dir}" RUNTIME DESTINATION "${module_dir}")
    install(FILES "${module_qmldir}" DESTINATION "${module_dir}")
    install(FILES "${module_typeinfo}" DESTINATION "${module_dir}")
endfunction()
