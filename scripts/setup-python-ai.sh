#!/data/data/com.termux/files/usr/bin/bash
# Termux AI Toolkit — Python AI 环境配置
# 用法：bash scripts/setup-python-ai.sh

set -e

echo "=== Python AI 环境配置 ==="

# 1. 系统依赖
echo "[1/4] 安装系统依赖..."
pkg install -y -q python clang make cmake libxml2 libxslt 2>/dev/null || true

# 2. Python 基础
echo "[2/4] 确保 pip 最新..."
python3 -m pip install --upgrade pip setuptools wheel -q

# 3. 安装常用 AI 库
echo "[3/4] 安装 AI 库..."
pip install \
    openai \
    anthropic \
    requests \
    httpx \
    aiohttp \
    -q 2>/dev/null || {
    echo "⚠️  部分安装失败，继续..."
}

# 4. 验证
echo "[4/4] 验证..."
echo "Python: $(python3 --version)"
echo "pip:    $(python3 -m pip --version | awk '{print $2}')"
echo ""
echo "已安装的 AI 相关包："
pip list 2>/dev/null | grep -iE "openai|anthropic|httpx|aiohttp" | while read -r line; do
    echo "  · $line"
done

echo ""
echo "✅ Python AI 环境配置完成"
echo "下一步：source venv/bin/activate"
