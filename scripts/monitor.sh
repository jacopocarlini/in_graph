#!/bin/bash

# Main Orchestrator Script for Testing & Monitoring System
# Esegue tutti i test, controlli di regressione e genera report completo

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS_DIR="${PROJECT_DIR}/scripts"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Help function
show_help() {
    cat << EOF
${BLUE}════════════════════════════════════════════════════════════════${NC}
${MAGENTA}    In Graph - Test & Monitor Orchestrator${NC}
${BLUE}════════════════════════════════════════════════════════════════${NC}

${CYAN}Usage:${NC}
  ./monitor.sh [COMMAND] [OPTIONS]

${CYAN}Commands:${NC}
  all              Run all tests and monitoring (default)
  tests            Run all test suites only
  unit             Run unit tests
  performance      Run performance tests
  visual           Run visual regression tests
  integration      Run integration tests
  check-regression Check for regressions
  monitor          Start frontend monitoring server
  analyze          Run code analysis
  help             Show this help message

${CYAN}Examples:${NC}
  ./monitor.sh                    # Run all tests
  ./monitor.sh tests              # Run only tests
  ./monitor.sh unit               # Run unit tests
  ./monitor.sh performance        # Run performance tests
  ./monitor.sh monitor            # Start monitoring dashboard
  ./monitor.sh check-regression   # Check for regressions

${CYAN}Output:${NC}
  Reports are saved to: .test-reports/
  Screenshots to: .screenshots/
  Regression data to: .regression-tests/

${BLUE}════════════════════════════════════════════════════════════════${NC}
EOF
}

# Print banner
print_banner() {
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${MAGENTA}        📊 In Graph - Testing & Monitoring System${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Run all tests
run_all_tests() {
    print_banner

    echo -e "${CYAN}🧪 Starting comprehensive test suite...${NC}"
    echo ""

    cd "$PROJECT_DIR"

    # 1. Run Flutter analysis
    echo -e "${YELLOW}📋 Step 1: Flutter Analysis${NC}"
    if flutter analyze --no-fatal-infos; then
        echo -e "${GREEN}✓ Flutter analysis passed${NC}"
    else
        echo -e "${RED}✗ Flutter analysis failed${NC}"
    fi
    echo ""

    # 2. Run unit tests
    echo -e "${YELLOW}🔧 Step 2: Unit Tests${NC}"
    if flutter test test/widget_tests.dart --no-test-assets -v; then
        echo -e "${GREEN}✓ Unit tests passed${NC}"
    else
        echo -e "${RED}✗ Unit tests failed${NC}"
    fi
    echo ""

    # 3. Run performance tests
    echo -e "${YELLOW}⚡ Step 3: Performance Tests${NC}"
    if flutter test test/performance_tests.dart --no-test-assets -v; then
        echo -e "${GREEN}✓ Performance tests passed${NC}"
    else
        echo -e "${RED}✗ Performance tests failed${NC}"
    fi
    echo ""

    # 4. Run visual regression tests
    echo -e "${YELLOW}🎨 Step 4: Visual Regression Tests${NC}"
    if flutter test test/visual_regression_tests.dart --no-test-assets -v; then
        echo -e "${GREEN}✓ Visual regression tests passed${NC}"
    else
        echo -e "${RED}✗ Visual regression tests failed${NC}"
    fi
    echo ""

    # 5. Check for regressions
    echo -e "${YELLOW}🔍 Step 5: Regression Detection${NC}"
    bash "${SCRIPTS_DIR}/check_regressions.sh"
    echo ""

    print_completion
}

# Run only tests
run_tests_only() {
    print_banner

    echo -e "${CYAN}🧪 Running test suites...${NC}"
    echo ""

    cd "$PROJECT_DIR"

    # Run all test files
    flutter test test/ --no-test-assets -v --coverage

    print_completion
}

# Run specific test suite
run_specific_tests() {
    local test_type=$1
    local test_file=""

    case $test_type in
        unit)
            test_file="test/widget_tests.dart"
            echo -e "${CYAN}Running unit tests...${NC}"
            ;;
        performance)
            test_file="test/performance_tests.dart"
            echo -e "${CYAN}Running performance tests...${NC}"
            ;;
        visual)
            test_file="test/visual_regression_tests.dart"
            echo -e "${CYAN}Running visual regression tests...${NC}"
            ;;
        integration)
            test_file="integration_test/app_test.dart"
            echo -e "${CYAN}Running integration tests...${NC}"
            ;;
        *)
            echo -e "${RED}Unknown test type: $test_type${NC}"
            show_help
            exit 1
            ;;
    esac

    cd "$PROJECT_DIR"
    flutter test "$test_file" --no-test-assets -v
}

# Start monitoring
start_monitoring() {
    print_banner

    echo -e "${CYAN}🎥 Starting frontend monitoring system...${NC}"
    echo ""

    if [ -f "${SCRIPTS_DIR}/monitor_frontend.sh" ]; then
        bash "${SCRIPTS_DIR}/monitor_frontend.sh"
    else
        echo -e "${RED}✗ Monitor script not found${NC}"
        exit 1
    fi
}

# Run code analysis
run_analysis() {
    print_banner

    echo -e "${CYAN}📊 Running code analysis...${NC}"
    echo ""

    cd "$PROJECT_DIR"

    echo -e "${YELLOW}📋 Flutter Analysis${NC}"
    flutter analyze --no-fatal-infos

    echo ""
    echo -e "${GREEN}✓ Analysis complete${NC}"
}

# Check for regressions
check_regressions() {
    print_banner

    echo -e "${CYAN}🔍 Checking for regressions...${NC}"
    echo ""

    if [ -f "${SCRIPTS_DIR}/check_regressions.sh" ]; then
        bash "${SCRIPTS_DIR}/check_regressions.sh"
    else
        echo -e "${RED}✗ Regression check script not found${NC}"
        exit 1
    fi
}

# Print completion message
print_completion() {
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✓ Testing complete!${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${CYAN}📁 Output Directories:${NC}"
    echo -e "   Tests:       ${YELLOW}.test-reports/${NC}"
    echo -e "   Screenshots: ${YELLOW}.screenshots/${NC}"
    echo -e "   Regression:  ${YELLOW}.regression-tests/${NC}"
    echo ""
    echo -e "${CYAN}💡 Next Steps:${NC}"
    echo -e "   • Review test reports in browser"
    echo -e "   • Check regression report for any issues"
    echo -e "   • Run \`./scripts/monitor.sh monitor\` for live dashboard"
    echo ""
}

# Make scripts executable
make_scripts_executable() {
    chmod +x "${SCRIPTS_DIR}/run_tests.sh" 2>/dev/null
    chmod +x "${SCRIPTS_DIR}/monitor_frontend.sh" 2>/dev/null
    chmod +x "${SCRIPTS_DIR}/check_regressions.sh" 2>/dev/null
}

# Main entry point
main() {
    local command=${1:-all}

    make_scripts_executable

    case $command in
        all)
            run_all_tests
            ;;
        tests)
            run_tests_only
            ;;
        unit|performance|visual|integration)
            run_specific_tests "$command"
            ;;
        monitor)
            start_monitoring
            ;;
        analyze)
            run_analysis
            ;;
        check-regression)
            check_regressions
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo -e "${RED}Unknown command: $command${NC}"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"

