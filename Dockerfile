FROM python:3.10-slim-bookworm

# Build arguments - TARGETARCH se detecta automáticamente
ARG TARGETARCH
ARG USERNAME=odoo
ARG USER_UID=1000
ARG USER_GID=$USER_UID
ARG WKHTMLTOPDF_VERSION=0.12.6.1
ARG WKHTMLTOPDF_AMD64_CHECKSUM='98ba0d157b50d36f23bd0dedf4c0aa28c7b0c50fcdcdc54aa5b6bbba81a3941d'
ARG WKHTMLTOPDF_ARM64_CHECKSUM="b6606157b27c13e044d0abbe670301f88de4e1782afca4f9c06a5817f3e03a9c"

# Environment variables
ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    DEBIAN_FRONTEND=noninteractive \
    UV_LINK_MODE=copy \
    UV_COMPILE_BYTECODE=1 \
    UV_PYTHON_DOWNLOADS=never \
    UV_PROJECT_ENVIRONMENT=/workspace/.venv \
    PATH="/workspace/.venv/bin:/home/${USERNAME}/.config/opencode/bin:$PATH" \
    HOME_USER=/home/${USERNAME} \
    ODOO_DATA=/var/lib/odoo

# Layer 1: Install system dependencies
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    # Core utilities
    ca-certificates \
    curl \
    wget \
    git \
    gnupg \
    sudo \
    rsync \
    gettext \
    xz-utils \
    # Shell and editors
    zsh \
    nano \
    # Development tools
    build-essential \
    python3-dev \
    openssh-client \
    # Fonts for PDF generation
    fonts-noto-cjk \
    fonts-liberation2 \
    gsfonts \
    # Python development libraries
    libxml2-dev \
    libxslt1-dev \
    zlib1g-dev \
    libsasl2-dev \
    libldap2-dev \
    libssl-dev \
    libffi-dev \
    libjpeg-dev \
    libpq-dev \
    liblcms2-dev \
    libblas-dev \
    libatlas-base-dev \
    # Localization
    locales && \
    # Configure locales
    sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen en_US.UTF-8 && \
    # Cleanup
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Layer 2: Install PostgreSQL client
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    # Create keyrings directory
    mkdir -p /etc/apt/keyrings && \
    # Add PostgreSQL repository with modern signed-by method
    curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /etc/apt/keyrings/postgresql.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/postgresql.gpg] http://apt.postgresql.org/pub/repos/apt/ bookworm-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
    # Install PostgreSQL client
    apt-get update && \
    apt-get install -y --no-install-recommends postgresql-client && \
    # Cleanup
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Layer 3: Install Node.js 22
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    # Add NodeSource repository
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" > /etc/apt/sources.list.d/nodesource.list && \
    # Install Node.js
    apt-get update && \
    apt-get install -y --no-install-recommends nodejs && \
    # Install global npm packages
    npm install -g rtlcss && \
    npm cache clean --force && \
    # Cleanup
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Layer 4: Install wkhtmltopdf
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    # Download wkhtmltopdf based on detected architecture
    WKHTMLTOPDF_URL="https://github.com/wkhtmltopdf/packaging/releases/download/${WKHTMLTOPDF_VERSION}-3/wkhtmltox_${WKHTMLTOPDF_VERSION}-3.bookworm_${TARGETARCH}.deb" && \
    WKHTMLTOPDF_CHECKSUM="" && \
    if [ "$TARGETARCH" = "arm64" ]; then \
    WKHTMLTOPDF_CHECKSUM="$WKHTMLTOPDF_ARM64_CHECKSUM"; \
    elif [ "$TARGETARCH" = "amd64" ]; then \
    WKHTMLTOPDF_CHECKSUM="$WKHTMLTOPDF_AMD64_CHECKSUM"; \
    else \
    echo "Unsupported architecture: $TARGETARCH" >&2; \
    exit 1; \
    fi && \
    curl -fsSL -o wkhtmltox.deb "${WKHTMLTOPDF_URL}" && \
    echo "${WKHTMLTOPDF_CHECKSUM}  wkhtmltox.deb" | sha256sum -c - && \
    # Install wkhtmltopdf with dependencies
    apt-get install -y --no-install-recommends ./wkhtmltox.deb && \
    # Cleanup
    rm -f wkhtmltox.deb && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Copy uv binary from official image
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# Create user and directories
RUN groupadd --gid $USER_GID $USERNAME && \
    useradd --uid $USER_UID --gid $USER_GID -m -s /bin/zsh $USERNAME && \
    echo "$USERNAME ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME && \
    chmod 0440 /etc/sudoers.d/$USERNAME && \
    mkdir -p $ODOO_DATA /commandhistory && \
    chown -R $USERNAME:$USERNAME $ODOO_DATA /commandhistory /home/$USERNAME && \
    chmod -R 775 $ODOO_DATA /commandhistory

USER $USERNAME
WORKDIR /home/$USERNAME

# Install Oh My Zsh and plugins
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended && \
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions && \
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting && \
    git clone --depth=1 https://github.com/zsh-users/zsh-completions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-completions && \
    git clone --depth=1 https://github.com/zsh-users/zsh-history-substring-search ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-history-substring-search && \
    # Configure zsh
    sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting zsh-completions sudo uv zsh-history-substring-search)/' ~/.zshrc && \
    { \
    echo '\n# Inicializar zoxide'; \
    echo 'eval "$(zoxide init zsh)"'; \
    echo '\n# Configuración de historial de zsh'; \
    echo 'autoload -Uz add-zsh-hook; append_history() { fc -W }; add-zsh-hook precmd append_history; export HISTFILE=/commandhistory/.zsh_history'; \
    echo 'HISTSIZE=10000'; \
    echo 'SAVEHIST=10000'; \
    echo 'setopt SHARE_HISTORY'; \
    } >> ~/.zshrc && \
    touch /commandhistory/.zsh_history

# Install OpenCode CLI
RUN curl -fsSL https://opencode.ai/install | bash

# Change to workspace directory
WORKDIR /workspace

# Expose volume for persistent Odoo data
VOLUME ["$ODOO_DATA"]

# Set zsh as default shell
CMD ["zsh"]
