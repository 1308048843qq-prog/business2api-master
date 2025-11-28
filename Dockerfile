# Build stage
FROM golang:1.24-alpine AS builder

WORKDIR /app

# Install build dependencies
RUN apk add --no-cache git ca-certificates

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY *.go ./

# Build binary
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o business2api .

# Runtime stage: Node + Go，支持 Puppeteer 和 IMAP
FROM node:20-bullseye-slim

WORKDIR /app

# 安装 Chromium / Puppeteer 所需依赖
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates tzdata \
        libasound2 libatk-bridge2.0-0 libatk1.0-0 libc6 libcairo2 libcups2 \
        libdbus-1-3 libexpat1 libfontconfig1 libgbm1 libglib2.0-0 libgtk-3-0 \
        libnspr4 libnss3 libpango-1.0-0 libpangocairo-1.0-0 libstdc++6 \
        libx11-6 libx11-xcb1 libxcb1 libxcomposite1 libxcursor1 libxdamage1 \
        libxext6 libxfixes3 libxi6 libxrandr2 libxrender1 libxss1 libxtst6 \
        wget xdg-utils && \
    rm -rf /var/lib/apt/lists/*

# 拷贝 Go 二进制
COPY --from=builder /app/business2api .

# 拷贝注册脚本（仅 main.js，避免依赖 package.json 是否存在）
COPY main.js ./

# 如果仓库中没有 gemini-automation.js，则在容器内生成一个简单入口
RUN if [ -f gemini-automation.js ]; then echo "use existing gemini-automation.js"; else echo "require('./main');" > gemini-automation.js; fi

# 直接安装所需依赖（不依赖 package.json 存在）
RUN npm install --omit=dev \
    puppeteer@^21.0.0 \
    axios@^1.6.0 \
    imap-simple@^5.0.0 \
    mailparser@^3.6.4

# 拷贝配置模板并作为默认 config.json
COPY config.json.example ./config.json.example
COPY config.json.example ./config.json

# 创建数据目录
RUN mkdir -p /app/data

# 默认环境变量（可在平台上覆盖）
ENV LISTEN_ADDR=":8000"
ENV DATA_DIR="/app/data"

EXPOSE 8000

ENTRYPOINT ["./business2api"]
