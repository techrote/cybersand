FROM mcr.microsoft.com/devcontainers/base:noble@sha256:d7c468679f45a52ad3673d06656b5bf16e488990b17216a1fa295d9e1f89d724
USER root
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      binutils=2.42-4ubuntu2.10 \
      ca-certificates=20260816ubuntu0.24.04.2 \
      curl=8.5.0-2ubuntu10.16 \
      file=1:5.45-3build1 \
      g++-13=13.3.0-6ubuntu2~24.04.1 \
      git-lfs=3.4.1-1ubuntu0.4 \
      libgl1-mesa-dri=25.2.8-0ubuntu0.24.04.4 \
      libglx-mesa0=25.2.8-0ubuntu0.24.04.4 \
      python3=3.12.3-0ubuntu2.1 \
      python3-venv=3.12.3-0ubuntu2.1 \
      unzip=6.0-28ubuntu4.1 \
      xauth=1:1.1.2-1build1 \
      xvfb=2:21.1.12-1ubuntu1.9 \
 && rm -rf /var/lib/apt/lists/*
USER vscode
