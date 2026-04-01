pub const ReportToolSpec = struct {
    exe_name: []const u8,
    check_exe_name: []const u8,
    root_source_file: []const u8,
    step_name: []const u8,
    description: []const u8,
    adds_build_options: bool = true,
    adds_target_profile_import: bool = false,
    adds_step_catalog_import: bool = false,
    adds_policy_catalog_import: bool = false,
    adds_profile_catalog_import: bool = false,
    adds_platform_capabilities_import: bool = false,
};

pub const build_mode_report = ReportToolSpec{
    .exe_name = "build-mode-report",
    .check_exe_name = "build-mode-report-check",
    .root_source_file = "build_system/reports/build_mode_report.zig",
    .step_name = "report-build-mode",
    .description = "Report selected app build mode and graph path",
};

pub const build_bootstrap_report = ReportToolSpec{
    .exe_name = "build-bootstrap-report",
    .check_exe_name = "build-bootstrap-report-check",
    .root_source_file = "build_system/reports/build_bootstrap_report.zig",
    .step_name = "report-build-bootstrap",
    .description = "Report resolved build bootstrap context",
};

pub const build_focused_policy_report = ReportToolSpec{
    .exe_name = "build-focused-mode-policy-check",
    .check_exe_name = "build-focused-policy-report-check",
    .root_source_file = "build_system/checks/build_focused_mode_policy_check.zig",
    .step_name = "report-build-focused-policy",
    .description = "Check focused mode dependency policy",
};

pub const build_target_report = ReportToolSpec{
    .exe_name = "build-target-report",
    .check_exe_name = "build-target-report-check",
    .root_source_file = "build_system/reports/build_target_report.zig",
    .step_name = "report-build-target",
    .description = "Report resolved target and optimize settings",
};

pub const build_policy_report = ReportToolSpec{
    .exe_name = "build-policy-report",
    .check_exe_name = "build-policy-report-check",
    .root_source_file = "build_system/reports/build_policy_report.zig",
    .step_name = "report-build-policy",
    .description = "Report supported build options and hard constraints",
    .adds_policy_catalog_import = true,
};

pub const build_platform_report = ReportToolSpec{
    .exe_name = "build-platform-report",
    .check_exe_name = "build-platform-report-check",
    .root_source_file = "build_system/reports/build_platform_report.zig",
    .step_name = "report-build-platform",
    .description = "Report target platform capability assumptions",
    .adds_platform_capabilities_import = true,
};

pub const build_surface_report = ReportToolSpec{
    .exe_name = "build-surface-report",
    .check_exe_name = "build-surface-report-check",
    .root_source_file = "build_system/reports/build_surface_report.zig",
    .step_name = "report-build-surface",
    .description = "Report operator-facing build step taxonomy",
    .adds_build_options = false,
    .adds_step_catalog_import = true,
};

pub const build_profile_report = ReportToolSpec{
    .exe_name = "build-profile-report",
    .check_exe_name = "build-profile-report-check",
    .root_source_file = "build_system/reports/build_profile_report.zig",
    .step_name = "report-build-profiles",
    .description = "Report active build dependency profiles",
    .adds_build_options = false,
    .adds_target_profile_import = true,
    .adds_profile_catalog_import = true,
};

pub const build_dependency_report = ReportToolSpec{
    .exe_name = "build-dependency-report",
    .check_exe_name = "build-dependency-report-check",
    .root_source_file = "build_system/reports/build_dependency_report.zig",
    .step_name = "report-build-dependencies",
    .description = "Report dependency intent for each build profile",
    .adds_build_options = false,
    .adds_profile_catalog_import = true,
};

pub const core_bootstrap_report_specs = [_]ReportToolSpec{
    build_mode_report,
    build_bootstrap_report,
    build_focused_policy_report,
    build_target_report,
    build_policy_report,
    build_platform_report,
    build_dependency_report,
    build_surface_report,
};

pub const core_report_tool_specs = [_]ReportToolSpec{
    build_mode_report,
    build_bootstrap_report,
    build_focused_policy_report,
    build_target_report,
    build_surface_report,
    build_policy_report,
    build_platform_report,
    build_profile_report,
    build_dependency_report,
};
