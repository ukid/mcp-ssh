#!/bin/bash
# Docker run wrapper for MCP SSH
# 每次调用都会启动一个新的独立容器，使用 --rm 自动清理

# 检查 SSH Agent
if [ -z "$SSH_AUTH_SOCK" ]; then
    echo "Error: SSH_AUTH_SOCK is not set" >&2
    exit 1
fi

# 确保数据卷存在（用于持久化连接配置）
docker volume inspect mcp-ssh-data >/dev/null 2>&1 || docker volume create mcp-ssh-data

# 运行容器
# 使用 --rm 确保容器退出后自动删除
# 使用 -i 保持交互式输入
# 使用 --network host 以便访问宿主机网络
exec docker run --rm -i \
    --network host \
    -v "${SSH_AUTH_SOCK}:/tmp/ssh-agent.sock:ro" \
    -v "mcp-ssh-data:/root/.mcp-ssh" \
    -v "${HOME}/.ssh:/root/.ssh:ro" \
    -e "SSH_AUTH_SOCK=/tmp/ssh-agent.sock" \
    -e "IS_DOCKER=true" \
    -e "SSH_DATA_PATH=/root/.mcp-ssh" \
    -e "CONNECTION_TIMEOUT=10000" \
    -e "DEFAULT_SSH_PORT=22" \
    -e "RECONNECT_ATTEMPTS=3" \
    mcp-ssh \
    python3 /app/bridging_ssh_mcp.py
