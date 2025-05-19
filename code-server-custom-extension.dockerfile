FROM codercom/code-server:latest

USER root

# Install Python and basic development tools
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    python3-full \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set up Python aliases if needed
RUN if [ ! -e /usr/bin/python ]; then ln -s /usr/bin/python3 /usr/bin/python; fi

# Install VS Code extensions for Jupyter
RUN code-server --install-extension ms-python.python \
    && code-server --install-extension ms-toolsai.jupyter 

# Switch back to the coder user
USER coder
