#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

COLOR_RED='\033[1;31m'
COLOR_BLUE='\033[1;34m'
COLOR_NC='\033[0m'

set -euo pipefail  

# 检查是否提供了 tag 参数
if [ $# -ne 1 ]; then
    echo "Hint Usage: $0 <tag-name>"
    echo "     Example: bash $0 v2.16.1"
    exit 1
fi

TAG_NAME="$1"
REPO_DIR="$HOME/code/NextChat"
DOCKERFILE="$CURRENT_DIR/Dockerfile"
ORIGIN_URL="https://github.com/yeying-community/NextChat.git"
BUILDER_NAME="multi-builder"
DOCKERHUB_USER="yeying2025"

index=1
echo -e "\n${COLOR_BLUE}step $index -- 正在准备构建 NextChat 镜像，目标 tag: $TAG_NAME ${COLOR_NC}"


if [ ! -d "$REPO_DIR" ]; then
    echo " $REPO_DIR 不存在，正在克隆仓库..."
    git clone "$ORIGIN_URL" "$REPO_DIR"
else
    echo " $REPO_DIR 已存在，正在拉取最新信息..."
    cd "$REPO_DIR"
    git fetch origin
    git fetch --tags
fi


cd "$REPO_DIR"

index=$((index+1))
echo -e "\n${COLOR_BLUE}step $index -- 检查指定的tag是否存在 ${COLOR_NC}"
# 2. 检查指定的 tag 是否存在
if ! git show-ref --verify --quiet "refs/tags/$TAG_NAME"; then
    echo -e "\n${COLOR_RED}错误：tag '$TAG_NAME' 不存在！${COLOR_NC}"
    echo "可用的 tag 列表："
    git tag -l | tail -5
    exit 1
fi

echo "tag '$TAG_NAME' 存在，正在切换到该 tag..."

index=$((index+1))
echo -e "\n${COLOR_BLUE}step $index -- 重置并切换到指定 tag ${COLOR_NC}"
git clean -fd    # 清理未跟踪的文件
git checkout "$TAG_NAME"


index=$((index+1))
echo -e "\n${COLOR_BLUE}step $index -- 检查 Dockerfile 是否存在 ${COLOR_NC}"
if [ ! -f "$DOCKERFILE" ]; then
    echo -e "\n${COLOR_RED}错误：Dockerfile 不存在！路径: $DOCKERFILE ${COLOR_NC}"
    exit 1
fi


index=$((index+1))
echo -e "\n${COLOR_BLUE}step $index -- 确保 Docker Buildx builder 实例 ${BUILDER_NAME} 已启用... ${COLOR_NC}"
if ! sudo docker buildx inspect "$BUILDER_NAME" >/dev/null 2>&1; then
    echo -e "\n${COLOR_RED}错误：没有找到 buildx builder 实例 ${BUILDER_NAME}  请检查名称是否正确或者重新创建 ${COLOR_NC}"
    exit 1
else
    echo "使用已有的 buildx builder..."
    docker buildx use "$BUILDER_NAME"
fi


index=$((index+1))
echo -e "\n${COLOR_BLUE}step $index -- 登录 Docker Hub ${COLOR_NC}"
if [ -z "${DOCKERHUB_TOKEN:-}" ]; then
    echo -e "\n${COLOR_RED}错误：环境变量 DOCKERHUB_TOKEN 未设置, 请先设置DOCKERHUB_TOKEN=your_personal_access_token！${COLOR_NC}"
    exit 1
fi
echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USER" --password-stdin
if [ $? -ne 0 ]; then
    echo -e "\n${COLOR_RED}错误：Docker Hub登录失败，请检查用户名或 Token ${COLOR_NC}"
    exit 1
fi


remove_v_prefix() {
    local tag="$1"
    local clean_tag=$(echo "$tag" | sed 's/^v//i')
    echo "$clean_tag"
}
index=$((index+1))
echo -e "\n${COLOR_BLUE}step $index -- 开始构建并推送多平台镜像 ${COLOR_NC}"
short_tag=$(remove_v_prefix "$TAG_NAME")
IMAGE_NAME="${DOCKERHUB_USER}/nextchat:$short_tag"
echo "镜像名称: $IMAGE_NAME"
docker buildx build \
    --platform linux/amd64,linux/arm64 \
    --file "$DOCKERFILE" \
    --tag "$IMAGE_NAME" \
    --push \
    "$REPO_DIR"

echo "镜像构建并推送成功！可在 Docker Hub 查看: https://hub.docker.com/r/${DOCKERHUB_USER}/nextchat/tags"

index=$((index+1))
echo -e "\n${COLOR_BLUE}step $index -- 登出 Docker Hub ${COLOR_NC}"
docker logout
