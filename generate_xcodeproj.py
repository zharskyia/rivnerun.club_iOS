from pathlib import Path
from uuid import uuid4

root = Path(r"C:\git\rivnerun.club_iOS")


def make_id(prefix: str) -> str:
    return f"{prefix}{uuid4().hex[:12].upper()}"


project_name = "RivneRunningClubApp"
files = [
    "AppTheme.swift",
    "ClubSiteRepository.swift",
    "ContentView.swift",
    "Models.swift",
    "NativePages.swift",
    "RivneRunningClubApp.swift",
    "ScrapeConfig.swift",
    "TrainingSchedule.swift",
]

project_obj_id = make_id("PBXPROJ")
main_group_id = make_id("PBXGROUP")
app_group_id = make_id("APPGROUP")
products_group_id = make_id("PRODGROUP")
frameworks_group_id = make_id("FRAMEWORKS")
target_id = make_id("TARGET")
config_list_id = make_id("CONFIGLIST")
project_config_list_id = make_id("PROJECTCFG")
debug_conf_id = make_id("DEBUGCFG")
release_conf_id = make_id("RELEASECFG")
source_phase_id = make_id("SOURCEPHASE")
resources_phase_id = make_id("RESOURCEPHASE")
frameworks_phase_id = make_id("FRAMEPHASE")
product_ref_id = make_id("PRODUCTREF")
plist_ref_id = make_id("PLISTREF")

file_refs = {}
build_file_ids = []
for f in files:
    file_ref_id = make_id("FILEREF")
    file_refs[f] = file_ref_id
    build_file_ids.append(make_id("BUILDFILE"))

object_lines = []
for f in files:
    object_lines.append(
        "\t\t" + file_refs[f] + " /* " + f + " */ = { isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = " + f + "; sourceTree = \"<group>\"; };"
    )
object_lines.append(
    "\t\t" + plist_ref_id + " /* Info.plist */ = { isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = \"<group>\"; };"
)
object_lines.append(
    "\t\t" + product_ref_id + " /* RivneRunningClubApp.app */ = { isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = " + project_name + ".app; sourceTree = BUILT_PRODUCTS_DIR; };"
)

object_lines.append(
    "\t\t" + main_group_id + " /* Project */ = { isa = PBXGroup; children = (\n"
    "\t\t\t" + app_group_id + " /* " + project_name + " */,\n"
    "\t\t\t" + products_group_id + " /* Products */,\n"
    "\t\t\t" + frameworks_group_id + " /* Frameworks */\n"
    "\t\t); sourceTree = \"<group>\"; };"
)

children = [
    "\t\t\t" + file_refs[f] + " /* " + f + " */" for f in files
]
children.append("\t\t\t" + plist_ref_id + " /* Info.plist */")
object_lines.append(
    "\t\t" + app_group_id + " /* " + project_name + " */ = { isa = PBXGroup; children = (\n"
    + ",\n".join(children) + "\n\t\t); path = " + project_name + "; sourceTree = \"<group>\"; };"
)
object_lines.append(
    "\t\t" + products_group_id + " /* Products */ = { isa = PBXGroup; children = (\n"
    "\t\t\t" + product_ref_id + " /* " + project_name + ".app */\n"
    "\t\t); sourceTree = \"<group>\"; };"
)
object_lines.append(
    "\t\t" + frameworks_group_id + " /* Frameworks */ = { isa = PBXGroup; children = (); sourceTree = \"<group>\"; };"
)

for i, f in enumerate(files):
    object_lines.append(
        "\t\t" + build_file_ids[i] + " /* " + f + " in Sources */ = { isa = PBXBuildFile; fileRef = " + file_refs[f] + " /* " + f + " */; };"
    )

source_files_block = "\t\t" + source_phase_id + " /* Sources */ = {\n"
source_files_block += "\t\t\tisa = PBXSourcesBuildPhase;\n"
source_files_block += "\t\t\tbuildActionMask = 2147483647;\n"
source_files_block += "\t\t\tfiles = (\n"
source_files_block += ",\n".join("\t\t\t\t" + build_file_ids[i] + " /* " + files[i] + " in Sources */" for i in range(len(files))) + "\n"
source_files_block += "\t\t\t);\n"
source_files_block += "\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
source_files_block += "\t\t};"
object_lines.append(source_files_block)

object_lines.append(
    "\t\t" + resources_phase_id + " /* Resources */ = { isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };"
)
object_lines.append(
    "\t\t" + frameworks_phase_id + " /* Frameworks */ = { isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };"
)

object_lines.append(
    "\t\t" + target_id + " /* " + project_name + " */ = {\n"
    "\t\t\tisa = PBXNativeTarget;\n"
    "\t\t\tbuildConfigurationList = " + config_list_id + " /* Build configuration list for PBXNativeTarget \"" + project_name + "\" */;\n"
    "\t\t\tbuildPhases = (\n"
    "\t\t\t\t" + source_phase_id + " /* Sources */,\n"
    "\t\t\t\t" + resources_phase_id + " /* Resources */,\n"
    "\t\t\t\t" + frameworks_phase_id + " /* Frameworks */\n"
    "\t\t\t);\n"
    "\t\t\tbuildRules = ();\n"
    "\t\t\tdependencies = ();\n"
    "\t\t\tname = " + project_name + ";\n"
    "\t\t\tproductName = " + project_name + ";\n"
    "\t\t\tproductReference = " + product_ref_id + " /* " + project_name + ".app */;\n"
    "\t\t\tproductType = \"com.apple.product-type.application\";\n"
    "\t\t};"
)

object_lines.append(
    "\t\t" + debug_conf_id + " /* Debug */ = {\n"
    "\t\t\tisa = XCBuildConfiguration;\n"
    "\t\t\tbuildSettings = {\n"
    "\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;\n"
    "\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = \"\";\n"
    "\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;\n"
    "\t\t\t\tCODE_SIGN_STYLE = Automatic;\n"
    "\t\t\t\tCURRENT_PROJECT_VERSION = 1;\n"
    "\t\t\t\tDEVELOPMENT_TEAM = \"\";\n"
    "\t\t\t\tGENERATE_INFOPLIST_FILE = NO;\n"
    "\t\t\t\tINFOPLIST_FILE = Sources/" + project_name + "/Info.plist;\n"
    "\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;\n"
    "\t\t\t\tLD_RUNPATH_SEARCH_PATHS = \"@executable_path/Frameworks\";\n"
    "\t\t\t\tMARKETING_VERSION = 1.0;\n"
    "\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.rivnerun.club.RivneRunningClubApp;\n"
    "\t\t\t\tPRODUCT_NAME = $(TARGET_NAME);\n"
    "\t\t\t\tSDKROOT = iphoneos;\n"
    "\t\t\t\tSWIFT_VERSION = 5.9;\n"
    "\t\t\t\tTARGETED_DEVICE_FAMILY = 1;\n"
    "\t\t\t};\n"
    "\t\t\tname = Debug;\n"
    "\t\t};"
)

object_lines.append(
    "\t\t" + release_conf_id + " /* Release */ = {\n"
    "\t\t\tisa = XCBuildConfiguration;\n"
    "\t\t\tbuildSettings = {\n"
    "\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;\n"
    "\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = \"\";\n"
    "\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;\n"
    "\t\t\t\tCODE_SIGN_STYLE = Automatic;\n"
    "\t\t\t\tCURRENT_PROJECT_VERSION = 1;\n"
    "\t\t\t\tDEVELOPMENT_TEAM = \"\";\n"
    "\t\t\t\tGENERATE_INFOPLIST_FILE = NO;\n"
    "\t\t\t\tINFOPLIST_FILE = Sources/" + project_name + "/Info.plist;\n"
    "\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;\n"
    "\t\t\t\tLD_RUNPATH_SEARCH_PATHS = \"@executable_path/Frameworks\";\n"
    "\t\t\t\tMARKETING_VERSION = 1.0;\n"
    "\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.rivnerun.club.RivneRunningClubApp;\n"
    "\t\t\t\tPRODUCT_NAME = $(TARGET_NAME);\n"
    "\t\t\t\tSDKROOT = iphoneos;\n"
    "\t\t\t\tSWIFT_VERSION = 5.9;\n"
    "\t\t\t\tTARGETED_DEVICE_FAMILY = 1;\n"
    "\t\t\t};\n"
    "\t\t\tname = Release;\n"
    "\t\t};"
)

object_lines.append(
    "\t\t" + config_list_id + " /* Build configuration list for PBXNativeTarget \"" + project_name + "\" */ = {\n"
    "\t\t\tisa = XCConfigurationList;\n"
    "\t\t\tbuildConfigurations = (\n"
    "\t\t\t\t" + debug_conf_id + " /* Debug */,\n"
    "\t\t\t\t" + release_conf_id + " /* Release */\n"
    "\t\t\t);\n"
    "\t\t\tdefaultConfigurationIsVisible = 0;\n"
    "\t\t\tdefaultConfigurationName = Release;\n"
    "\t\t};"
)

object_lines.append(
    "\t\t" + project_config_list_id + " /* Project object */ = {\n"
    "\t\t\tisa = XCConfigurationList;\n"
    "\t\t\tbuildConfigurations = (\n"
    "\t\t\t\t" + debug_conf_id + " /* Debug */,\n"
    "\t\t\t\t" + release_conf_id + " /* Release */\n"
    "\t\t\t);\n"
    "\t\t\tdefaultConfigurationIsVisible = 0;\n"
    "\t\t\tdefaultConfigurationName = Release;\n"
    "\t\t};"
)

object_lines.append(
    "\t\t" + project_obj_id + " /* Project object */ = {\n"
    "\t\t\tisa = PBXProject;\n"
    "\t\t\tattributes = {};\n"
    "\t\t\tbuildConfigurationList = " + project_config_list_id + " /* Project object */;\n"
    "\t\t\tcompatibilityVersion = \"Xcode 14.0\";\n"
    "\t\t\tdevelopmentRegion = en;\n"
    "\t\t\thasScannedForEncodings = 0;\n"
    "\t\t\tknownRegions = (en, Base, uk);\n"
    "\t\t\tmainGroup = " + main_group_id + " /* Project */;\n"
    "\t\t\tproductRefGroup = " + products_group_id + " /* Products */;\n"
    "\t\t\tprojectDirPath = \"\";\n"
    "\t\t\tprojectRoot = \"\";\n"
    "\t\t\ttargets = (\n"
    "\t\t\t\t" + target_id + " /* " + project_name + " */\n"
    "\t\t\t);\n"
    "\t\t};"
)

content = """// !$*UTF8*$!
{{
\tarchiveVersion = 1;
\tclasses = {{}};
\tobjectVersion = 56;
\tobjects = {{
{objects}
\t}};
\trootObject = {project_obj_id} /* Project object */;
}}
""".format(
    project_obj_id=project_obj_id,
    objects="\n" + "\n".join(object_lines) + "\n\t",
)

xcodeproj_dir = root / (project_name + ".xcodeproj")
xcodeproj_dir.mkdir(exist_ok=True)
(xcodeproj_dir / "project.pbxproj").write_text(content, encoding="utf-8")
print("Created " + str(xcodeproj_dir / "project.pbxproj"))
