#!/bin/bash
# Docker run wrapper for MCP SSH
# 单一容器实例模式，不自动清理

CONTAINER_NAME="mcp-ssh-instance"

# 检查 SSH Agent
if [ -z "$SSH_AUTH_SOCK" ]; then
    echo "Error: SSH_AUTH_SOCK is not set" >&2
    exit 1
fi

# 确保数据卷存在（用于持久化连接配置）
docker volume inspect mcp-ssh-data >/dev/null 2>&1 || docker volume create mcp-ssh-data

# 检查容器状态
CONTAINER_STATUS=$(docker ps -a --filter "name=$CONTAINER_NAME" --format "{{.Status}}" 2>/dev/null)

if [[ "$CONTAINER_STATUS" == *"Up"* ]]; then
    # 容器正在运行，附加到现有容器
    echo "容器 $CONTAINER_NAME 已在运行，附加到现有容器..." >&2
    # 清理可能存在的旧锁文件（允许多个进程同时运行）
    docker exec "$CONTAINER_NAME" rm -f /app/.mcp-ssh.lock 2>/dev/null || true
    exec docker exec -i "$CONTAINER_NAME" python3 /app/bridging_ssh_mcp.py
elif [[ -n "$CONTAINER_STATUS" ]]; then
    # 容器存在但已停止，启动并附加
    echo "发现已停止的容器，正在启动..." >&2
    docker start "$CONTAINER_NAME" >/dev/null 2>&1
    # 等待容器完全启动
    sleep 1
    # 清理可能存在的旧锁文件（允许多个进程同时运行）
    docker exec "$CONTAINER_NAME" rm -f /app/.mcp-ssh.lock 2>/dev/null || true
    exec docker exec -i "$CONTAINER_NAME" python3 /app/bridging_ssh_mcp.py
else
    # 容器不存在，创建新容器（后台运行，使用 sleep 作为主进程保持容器运行）
    echo "创建新容器 $CONTAINER_NAME..." >&2
    docker run -d --name "$CONTAINER_NAME" --init \
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
        sleep infinity >/dev/null 2>&1
    
    # 等待容器完全启动
    sleep 1
    
    # 清理可能存在的旧锁文件（允许多个进程同时运行）
    docker exec "$CONTAINER_NAME" rm -f /app/.mcp-ssh.lock 2>/dev/null || true
    
    # 附加到容器执行命令
    exec docker exec -i "$CONTAINER_NAME" python3 /app/bridging_ssh_mcp.py
fi

# 注意：不注册 cleanup，脚本退出时容器继续运行
# 容器清理方式：
# 1. 手动执行: docker stop $CONTAINER_NAME
# 2. 使用 cleanup-containers.sh 脚本
# 3. 系统重启
