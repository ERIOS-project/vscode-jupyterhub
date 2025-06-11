FROM jupyter/minimal-notebook:latest

USER root

ENV CODE_SERVER_VERSION=4.89.1

# Install code-server and dependencies
RUN apt-get update && \
    apt-get install -y curl inotify-tools && \
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

# Install Python tools
RUN pip install --no-cache-dir jupyter-server-proxy debugpy poetry udocker && \
    conda install -n base -c conda-forge mamba && conda clean -afy

# Symbolic link to docker stdout
RUN ln -sf /proc/1/fd/1 /var/log/terminal.log

# Shell wrapper with security banner
RUN echo '#!/bin/bash' > /usr/local/bin/logged-bash && \
    echo 'echo "🛡️  This session is being monitored and recorded for security and compliance purposes."' >> /usr/local/bin/logged-bash && \
    echo 'exec script -q -c /bin/bash /proc/1/fd/1' >> /usr/local/bin/logged-bash && \
    chmod 555 /usr/local/bin/logged-bash && \
    chown root:root /usr/local/bin/logged-bash

# Force shell for jovyan
RUN usermod -s /usr/local/bin/logged-bash jovyan

# Audit script
RUN echo '#!/bin/bash' > /usr/local/bin/audit-fs && \
    echo 'inotifywait -m -r -e create,modify,delete,move --format "%T|%e|%w%f" --timefmt "%F %T" /home/jovyan | while IFS="|" read -r timestamp event file; do' >> /usr/local/bin/audit-fs && \
    echo '  echo "[FILE EVENT] $timestamp $event $file" >> /proc/1/fd/1' >> /usr/local/bin/audit-fs && \
    echo '  if echo "$event" | grep -qE "CREATE|MODIFY" && [ -f "$file" ]; then' >> /usr/local/bin/audit-fs && \
    echo '    if [[ "$file" =~ \.py$|\.ipynb$|\.sh$|\.json$|\.env$|\.yaml$|\.yml$|\.txt$|\.js$ ]]; then' >> /usr/local/bin/audit-fs && \
    echo '      echo "--- Content of $file ---" >> /proc/1/fd/1' >> /usr/local/bin/audit-fs && \
    echo '      cat "$file" >> /proc/1/fd/1' >> /usr/local/bin/audit-fs && \
    echo '      echo "--- End of $file ---" >> /proc/1/fd/1' >> /usr/local/bin/audit-fs && \
    echo '    else' >> /usr/local/bin/audit-fs && \
    echo '      echo "--- Content skipped for $file (extension not tracked) ---" >> /proc/1/fd/1' >> /usr/local/bin/audit-fs && \
    echo '    fi' >> /usr/local/bin/audit-fs && \
    echo '  fi' >> /usr/local/bin/audit-fs && \
    echo 'done' >> /usr/local/bin/audit-fs && \
    chmod 555 /usr/local/bin/audit-fs && \
    chown root:root /usr/local/bin/audit-fs

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

# Compatible startup with JupyterHub
RUN echo '#!/bin/bash' > /usr/local/bin/start-with-audit && \
    echo '/usr/local/bin/audit-fs &' >> /usr/local/bin/start-with-audit && \
    echo 'if [ "$#" -eq 0 ]; then' >> /usr/local/bin/start-with-audit && \
    echo '  exec start-singleuser.sh' >> /usr/local/bin/start-with-audit && \
    echo 'else' >> /usr/local/bin/start-with-audit && \
    echo '  exec "$@"' >> /usr/local/bin/start-with-audit && \
    echo 'fi' >> /usr/local/bin/start-with-audit && \
    chmod 555 /usr/local/bin/start-with-audit && \
    chown root:root /usr/local/bin/start-with-audit

# JupyterHub expects CMD not ENTRYPOINT
CMD ["/usr/local/bin/start-with-audit"]

USER ${NB_UID}
