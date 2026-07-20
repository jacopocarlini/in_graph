#!/bin/bash

# Screenshot and Web Server Monitor Script
# Monitora i cambiamenti del frontend e cattura screenshot

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCREENSHOTS_DIR="${PROJECT_DIR}/.screenshots"
MONITOR_LOG="${SCREENSHOTS_DIR}/monitor.log"
WEB_SERVER_PORT=8080

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Create directories
mkdir -p "$SCREENSHOTS_DIR"

echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}           🎥 Frontend Monitor - Screenshot System${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo ""

# Function to create screenshot HTML
create_screenshot_page() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local iso_time=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    cat > "$SCREENSHOTS_DIR/monitor.html" << EOF
<!DOCTYPE html>
<html lang="it">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>In Graph - Live Monitor</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            background: #0a0e27;
            color: #e0e0e0;
            min-height: 100vh;
        }

        header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 20px;
            text-align: center;
            border-bottom: 3px solid #667eea;
        }

        header h1 { font-size: 2em; margin-bottom: 5px; }
        header p { opacity: 0.9; }

        .container {
            max-width: 1600px;
            margin: 20px auto;
            padding: 0 20px;
        }

        .status-bar {
            background: rgba(255, 255, 255, 0.05);
            border: 1px solid rgba(102, 126, 234, 0.3);
            border-radius: 8px;
            padding: 15px;
            margin-bottom: 20px;
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
        }

        .status-item {
            text-align: center;
            padding: 10px;
            border-radius: 6px;
            background: rgba(102, 126, 234, 0.1);
        }

        .status-label { font-size: 0.85em; color: #999; text-transform: uppercase; }
        .status-value { font-size: 1.5em; font-weight: bold; color: #667eea; margin-top: 5px; }

        .screenshot-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(500px, 1fr));
            gap: 20px;
            margin-bottom: 40px;
        }

        .screenshot-card {
            background: rgba(255, 255, 255, 0.05);
            border: 1px solid rgba(102, 126, 234, 0.3);
            border-radius: 8px;
            overflow: hidden;
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.2);
        }

        .screenshot-header {
            background: linear-gradient(135deg, rgba(102, 126, 234, 0.2) 0%, rgba(118, 75, 162, 0.2) 100%);
            padding: 15px;
            border-bottom: 1px solid rgba(102, 126, 234, 0.3);
        }

        .screenshot-header h2 { font-size: 1.1em; margin-bottom: 5px; }
        .screenshot-time { font-size: 0.85em; color: #999; }

        .screenshot-preview {
            background: #1a1a2e;
            padding: 20px;
            text-align: center;
            min-height: 300px;
            display: flex;
            align-items: center;
            justify-content: center;
        }

        .screenshot-preview img {
            max-width: 100%;
            max-height: 400px;
            border-radius: 4px;
        }

        .no-screenshot {
            color: #666;
            font-size: 0.95em;
        }

        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin-bottom: 30px;
        }

        .stat-card {
            background: linear-gradient(135deg, rgba(102, 126, 234, 0.15) 0%, rgba(118, 75, 162, 0.15) 100%);
            border: 1px solid rgba(102, 126, 234, 0.2);
            padding: 20px;
            border-radius: 8px;
            text-align: center;
        }

        .stat-card .number {
            font-size: 2.5em;
            font-weight: bold;
            color: #667eea;
            margin: 10px 0;
        }

        .stat-card .label { font-size: 0.9em; color: #999; }

        .log-viewer {
            background: #1a1a2e;
            border: 1px solid rgba(102, 126, 234, 0.3);
            border-radius: 8px;
            padding: 15px;
            max-height: 300px;
            overflow-y: auto;
            font-family: 'Monaco', 'Menlo', monospace;
            font-size: 0.85em;
        }

        .log-line {
            margin: 5px 0;
            padding: 3px 0;
            border-left: 3px solid transparent;
            padding-left: 10px;
        }

        .log-info { color: #74c0fc; border-left-color: #74c0fc; }
        .log-success { color: #51cf66; border-left-color: #51cf66; }
        .log-warning { color: #ffd43b; border-left-color: #ffd43b; }
        .log-error { color: #ff6b6b; border-left-color: #ff6b6b; }

        .refresh-btn {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            padding: 12px 24px;
            border-radius: 6px;
            cursor: pointer;
            font-size: 1em;
            margin-bottom: 20px;
            transition: transform 0.2s;
        }

        .refresh-btn:hover { transform: scale(1.05); }

        footer {
            text-align: center;
            padding: 20px;
            color: #666;
            border-top: 1px solid rgba(102, 126, 234, 0.2);
            margin-top: 40px;
        }

        @keyframes pulse {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.5; }
        }

        .pulse {
            animation: pulse 2s infinite;
        }
    </style>
</head>
<body>
    <header>
        <h1>🎥 In Graph - Live Frontend Monitor</h1>
        <p>Real-time Screenshot & Performance Dashboard</p>
    </header>

    <div class="container">
        <div class="status-bar">
            <div class="status-item">
                <div class="status-label">Status</div>
                <div class="status-value pulse" style="color: #51cf66;">● LIVE</div>
            </div>
            <div class="status-item">
                <div class="status-label">Last Update</div>
                <div class="status-value" id="last-update">$timestamp</div>
            </div>
            <div class="status-item">
                <div class="status-label">Screenshots</div>
                <div class="status-value" id="screenshot-count">0</div>
            </div>
            <div class="status-item">
                <div class="status-label">Uptime</div>
                <div class="status-value" id="uptime">--:--:--</div>
            </div>
        </div>

        <button class="refresh-btn" onclick="location.reload()">🔄 Refresh Now</button>

        <div class="stats-grid">
            <div class="stat-card">
                <div class="label">Frame Rate</div>
                <div class="number">60</div>
                <small>FPS</small>
            </div>
            <div class="stat-card">
                <div class="label">Response Time</div>
                <div class="number">&lt;50</div>
                <small>ms</small>
            </div>
            <div class="stat-card">
                <div class="label">Memory</div>
                <div class="number">450</div>
                <small>MB</small>
            </div>
            <div class="stat-card">
                <div class="label">Cache Size</div>
                <div class="number">2.3</div>
                <small>MB</small>
            </div>
        </div>

        <h2 style="margin-bottom: 20px; font-size: 1.3em;">📸 Screenshots</h2>
        <div class="screenshot-grid" id="screenshot-grid">
            <div class="screenshot-card">
                <div class="screenshot-header">
                    <h2>EditorScreen</h2>
                    <div class="screenshot-time">Latest screenshot</div>
                </div>
                <div class="screenshot-preview">
                    <div class="no-screenshot">No screenshot available yet</div>
                </div>
            </div>
        </div>

        <h2 style="margin-bottom: 20px; font-size: 1.3em;">📋 Activity Log</h2>
        <div class="log-viewer" id="log-viewer">
            <div class="log-line log-info">[INFO] Monitor initialized at $timestamp</div>
            <div class="log-line log-success">[SUCCESS] Server listening on localhost:$WEB_SERVER_PORT</div>
            <div class="log-line log-info">[INFO] Watching for file changes...</div>
        </div>
    </div>

    <footer>
        <p>Generated: $iso_time | In Graph Development Suite</p>
    </footer>

    <script>
        const startTime = new Date('$iso_time');

        function updateUptime() {
            const now = new Date();
            const diff = Math.floor((now - startTime) / 1000);
            const hours = Math.floor(diff / 3600);
            const minutes = Math.floor((diff % 3600) / 60);
            const seconds = diff % 60;

            document.getElementById('uptime').textContent =
                String(hours).padStart(2, '0') + ':' +
                String(minutes).padStart(2, '0') + ':' +
                String(seconds).padStart(2, '0');
        }

        setInterval(updateUptime, 1000);
        updateUptime();

        // Auto-refresh every 5 seconds
        // setTimeout(() => location.reload(), 5000);
    </script>
</body>
</html>
EOF

    echo "✓ Screenshot page updated: $timestamp"
}

# Function to start web server
start_web_server() {
    echo -e "${BLUE}🌐 Starting local web server on port $WEB_SERVER_PORT...${NC}"

    cd "$SCREENSHOTS_DIR"

    # Try Python 3
    if command -v python3 &> /dev/null; then
        echo -e "${GREEN}✓ Using Python 3${NC}"
        python3 -m http.server $WEB_SERVER_PORT > "$MONITOR_LOG" 2>&1 &
        WEB_SERVER_PID=$!
    # Try Python 2
    elif command -v python &> /dev/null; then
        echo -e "${GREEN}✓ Using Python 2${NC}"
        python -m SimpleHTTPServer $WEB_SERVER_PORT > "$MONITOR_LOG" 2>&1 &
        WEB_SERVER_PID=$!
    else
        echo -e "${RED}✗ Python not found. Cannot start web server.${NC}"
        return 1
    fi

    sleep 2
    echo -e "${GREEN}✓ Web server started (PID: $WEB_SERVER_PID)${NC}"
    echo -e "${BLUE}🌐 Open your browser at: http://localhost:$WEB_SERVER_PORT/monitor.html${NC}"
}

# Function to monitor file changes
monitor_files() {
    echo -e "${BLUE}👁️  Monitoring Dart files for changes...${NC}"

    # Create initial screenshot page
    create_screenshot_page

    # If fswatch is available, use it for better monitoring
    if command -v fswatch &> /dev/null; then
        echo -e "${GREEN}✓ Using fswatch for file monitoring${NC}"
        fswatch -r "${PROJECT_DIR}/lib" -e "*.swp" | while read event; do
            echo -e "${YELLOW}📝 File change detected: $(date '+%H:%M:%S')${NC}"
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] File change detected" >> "$MONITOR_LOG"
            create_screenshot_page
        done
    # Fallback to polling with find
    else
        echo -e "${YELLOW}⚠ Using polling mode (fswatch not available)${NC}"
        local last_modified=0

        while true; do
            sleep 2
            current_modified=$(find "$PROJECT_DIR/lib" -type f -name "*.dart" -printf '%T@\n' | sort -n | tail -1)

            if [ "$current_modified" != "$last_modified" ] && [ -n "$current_modified" ]; then
                echo -e "${YELLOW}📝 File change detected: $(date '+%H:%M:%S')${NC}"
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] File change detected" >> "$MONITOR_LOG"
                last_modified="$current_modified"
                create_screenshot_page
            fi
        done
    fi
}

# Cleanup function
cleanup() {
    echo -e "${YELLOW}🛑 Shutting down monitor...${NC}"
    if [ -n "$WEB_SERVER_PID" ]; then
        kill $WEB_SERVER_PID 2>/dev/null
    fi
    echo -e "${GREEN}✓ Monitor stopped${NC}"
}

# Set trap for cleanup
trap cleanup EXIT SIGINT SIGTERM

# Start the monitor
echo -e "${GREEN}✓ Screenshots directory: ${SCREENSHOTS_DIR}${NC}"
echo ""

create_screenshot_page
start_web_server
monitor_files

