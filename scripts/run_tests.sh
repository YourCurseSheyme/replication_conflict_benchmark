#!/bin/bash

set -e

# Потом на 2 файла надо разбить:
# - создание скриптов
# - их запуск
# почему так? потому что скрипты на sql, где тарантул - частный случай

# Configuration

BASE_PORT=3301
DATA_DIR="../benchmark"
INSTANCE1_DIR="$DATA_DIR/node1"
INSTANCE2_DIR="$DATA_DIR/node2"
SCRIPTS_DIR="."
CFG_DIR="../configs"

# Cleaning up

cleanup() {
    echo "Cleaning up environment..."
    kill $(lsof -t -i:$BASE_PORT) 2>/dev/null || true
    kill $(lsof -t -i:$((BASE_PORT + 1))) 2>/dev/null || true
    rm -rf "$DATA_DIR" 2>/dev/null || true
    rm -f "$SCRIPTS_DIR/test_data.md" || true
    mkdir -p "$INSTANCE1_DIR/wal" "$INSTANCE1_DIR/snap"
    mkdir -p "$INSTANCE2_DIR/wal" "$INSTANCE2_DIR/snap"
}

# Selecting tests

select_test() {
    echo "Available test scenarios: 1, 2, 3"
    while true; do
        read -p "Select test scenario: " test_num
        case $test_num in
            1|2|3)
                echo "Chosen $test_num"
                SELECTED_TEST_DIR="$CFG_DIR/test$test_num"
                cp "$SELECTED_TEST_DIR/content.md" .
                mv content.md test_data.md
                return 0
                ;;
            *)
                echo "Invalid selection"
                ;;
        esac
    done
}

# Creating configs

create_configs() {
    local test_init=$(realpath "$SELECTED_TEST_DIR/init.lua")
    cat > "$INSTANCE1_DIR/config.lua" << EOL
os.setenv("TARANTOOL_LISTEN", "127.0.0.1:$BASE_PORT")
os.setenv("TARANTOOL_MASTER", "127.0.0.1:$BASE_PORT")
os.setenv("TARANTOOL_REPLICA", "127.0.0.1:$((BASE_PORT + 1))")
os.setenv("TARANTOOL_WAL_DIR", "$INSTANCE1_DIR/wal")
os.setenv("TARANTOOL_MEMTX_DIR", "$INSTANCE1_DIR/snap")

dofile('$test_init')

require('console').start()
os.exit()
EOL
    cat > "$INSTANCE2_DIR/config.lua" << EOL
os.setenv("TARANTOOL_LISTEN", "127.0.0.1:$((BASE_PORT+1))")
os.setenv("TARANTOOL_MASTER", "127.0.0.1:$BASE_PORT")
os.setenv("TARANTOOL_REPLICA", "127.0.0.1:$((BASE_PORT+1))")
os.setenv("TARANTOOL_WAL_DIR", "$INSTANCE2_DIR/wal")
os.setenv("TARANTOOL_MEMTX_DIR", "$INSTANCE2_DIR/snap")

dofile('$test_init')

require('console').start()
os.exit()
EOL
}

# Building

start_instances() {
    echo -e "\nStarting Tarantool instances..."

    gnome-terminal --tab --title="Master" -- bash -c "tarantool -i $INSTANCE1_DIR/config.lua; run_test.lua; exec bash"
    gnome-terminal --tab --title="Replica" -- bash -c "tarantool -i $INSTANCE2_DIR/config.lua; run_test.lua; exec bash"

    echo -e "\nTest env ready:"
    echo "master: 127.0.0.1:$BASE_PORT"
    echo "replica: 127.0.0.1:$((BASE_PORT + 1))"
    echo "test: $SELECTED_TEST"
    echo "To continue testing, read: ./test_data.md"

    local benchmark_path=$(realpath "$DATA_DIR")
    cp resolver.lua "$benchmark_path"/node1
    cp resolver.lua "$benchmark_path"/node2
    echo "To test resolver module, enter at any node: require('resolver')"
}

main() {
    cleanup
    select_test
    create_configs
    start_instances
}

main