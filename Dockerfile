FROM quay.io/jupyter/minimal-notebook:x86_64-python-3.12

USER root

ENV CODE_SERVER_VERSION=4.89.1

# Install only required deps
RUN apt-get update && \
    apt-get install -y curl bash && \
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
    apt-get purge -y curl && \
    apt-get autoremove -y && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Python tools
RUN pip install --no-cache-dir jupyter-server-proxy debugpy poetry udocker && \
    conda install -n base -c conda-forge mamba && conda clean -afy

# Symlink to docker logs
RUN ln -sf /proc/1/fd/1 /var/log/terminal.log

# Custom shell with banner
RUN echo '#!/bin/bash' > /usr/local/bin/logged-bash && \
    echo 'echo "🛡️  This session is being monitored and recorded for security and compliance purposes."' >> /usr/local/bin/logged-bash && \
    echo 'exec bash -i' >> /usr/local/bin/logged-bash && \
    chmod 555 /usr/local/bin/logged-bash && \
    chown root:root /usr/local/bin/logged-bash

# Force shell for jovyan
RUN usermod -s /usr/local/bin/logged-bash jovyan

# Log every command executed by the user
RUN echo 'export PROMPT_COMMAND='\''RECORD=$(history 1 | sed "s/^ *[0-9]* *//"); echo "[COMMAND] $(whoami): $RECORD" >> /proc/1/fd/1'\''' > /etc/profile.d/audit-cmd.sh && \
    chmod 444 /etc/profile.d/audit-cmd.sh && \
    chown root:root /etc/profile.d/audit-cmd.sh

# Lock VS Code terminal settings
RUN mkdir -p /opt/static/code-server/User && \
    cat <<EOF > /opt/static/code-server/User/settings.json
{
  "terminal.integrated.defaultProfile.linux": "logged-bash",
  "terminal.integrated.profiles.linux": {
    "logged-bash": {
      "path": "/usr/local/bin/logged-bash"
    }
  },
  "terminal.integrated.allowWorkspaceShell": false,
  "terminal.integrated.shellIntegration.enabled": true
}
EOF

RUN mkdir -p /home/jovyan/.local/share/code-server/User && \
    cp /opt/static/code-server/User/settings.json /home/jovyan/.local/share/code-server/User/settings.json && \
    chown -R jovyan:users /home/jovyan/.local && \
    chmod 444 /home/jovyan/.local/share/code-server/User/settings.json

# Register code-server in jupyter-server-proxy
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

# Startup script for JupyterHub compatibility
RUN echo '#!/bin/bash' > /usr/local/bin/start-with-audit && \
    echo 'if [ "$#" -eq 0 ]; then' >> /usr/local/bin/start-with-audit && \
    echo '  exec start-singleuser.sh' >> /usr/local/bin/start-with-audit && \
    echo 'else' >> /usr/local/bin/start-with-audit && \
    echo '  exec "$@"' >> /usr/local/bin/start-with-audit && \
    echo 'fi' >> /usr/local/bin/start-with-audit && \
    chmod 555 /usr/local/bin/start-with-audit && \
    chown root:root /usr/local/bin/start-with-audit

CMD ["/usr/local/bin/start-with-audit"]

USER ${NB_UID}
