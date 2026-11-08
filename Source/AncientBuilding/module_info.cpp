#include "AncientBuilding/module_info.h"

#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void AncientBuildingModule::_bind_methods() {
    ClassDB::bind_method(D_METHOD("get_version"), &AncientBuildingModule::get_version);
}

String AncientBuildingModule::get_version() const {
    return "0.1.0";
}