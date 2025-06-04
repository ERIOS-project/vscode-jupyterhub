# Start from the official minimal Jupyter Notebook image
FROM jupyter/minimal-notebook:latest

# Switch to the root user to perform system-level operations
USER root

# Define the version of code-server to install
ENV CODE_SERVER_VERSION=4.89.1

# Install curl and download code-server based on system architecture
# Clean up apt cache afterwards to reduce image size
RUN apt-get update && \
    apt-get install -y curl && \
    ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "arm64" ]; then \
        CODE_URL="https://github.com/coder/code-server/releases/download/v${CODE_SERVER_VERSION}/code-server-${CODE_SERVER_VERSION}-linux-arm64.tar.gz"; \
    else \
        CODE_URL="https://github.com/coder/code-server/releases/download/v${CODE_SERVER_VERSION}/code-server-${CODE_SERVER_VERSION}-linux-amd64.tar.gz"; \
    fi && \
    curl -fsSL "$CODE_URL" -o /tmp/code-server.tar.gz && \
    tar -xzf /tmp/code-server.tar.gz -C /tmp && \
    mkdir -p /opt/code-server && \
    cp -r /tmp/code-server-${CODE_SERVER_VERSION}-linux-*/* /opt/code-server && \
    ln -s /opt/code-server/bin/code-server /usr/local/bin/code-server && \
    rm -rf /tmp/* && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Install mamba (a faster alternative to conda) in the base environment
RUN conda install -n base -c conda-forge mamba && conda clean -afy

# Install jupyter-server-proxy via pip to enable proxying external applications
RUN pip install --no-cache-dir jupyter-server-proxy

# Configure jupyter-server-proxy to expose code-server under the name "vscode"
RUN tee -a /etc/jupyter/jupyter_server_config.py > /dev/null <<EOF
c.ServerProxy.servers = {
  'vscode': {
    'command': ['/opt/code-server/bin/code-server', '--auth', 'none', '--disable-telemetry', '--port', '{port}'],
    'timeout': 20,
    'launcher_entry': {
      'title': 'VS Code',
    }
  }
}
EOF

# Switch back to the default Jupyter Notebook user (non-root)
USER ${NB_UID}

# Install only the essential Python tools: debugpy (for debugging) and poetry (for dependency management)
RUN pip install --no-cache-dir debugpy poetry
