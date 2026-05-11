# =============================================================================
# lib/excludes.sh - shared noisy/generated file excludes for stateless commands
# =============================================================================

dx_rg_exclude_args() {
  cat <<'EOF'
--glob
!*.g.dart
--glob
!*.freezed.dart
--glob
!*.mocks.dart
--glob
!build/**
--glob
!.dart_tool/**
--glob
!ios/Pods/**
--glob
!android/.gradle/**
--glob
!node_modules/**
--glob
!coverage/**
--glob
!dist/**
--glob
!.DS_Store
EOF
}

dx_fd_exclude_args() {
  cat <<'EOF'
--exclude
*.g.dart
--exclude
*.freezed.dart
--exclude
*.mocks.dart
--exclude
build
--exclude
.dart_tool
--exclude
Pods
--exclude
.gradle
--exclude
node_modules
--exclude
coverage
--exclude
dist
--exclude
.DS_Store
EOF
}

dx_git_pathspec_excludes() {
  cat <<'EOF'
:(exclude)*.g.dart
:(exclude)*.freezed.dart
:(exclude)*.mocks.dart
:(exclude)build/**
:(exclude).dart_tool/**
:(exclude)ios/Pods/**
:(exclude)android/.gradle/**
:(exclude)node_modules/**
:(exclude)coverage/**
:(exclude)dist/**
:(exclude).DS_Store
EOF
}

dx_is_generated_path() {
  case "$1" in
    *.g.dart|*.freezed.dart|*.mocks.dart|.DS_Store|build/*|.dart_tool/*|ios/Pods/*|android/.gradle/*|node_modules/*|coverage/*|dist/*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}
