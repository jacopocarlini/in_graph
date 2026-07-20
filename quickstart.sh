#!/bin/bash

# Quick Start Guide - In Graph Testing System
# Questo script aiuta a configurare e avviare il sistema di test

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="${PROJECT_DIR}/scripts"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

clear

# ASCII Art Banner
cat << "EOF"
${BLUE}
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║          📊 IN GRAPH - TESTING & MONITORING SYSTEM 📊           ║
║                                                                ║
║            Quick Start Guide & Setup Assistant                 ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
EOF

echo ""
echo -e "${CYAN}Welcome to the In Graph Testing System!${NC}"
echo ""
echo -e "${BLUE}This guide will help you:${NC}"
echo "  1. ✅ Verify your environment"
echo "  2. 📦 Install required dependencies"
echo "  3. 🧪 Run your first test suite"
echo "  4. 🎥 Start the monitoring dashboard"
echo "  5. 📊 Generate your first report"
echo ""

# Check environment
check_environment() {
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}📋 Checking environment...${NC}"
    echo ""

    local all_good=true

    # Check Flutter
    if command -v flutter &> /dev/null; then
        local flutter_version=$(flutter --version | head -1)
        echo -e "${GREEN}✓ Flutter${NC}: $flutter_version"
    else
        echo -e "${RED}✗ Flutter${NC}: Not installed"
        all_good=false
    fi

    # Check Dart
    if command -v dart &> /dev/null; then
        local dart_version=$(dart --version 2>&1 | head -1)
        echo -e "${GREEN}✓ Dart${NC}: $dart_version"
    else
        echo -e "${RED}✗ Dart${NC}: Not installed"
        all_good=false
    fi

    # Check Python (for web server)
    if command -v python3 &> /dev/null; then
        local python_version=$(python3 --version 2>&1)
        echo -e "${GREEN}✓ Python 3${NC}: $python_version"
    elif command -v python &> /dev/null; then
        local python_version=$(python --version 2>&1)
        echo -e "${GREEN}✓ Python${NC}: $python_version"
    else
        echo -e "${YELLOW}⚠ Python${NC}: Not installed (web server won't work)"
    fi

    # Check Chrome
    if command -v open &> /dev/null; then
        echo -e "${GREEN}✓ macOS${NC}: open command available"
    fi

    echo ""

    if [ "$all_good" = true ]; then
        echo -e "${GREEN}✓ Environment check passed!${NC}"
        return 0
    else
        echo -e "${RED}✗ Some dependencies are missing${NC}"
        return 1
    fi
}

# Install dependencies
install_dependencies() {
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}📦 Installing Flutter dependencies...${NC}"
    echo ""

    cd "$PROJECT_DIR"

    if flutter pub get; then
        echo -e "${GREEN}✓ Dependencies installed${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to install dependencies${NC}"
        return 1
    fi
}

# Run first test
run_first_test() {
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}🧪 Running first test...${NC}"
    echo ""

    cd "$PROJECT_DIR"

    echo -e "${CYAN}This will run a quick unit test to verify everything works.${NC}"
    echo ""

    flutter test test/widget_tests.dart -v --test-randomize-ordering-seed random | head -50

    echo ""
    echo -e "${GREEN}✓ Test run completed${NC}"
}

# Start monitoring
start_monitoring_prompt() {
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}🎥 Start monitoring dashboard?${NC}"
    echo ""
    echo -e "${CYAN}The monitoring dashboard provides:${NC}"
    echo "  • Live screenshots as you make changes"
    echo "  • Real-time performance metrics"
    echo "  • Activity log viewer"
    echo "  • Automatic file change detection"
    echo ""

    read -p "Start monitoring dashboard? (y/n) " -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        echo -e "${CYAN}Starting monitoring dashboard...${NC}"
        echo -e "${YELLOW}(Press Ctrl+C to stop)${NC}"
        echo ""
        sleep 1
        bash "${SCRIPTS_DIR}/monitor_frontend.sh"
    fi
}

# Menu
show_menu() {
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${MAGENTA}🎯 QUICK START MENU${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "  ${CYAN}1)${NC} Run all tests + generate report"
    echo "  ${CYAN}2)${NC} Run unit tests only"
    echo "  ${CYAN}3)${NC} Run performance tests"
    echo "  ${CYAN}4)${NC} Start monitoring dashboard"
    echo "  ${CYAN}5)${NC} Check for regressions"
    echo "  ${CYAN}6)${NC} Open documentation"
    echo "  ${CYAN}7)${NC} Exit"
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
}

# Main loop
main() {
    # Check environment
    if ! check_environment; then
        echo ""
        echo -e "${YELLOW}⚠ Please install missing dependencies and try again${NC}"
        exit 1
    fi

    echo ""
    read -p "Press Enter to continue..." </dev/tty

    # Install dependencies
    echo ""
    if ! install_dependencies; then
        exit 1
    fi

    echo ""
    read -p "Press Enter to run first test..." </dev/tty

    # Run first test
    echo ""
    run_first_test

    # Menu loop
    while true; do
        echo ""
        show_menu
        read -p "Select an option (1-7): " -n 1 -r choice
        echo ""
        echo ""

        case $choice in
            1)
                echo -e "${CYAN}Running all tests with reporting...${NC}"
                bash "${SCRIPTS_DIR}/monitor.sh" all
                ;;
            2)
                echo -e "${CYAN}Running unit tests...${NC}"
                bash "${SCRIPTS_DIR}/monitor.sh" unit
                ;;
            3)
                echo -e "${CYAN}Running performance tests...${NC}"
                bash "${SCRIPTS_DIR}/monitor.sh" performance
                ;;
            4)
                echo -e "${CYAN}Starting monitoring dashboard...${NC}"
                bash "${SCRIPTS_DIR}/monitor.sh" monitor
                ;;
            5)
                echo -e "${CYAN}Checking for regressions...${NC}"
                bash "${SCRIPTS_DIR}/monitor.sh" check-regression
                ;;
            6)
                echo -e "${CYAN}Opening documentation...${NC}"
                if command -v open &> /dev/null; then
                    open -a "Google Chrome" "${PROJECT_DIR}/TESTING.md" 2>/dev/null || open "${PROJECT_DIR}/TESTING.md"
                else
                    echo "See TESTING.md in project root"
                fi
                ;;
            7)
                echo -e "${GREEN}✓ Goodbye!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                ;;
        esac
    done
}

# Run main
main

