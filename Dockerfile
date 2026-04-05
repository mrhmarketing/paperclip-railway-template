FROM node:20-slim

# ── System deps: gosu (privilege dropping) + Python (for Hermes Agent) ──
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
       gosu \
       python3 \
       python3-pip \
       python3-venv \
       git \
       curl \
  && rm -rf /var/lib/apt/lists/*

# ── Install uv (fast Python package manager) ──
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:$PATH"

# ── Install Hermes Agent from source ──
RUN git clone --recurse-submodules https://github.com/NousResearch/hermes-agent.git /opt/hermes-agent \
  && cd /opt/hermes-agent \
  && uv venv venv --python 3.11 \
  && VIRTUAL_ENV=/opt/hermes-agent/venv uv pip install -e ".[all]" \
  && mkdir -p /usr/local/bin \
  && ln -sf /opt/hermes-agent/venv/bin/hermes /usr/local/bin/hermes

# ── Create non-root user (Claude CLI refuses --dangerously-skip-permissions as root) ──
RUN groupadd -r paperclip && useradd -r -g paperclip -m -d /home/paperclip -s /bin/bash paperclip

# ── Create the paperclip home directory (Railway volume mount point) ──
RUN mkdir -p /paperclip && chown -R paperclip:paperclip /paperclip

# ── Create Hermes home directory on the persistent volume ──
RUN mkdir -p /paperclip/.hermes && chown -R paperclip:paperclip /paperclip/.hermes

WORKDIR /app

# ── Copy package files and install Node dependencies ──
COPY package.json ./
RUN npm install --omit=dev

# ── Copy application code ──
COPY . .

# ── Give ownership of everything to the non-root user ──
RUN chown -R paperclip:paperclip /app /home/paperclip

# ── Copy and set up entrypoint ──
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# ── Set Hermes home to persistent volume so memory/sessions survive redeploys ──
ENV HERMES_HOME=/paperclip/.hermes

# ── Railway injects PORT at runtime (default 3100) ──
ENV PORT=3100
EXPOSE 3100

# ── Entrypoint runs as root to fix volume permissions, then drops to paperclip user ──
ENTRYPOINT ["/entrypoint.sh"]
CMD ["npm", "start"]
